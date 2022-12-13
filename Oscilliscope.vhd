library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity Oscilliscope is
	port(
	    --Oscilliscope
		clk:     in  std_logic;
		vaux5_n: in  std_logic;
		vaux5_p: in  std_logic;
		pio31:   out std_logic;  -- square wave signal; 30 detects signal
		rx:      in  std_logic;
		tx:      out std_logic;
		
		--VGA
        tvx:   out   std_logic;
		red:   out   std_logic_vector(1 downto 0);
		green: out   std_logic_vector(1 downto 0);
		blue:  out   std_logic_vector(1 downto 0);
		hsync: out   std_logic;
		vsync: out   std_logic
	);
end Oscilliscope;

architecture arch of Oscilliscope is
	component Oscilliscope_gui is
		generic(
			SAMPLES: natural
		);
		port(
			clk:  in  std_logic;
			rx:   in  std_logic;
			tx:   out std_logic;
			addr: out std_logic_vector(9 downto 0);
			data: in  std_logic_vector(11 downto 0)
		);
	end component;
	component Oscilliscope_adc is
		port(
			clk:     in  std_logic;
			vaux5_n: in  std_logic;
			vaux5_p: in  std_logic;
			rdy:     out std_logic;
			data:    out std_logic_vector(11 downto 0) -- XADC output to RAM => dataa_i; represents scope reading at one time point
		);
	end component;
	component Oscilliscope_ram is
		port(
			clka_i:  in  std_logic;
			wea_i:   in  std_logic;
			addra_i: in  std_logic_vector(9 downto 0);
			dataa_i: in  std_logic_vector(35 downto 0); -- writes XADC data output as lowest 12 bits of 36
			dataa_o: out std_logic_vector(35 downto 0); -- VGA reads from here and compare to vcount
			clkb_i:  in  std_logic;
			web_i:   in  std_logic;
			addrb_i: in  std_logic_vector(9 downto 0);
			datab_i: in  std_logic_vector(35 downto 0);
			datab_o: out std_logic_vector(35 downto 0)
		);
	end component;
	component Oscilliscope_cmt is
		port(
			clk_i: in  std_logic;
			clk_o: out std_logic
		);
	end component;
	
	constant samples: natural:=200;
	signal fclk:    std_logic;
	signal rdy:  	std_logic;
	signal out31: 	std_logic;
	signal wea: 	std_logic;
	signal web: 	std_logic;
	signal counter: unsigned(10 downto 0):= b"00000000001";
	signal addra: 	std_logic_vector(9 downto 0); -- driven by gui
	signal addr_a:	std_logic_vector(9 downto 0); -- driven by VGA hcount
	signal dataa: 	std_logic_vector(35 downto 0); -- from RAM ...
	-- signal dataa0: 	std_logic_vector(35 downto 0);
	-- signal dataa1: 	std_logic_vector(35 downto 0);
	-- signal dataa2: 	std_logic_vector(35 downto 0);
	-- signal dataa3: 	std_logic_vector(35 downto 0);
	signal addrb: 	std_logic_vector(9 downto 0);
	-- signal addrb0: 	std_logic_vector(9 downto 0);
	-- signal addrb1: 	std_logic_vector(9 downto 0);
	-- signal addrb2: 	std_logic_vector(9 downto 0);
	-- signal addrb3: 	std_logic_vector(9 downto 0);
	signal datab: 	std_logic_vector(35 downto 0); -- from ADC ...
	-- signal datab0: 	std_logic_vector(35 downto 0);
	-- signal datab1: 	std_logic_vector(35 downto 0);
	-- signal datab2: 	std_logic_vector(35 downto 0);
	-- signal datab3: 	std_logic_vector(35 downto 0);
	-- signal adc_count: unsigned(1 downto 0):=to_unsigned(0,2);

	--VGA --
	signal clkfb:    std_logic;
	signal clkfx:    std_logic;
	signal hcount:   unsigned(9 downto 0);
	signal vcount:   unsigned(9 downto 0);
	signal blank:    std_logic;
	signal frame:    std_logic;
	signal grd_red: std_logic_vector(1 downto 0):=(others=>'0');  -- grid
	signal grd_grn: std_logic_vector(1 downto 0):=(others=>'0');
	signal grd_blu: std_logic_vector(1 downto 0):=(others=>'0');
	signal line_red: std_logic_vector(1 downto 0):=(others=>'0');  -- reading
	signal line_grn: std_logic_vector(1 downto 0):=(others=>'0');
	signal line_blu: std_logic_vector(1 downto 0):=(others=>'0');
	signal screen_red: std_logic_vector(1 downto 0):=(others=>'0');  -- screen -> reading over grid
	signal screen_grn: std_logic_vector(1 downto 0):=(others=>'0');
	signal screen_blu: std_logic_vector(1 downto 0):=(others=>'0');

	signal grid_top: 	unsigned(9 downto 0):=to_unsigned(10,10);
	signal grid_left: 	unsigned(9 downto 0):=to_unsigned(10,10);
	signal grid_bottom: unsigned(9 downto 0):=to_unsigned(265,10); -- 10 + (256-1)
	signal grid_right: 	unsigned(9 downto 0):=to_unsigned(329,10); -- 10 + (330-1)
	signal grid_width: unsigned(9 downto 0):=to_unsigned(330,10);
	signal grid_height: unsigned(9 downto 0):=to_unsigned(256,10);

	
begin
    --BEGIN WITH OSCILLISCOPE MEASUREMENT
	gui:  Oscilliscope_gui generic map (SAMPLES=>samples)
	                port map(clk=>clk,rx=>rx,tx=>tx,addr=>addra,data=>dataa(11 downto 0));
	cmt:  Oscilliscope_cmt port map(clk_i=>clk,clk_o=>fclk);
	adc:  Oscilliscope_adc port map(clk=>fclk,vaux5_n=>vaux5_n,vaux5_p=>vaux5_p,rdy=>rdy,data=>datab(11 downto 0));
	
	ram0: Oscilliscope_ram port map(
		clka_i=>clk,  -- port A read only output to VGA
		wea_i=>'0',
		addra_i=>addr_a, -- 10 bits
		dataa_i=>(others=>'0'),
		dataa_o=>dataa,  -- 36 bits
		clkb_i=>fclk, -- port B write enable from ADC
		web_i=>web,
		addrb_i=>addrb,
		datab_i=>datab,
		datab_o=>open 
    );

	pio31 <= out31;
	web <= rdy;
	addr_a <= std_logic_vector(hcount);

	------------------------------------------------------------------
	-- TODO: Broken Buffer chain code
	------------------------------------------------------------------

	-- ram0: Oscilliscope_ram port map(
	-- 	clka_i=>clk,wea_i=>wea(0),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa0, -- port A output to VGA
	-- 	clkb_i=>fclk,web_i=>web(0),addrb_i=>addrb0,datab_i=>datab0,datab_o=>open          -- port B input from ADC
    -- );
	-- ram1: Oscilliscope_ram port map(
	-- 	clka_i=>clk,wea_i=>wea(1),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa1,
	-- 	clkb_i=>fclk,web_i=>web(1),addrb_i=>addrb1,datab_i=>datab1,datab_o=>open
	-- );
	-- ram2: Oscilliscope_ram port map(
	-- 	clka_i=>clk,wea_i=>wea(2),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa2,
	-- 	clkb_i=>fclk,web_i=>web(2),addrb_i=>addrb2,datab_i=>datab2,datab_o=>open
	-- );
	-- ram3: Oscilliscope_ram port map(
	-- 	clka_i=>clk,wea_i=>wea(3),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa3,
	-- 	clkb_i=>fclk,web_i=>web(3),addrb_i=>addrb3,datab_i=>datab3,datab_o=>open
	-- );

	------------------------------------------------------------------
	-- Increment addrb of ram0 
	------------------------------------------------------------------
	process(rdy) 
	begin
		if rising_edge(rdy) then
			if (addrb=std_logic_vector(to_unsigned(samples-1,10))) then
				addrb<=b"00_0000_0000";
			else
				addrb<= std_logic_vector(unsigned(addrb) + to_unsigned(1,10));
			end if;
		end if;
	end process;

	-- Generate square wave
	process(fclk) 
	begin
		if rising_edge(fclk) then
			counter <= counter + to_unsigned(1,11);
			if (counter = "10000010000") then
				out31 <= not out31;
				counter <= b"00000000001";
			end if;
		end if;
	end process;	
	
	--CONTINUE WITH VGA DISPLAY SYSTEM--
	tvx<='1';
	------------------------------------------------------------------
	-- Clock management tile
	--
	-- Input clock: 12 MHz
	-- Output clock: 25.2 MHz
	--
	-- CLKFBOUT_MULT_F: 50.875
	-- CLKOUT0_DIVIDE_F: 24.250
	-- DIVCLK_DIVIDE: 1
	------------------------------------------------------------------
	cmt2: MMCME2_BASE generic map (
		-- Jitter programming (OPTIMIZED, HIGH, LOW)
		BANDWIDTH=>"OPTIMIZED",
		-- Multiply value for all CLKOUT (2.000-64.000).
		CLKFBOUT_MULT_F=>50.875,
		-- Phase offset in degrees of CLKFB (-360.000-360.000).
		CLKFBOUT_PHASE=>0.0,
		-- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
		CLKIN1_PERIOD=>83.333,
		-- Divide amount for each CLKOUT (1-128)
		CLKOUT1_DIVIDE=>1,
		CLKOUT2_DIVIDE=>1,
		CLKOUT3_DIVIDE=>1,
		CLKOUT4_DIVIDE=>1,
		CLKOUT5_DIVIDE=>1,
		CLKOUT6_DIVIDE=>1,
		-- Divide amount for CLKOUT0 (1.000-128.000):
		CLKOUT0_DIVIDE_F=>24.250,
		-- Duty cycle for each CLKOUT (0.01-0.99):
		CLKOUT0_DUTY_CYCLE=>0.5,
		CLKOUT1_DUTY_CYCLE=>0.5,
		CLKOUT2_DUTY_CYCLE=>0.5,
		CLKOUT3_DUTY_CYCLE=>0.5,
		CLKOUT4_DUTY_CYCLE=>0.5,
		CLKOUT5_DUTY_CYCLE=>0.5,
		CLKOUT6_DUTY_CYCLE=>0.5,
		-- Phase offset for each CLKOUT (-360.000-360.000):
		CLKOUT0_PHASE=>0.0,
		CLKOUT1_PHASE=>0.0,
		CLKOUT2_PHASE=>0.0,
		CLKOUT3_PHASE=>0.0,
		CLKOUT4_PHASE=>0.0,
		CLKOUT5_PHASE=>0.0,
		CLKOUT6_PHASE=>0.0,
		-- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
		CLKOUT4_CASCADE=>FALSE,
		-- Master division value (1-106)
		DIVCLK_DIVIDE=>1,
		-- Reference input jitter in UI (0.000-0.999).
		REF_JITTER1=>0.0,
		-- Delays DONE until MMCM is locked (FALSE, TRUE)
		STARTUP_WAIT=>FALSE
	) port map (
		-- User Configurable Clock Outputs:
		CLKOUT0=>clkfx,  -- 1-bit output: CLKOUT0
		CLKOUT0B=>open,  -- 1-bit output: Inverted CLKOUT0
		CLKOUT1=>open,   -- 1-bit output: CLKOUT1
		CLKOUT1B=>open,  -- 1-bit output: Inverted CLKOUT1
		CLKOUT2=>open,   -- 1-bit output: CLKOUT2
		CLKOUT2B=>open,  -- 1-bit output: Inverted CLKOUT2
		CLKOUT3=>open,   -- 1-bit output: CLKOUT3
		CLKOUT3B=>open,  -- 1-bit output: Inverted CLKOUT3
		CLKOUT4=>open,   -- 1-bit output: CLKOUT4
		CLKOUT5=>open,   -- 1-bit output: CLKOUT5
		CLKOUT6=>open,   -- 1-bit output: CLKOUT6
		-- Clock Feedback Output Ports:
		CLKFBOUT=>clkfb,-- 1-bit output: Feedback clock
		CLKFBOUTB=>open, -- 1-bit output: Inverted CLKFBOUT
		-- MMCM Status Ports:
		LOCKED=>open,    -- 1-bit output: LOCK
		-- Clock Input:
		CLKIN1=>clk,   -- 1-bit input: Clock
		-- MMCM Control Ports:
		PWRDWN=>'0',     -- 1-bit input: Power-down
		RST=>'0',        -- 1-bit input: Reset
		-- Clock Feedback Input Port:
		CLKFBIN=>clkfb  -- 1-bit input: Feedback clock
	);

	------------------------------------------------------------------
	-- VGA display counters
	--
	-- Pixel clock: 25.175 MHz (actual: 25.2 MHz)
	-- Horizontal count (active low sync):
	--     0 to 639: Active video
	--     640 to 799: Horizontal blank
	--     656 to 751: Horizontal sync (active low)
	-- Vertical count (active low sync):
	--     0 to 479: Active video
	--     480 to 524: Vertical blank
	--     490 to 491: Vertical sync (active low)
	------------------------------------------------------------------
	process(clkfx)
	begin
		if rising_edge(clkfx) then
			-- Pixel position counters
			if (hcount>=to_unsigned(799,10)) then      -- if beam_h >= 799(row duration)
				hcount<=(others=>'0');                 -- then move beam_h back to 0
				if (vcount>=to_unsigned(524,10)) then     -- if beam_v >= 524(column duration)
					vcount<=(others=>'0');                -- then move beam_v back to 0
				else
					vcount<=vcount+1;                     -- else incr beam_v
				end if;
			else
				hcount<=hcount+1;                      -- else incr beam_h
			end if;
			-- Sync, blank and frame
			if (hcount>=to_unsigned(656,10)) and   -- if beam_h >= 656=640(video)+16(backporch)
				(hcount<=to_unsigned(751,10)) then -- and beam_h >= 752=656(vid+back)+96(sync)
				hsync<='0';                        -- then hsync<='1'
			else
				hsync<='1';
			end if;
			if (vcount>=to_unsigned(490,10)) and   -- if beam_v >= 490=480(video)+10(backporch)
				(vcount<=to_unsigned(491,10)) then -- and beam_v >= 492=490(vid+back)+2(sync)
				vsync<='0';                        -- then vsync<='1'
			else
				vsync<='1';
			end if;
			if (hcount>=to_unsigned(640,10)) or    -- if beam_h >= 640(video)
				(vcount>=to_unsigned(480,10)) then -- or beam_v >= 480(video)
				blank<='1';                        -- then set to black
			else
				blank<='0';
			end if;
			if (hcount=to_unsigned(640,10)) and    -- if beam_h == 640(video)
				(vcount=to_unsigned(479,10)) then  -- and beam_v == 480(video)
				frame<='1';                        -- then update frame
			else
				frame<='0';
			end if;
		end if;
	end process;
	
    ------------------------------------------------------------------
	-- VGA Output: Grid, Trace
	------------------------------------------------------------------
    process(clkfx,grd_red,grd_blu,grd_grn,line_red,line_grn,line_blu)
    begin
        if rising_edge(clkfx) then
			-- Draw grid
            if vcount>=grid_top and vcount<=grid_bottom and hcount>=grid_left and hcount<=grid_right and
				(vcount=grid_top or vcount=grid_top+grid_height/2 or vcount=grid_bottom or 
				 hcount=grid_left or hcount=grid_left+grid_width/2 or hcount=grid_right or
				 vcount=grid_top+grid_height/4 or vcount=grid_top+3*grid_height/4 or 
				 hcount=grid_left+grid_width/4 or hcount=grid_left+3*grid_width/4) then
				grd_red<=b"01";            
				grd_grn<=b"01";
				grd_blu<=b"01";
            else
                grd_red<=b"00";            
                grd_grn<=b"00";
                grd_blu<=b"00";
            end if;
			
			-- Draw line/trace using one RAM block (ram0)
            if vcount>=grid_top and vcount<=grid_bottom and hcount>=grid_left and hcount<=grid_right and 
				vcount=(10+grid_width-unsigned(dataa(11 downto 0))/(4096/grid_width)) then
				line_red<=b"00";            
				line_grn<=b"11";
				line_blu<=b"00";
			else
				line_red<=b"00";            
				line_grn<=b"00";
				line_blu<=b"00";
			end if;
        end if;

		-- Make trace appear before grid
        if (line_red=b"00" and line_grn=b"00" and line_blu=b"00") then
            screen_red <= grd_red;
            screen_grn <= grd_grn;
            screen_blu <= grd_blu;
	    else
            screen_red <= line_red;
            screen_grn <= line_grn;
            screen_blu <= line_blu;
	end if;
    end process;
	------------------------------------------------------------------
	-- VGA output with blanking
	------------------------------------------------------------------
	red<=b"00" when blank='1' else screen_red;
	green<=b"00" when blank='1' else screen_grn;
	blue<=b"00" when blank='1' else screen_blu;

end arch;