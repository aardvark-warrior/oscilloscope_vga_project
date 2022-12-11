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
	signal wea:		std_logic_vector(3 downto 0):=(others=>'0');
	signal web: 	std_logic_vector(3 downto 0):=(others=>'0');
	signal counter: unsigned(10 downto 0):= b"00000000001";
	signal addra: 	std_logic_vector(9 downto 0);
	signal dataa: 	std_logic_vector(35 downto 0);
	signal addrb: 	std_logic_vector(9 downto 0);
	signal datab: 	std_logic_vector(35 downto 0);
	
	
	--VGA --
	signal clkfb:    std_logic;
	signal clkfx:    std_logic;
	signal hcount:   unsigned(9 downto 0);
	signal vcount:   unsigned(9 downto 0);
	signal blank:    std_logic;
	signal frame:    std_logic;
	signal obj1_red: std_logic_vector(1 downto 0):=(others=>'0');  -- obj1 -> grid
	signal obj1_grn: std_logic_vector(1 downto 0):=(others=>'0');
	signal obj1_blu: std_logic_vector(1 downto 0):=(others=>'0');
	signal obj2_red: std_logic_vector(1 downto 0):=(others=>'0');  -- obj2 -> reading
	signal obj2_grn: std_logic_vector(1 downto 0):=(others=>'0');
	signal obj2_blu: std_logic_vector(1 downto 0):=(others=>'0');
	signal screen_red: std_logic_vector(1 downto 0):=(others=>'0');  -- screen -> reading over grid
	signal screen_grn: std_logic_vector(1 downto 0):=(others=>'0');
	signal screen_blu: std_logic_vector(1 downto 0):=(others=>'0');
	
	--signal 
	
begin
    --dataa_11 <= to_unsigned(480,12)*unsigned(dataa(11 downto 0))/unsigned(std_logic_vector(b"11111111111"));
    --BEGIN WITH OSCILLISCOPE MEASUREMENT
	gui:  Oscilliscope_gui generic map (SAMPLES=>samples)
	                port map(clk=>clk,rx=>rx,tx=>tx,addr=>addra,data=>dataa(11 downto 0));
	cmt:  Oscilliscope_cmt port map(clk_i=>clk,clk_o=>fclk);
	adc:  Oscilliscope_adc port map(clk=>fclk,vaux5_n=>vaux5_n,vaux5_p=>vaux5_p,rdy=>rdy,data=>datab(11 downto 0));
	
	ram0: Oscilliscope_ram port map(
		clka_i=>clk,wea_i=>wea(0),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa, -- port A output to VGA
		clkb_i=>fclk,web_i=>web(0),addrb_i=>addrb,datab_i=>datab,datab_o=>open          -- port B input from ADC
    );
	-- ram1: Oscilliscope_ram port map(
	-- 	clka_i=>clk,wea_i=>wea(1),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa,
	-- 	clkb_i=>fclk,web_i=>web(1),addrb_i=>addrb,datab_i=>datab,datab_o=>open
	-- );
	-- ram2: Oscilliscope_ram port map(
	-- 	clka_i=>clk,wea_i=>wea(2),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa,
	-- 	clkb_i=>fclk,web_i=>web(2),addrb_i=>addrb,datab_i=>datab,datab_o=>open
	-- );
	-- ram3: Oscilliscope_ram port map(
	-- 	clka_i=>clk,wea_i=>wea(3),addra_i=>addra,dataa_i=>(others=>'0'),dataa_o=>dataa,
	-- 	clkb_i=>fclk,web_i=>web(3),addrb_i=>addrb,datab_i=>datab,datab_o=>open
	-- );
   
	pio31 <= out31;
	web(0) <= rdy;

	wea(0) <= frame;
	-- if (ramcount = '1') then
	--     web_ram0 = '0'
    --     web_ram1 = '1'
	--     web_ram2 = '0'
	--     web_ram3 = '0'
    -- end if;

	process(rdy) -- 
	begin
		if rising_edge(rdy) then
			if (addrb=std_logic_vector(to_unsigned(samples-1,10))) then
				addrb<=b"00_0000_0000";
			else
				addrb<= std_logic_vector(unsigned(addrb) + to_unsigned(1,10));
			end if;
		end if;
	end process;
	
	process(fclk) -- create square wave
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
	-- Draw grid
	------------------------------------------------------------------
    process(clkfx,obj2_red,obj2_grn,obj2_blu)
    begin
        if rising_edge(clkfx) then
            if (hcount=80) or
               (hcount=160) or
               (hcount=240) or
               (hcount=320) or
               (hcount=400) or
               (hcount=480) or
               (hcount=560) or
               (vcount=80) or
               (vcount=160) or
               (vcount=240) or
               (vcount=320) or
               (vcount=400) then  
                obj1_red<=b"01";
                obj1_grn<=b"01";
                obj1_blu<=b"01";
            else
                obj1_red<=b"00";            
                obj1_grn<=b"00";
                obj1_blu<=b"00";
            end if;
			-- Hard code green horizontal line centre of screen
			-- if (vcount=240) then
			-- 	obj2_red<=b"00";
			-- 	obj2_grn<=b"11";
			-- 	obj2_blu<=b"00";
			-- else
			-- 	obj2_red<=b"00";
			-- 	obj2_grn<=b"00";
			-- 	obj2_blu<=b"00";
			-- end if;
			-- if (vcount=(480*(1-unsigned(dataa(11 downto 0))/4095))) then
			-- 	obj2_red<=b"00";
			-- 	obj2_grn<=b"11";
			-- 	obj2_blu<=b"00";
			-- else
			-- 	obj2_red<=b"00";
			-- 	obj2_grn<=b"00";
			-- 	obj2_blu<=b"00";
			-- end if;
			if (vcount = 400 - to_integer(5 + 10*unsigned(dataa(11 downto 0))*320/4095)/10) then
				obj2_red<=b"00";            
				obj2_grn<=b"11";
				obj2_blu<=b"00";
			else
				obj2_red<=b"00";
				obj2_grn<=b"00";
				obj2_blu<=b"00";
			end if;
        end if;
		-- Make trace appear before grid
        if (obj2_red=b"00" and obj2_grn=b"00" and obj2_blu=b"00") then
            screen_red <= obj1_red;
            screen_grn <= obj1_grn;
            screen_blu <= obj1_blu;
	    else
            screen_red <= obj2_red;
            screen_grn <= obj2_grn;
            screen_blu <= obj2_blu;
	end if;
    end process;
	------------------------------------------------------------------
	-- VGA output with blanking
	------------------------------------------------------------------
	
	
	red<=b"00" when blank='1' else screen_red;
	green<=b"00" when blank='1' else screen_grn;
	blue<=b"00" when blank='1' else screen_blu;

end arch;