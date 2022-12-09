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
			data:    out std_logic_vector(11 downto 0)
		);
	end component;
	component Oscilliscope_ram is
		port(
			clka_i:  in  std_logic;
			wea_i:   in  std_logic;
			addra_i: in  std_logic_vector(9 downto 0);
			dataa_i: in  std_logic_vector(35 downto 0);
			dataa_o: out std_logic_vector(35 downto 0);
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
	signal web: 	std_logic;
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
	signal obj1_red: std_logic_vector(1 downto 0);  -- obj1 -> grid
	signal obj1_grn: std_logic_vector(1 downto 0);
	signal obj1_blu: std_logic_vector(1 downto 0);
	signal obj2_red: std_logic_vector(1 downto 0);  -- obj2 -> reading
	signal obj2_grn: std_logic_vector(1 downto 0);
	signal obj2_blu: std_logic_vector(1 downto 0);

	--signal radius:        unsigned(9 downto 0);	
	signal ball_x_left:   unsigned(9 downto 0):=to_unsigned(0,10);
    signal ball_x_right:  unsigned(9 downto 0);
	signal ball_y_top:    unsigned(9 downto 0):=to_unsigned(0,10);
	signal ball_y_bot:    unsigned(9 downto 0);
	signal ball_dx:       std_logic:='1';
	signal ball_dy:       std_logic:='1';
    signal dataa_11:      std_logic_vector(9 downto 0);
	
	--signal 
	
begin
    dataa_11 <= to_unsigned(480,12)*unsigned(dataa(11 downto 0))/unsigned(std_logic_vector(b"11111111111"));
    --BEGIN WITH OSCILLISCOPE MEASUREMENT
	gui:  Oscilliscope_gui generic map (SAMPLES=>samples)
	                port map(clk=>clk,rx=>rx,tx=>tx,addr=>addra,data=>dataa(11 downto 0));
	cmt:  Oscilliscope_cmt port map(clk_i=>clk,clk_o=>fclk);
	adc:  Oscilliscope_adc port map(clk=>fclk,vaux5_n=>vaux5_n,vaux5_p=>vaux5_p,rdy=>rdy,data=>datab(11 downto 0));
	
	ram: Oscilliscope_ram port map(
	   clka_i=>clk,
	   wea_i=>'0', -- read mode
	   addra_i=>addra,
	   dataa_i=>(others=>'0'),
	   dataa_o=>dataa, -- RAM data -> dataa signal
	   clkb_i=>fclk,
	   web_i=>web,
	   addrb_i=>addrb,
	   datab_i=>datab,
	   datab_o=>open
   );
--   ram1: Oscilliscope_ram port map(
--	   clka_i=>clk,
--	   wea_i=>'0',
--	   addra_i=>addra,
--	   dataa_i=>(others=>'0'),
--	   dataa_o=>dataa,
--	   clkb_i=>fclk,
--	   web_i=>web,
--	   addrb_i=>addrb,
--	   datab_i=>datab,
--	   datab_o=>open
--   );
--   ram2: Oscilliscope_ram port map(
--	   clka_i=>clk,
--	   wea_i=>'0',
--	   addra_i=>addra,
--	   dataa_i=>(others=>'0'),
--	   dataa_o=>dataa,
--	   clkb_i=>fclk,
--	   web_i=>web,
--	   addrb_i=>addrb,
--	   datab_i=>datab,
--	   datab_o=>open
--   );
--   ram3: Oscilliscope_ram port map(
--	   clka_i=>clk,
--	   wea_i=>'0',
--	   addra_i=>addra,
--	   dataa_i=>(others=>'0'),
--	   dataa_o=>dataa,
--	   clkb_i=>fclk,
--	   web_i=>web,
--	   addrb_i=>addrb,
--	   datab_i=>datab,
--	   datab_o=>open
--   );
   
	pio31 <= out31;
	web <= rdy;
	-- if (ramcount = '1') then
	--     web_ram0 = '0'
    --     web_ram1 = '1'
	--     web_ram2 = '0'
	--     web_ram3 = '0'
    -- end if;

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

	datab(35 downto 12)<=(others=>'0');
	
	
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
	
	-- Relate ball right and bottom edges to left and top edges plus offset
	--ball_x_right <= ball_x_left + 20;
	--ball_y_bot   <= ball_y_top + 20;
	
	------------------------------------------------------------------
	-- Move white ball
	------------------------------------------------------------------
	process(clkfx,frame)
	begin
	    if rising_edge(clkfx) and frame='1' then 			 
            -- Move ball-x
            if ball_dx = '1' then
                if ball_x_right = to_unsigned(639,10) then
                    ball_x_left <= ball_x_left - 1;
                    ball_dx <= '0';
                else
                    ball_x_left <= ball_x_left + 1;
                end if;
            else 
                if ball_x_left = to_unsigned(0,10) then
                    ball_x_left <= ball_x_left + 1;
                    ball_dx <= '1';
                else
                    ball_x_left <= ball_x_left - 1;
                end if;
            end if; -- dx
            -- Move ball-y
            if ball_dy = '1' then
                if ball_y_bot = to_unsigned(479,10) then
                    ball_y_top <= ball_y_top - 1;
                    ball_dy <= '0';
                else
                    ball_y_top <= ball_y_top + 1;
                end if;
            else -- ball_dy = '0'
                if ball_y_top = to_unsigned(0,10) then
                    ball_y_top <= ball_y_top + 1;
                    ball_dy <= '1';
                else
                    ball_y_top <= ball_y_top - 1;
                end if;
            end if; -- dy
	    end if; -- clk & frame
	end process;
	
	
    ------------------------------------------------------------------
	-- Draw grid
	------------------------------------------------------------------
    process(clkfx)
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
               (vcount=400) or
               (vcount=480) then  
                obj1_red<=b"01";
                obj1_grn<=b"01";
                obj1_blu<=b"01";
            else
                obj1_red<=b"00";            
                obj1_grn<=b"00";
                obj1_blu<=b"00";
            end if;
            if (vcount= unsigned(dataa_11)) then
                obj2_red<=b"11";            
                obj2_grn<=b"11";
                obj2_blu<=b"11";
            else
                obj2_red<=b"00";            
                obj2_grn<=b"00";
                obj2_blu<=b"00";
            end if;
        end if;
    end process;
	------------------------------------------------------------------
	-- VGA output with blanking
	------------------------------------------------------------------
	red<=b"00" when blank='1' else obj1_red;
	green<=b"00" when blank='1' else obj1_grn;
	blue<=b"00" when blank='1' else obj1_blu;

end arch;