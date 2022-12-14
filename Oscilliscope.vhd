library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity Oscilliscope is
	port(
		btn: in  std_logic_vector(1 downto 0);
		led: out std_logic_vector(3 downto 0);
		--Oscilliscope
		clk:     in  std_logic;
		vaux5_n: in  std_logic;
		vaux5_p: in  std_logic;
		pio31:   out std_logic;  -- square wave signal; pin 30 detects signal (first white circle)
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
			data:    out std_logic_vector(11 downto 0) -- represents scope reading at one any point in time
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
	--XADC--
	constant samples: natural:=480;
	signal fclk:    std_logic;
	signal rdy:  	std_logic;
	signal out31: 	std_logic;
	signal web: 	std_logic_vector(3 downto 0):= b"0000";
	signal counter: unsigned(10 downto 0):= b"00000000001";
	signal addra: 	std_logic_vector(9 downto 0); 	-- driven by gui
	signal addr_a:	std_logic_vector(9 downto 0); 	-- driven by VGA hcount
	signal dataa: 	std_logic_vector(35 downto 0); 	-- from RAM ...
	signal addrb: 	std_logic_vector(9 downto 0);
	signal datab: 	std_logic_vector(35 downto 0); 	-- from ADC ...
	signal adc_loc: unsigned(1 downto 0):=b"00";	-- track adc location in buffer chain
	signal vga_loc: unsigned(1 downto 0):=b"00";	-- track vga location in buffer chain
	signal adc_loc_next: unsigned(1 downto 0);
	signal vga_loc_next: unsigned(1 downto 0);
	signal dataa0: 	std_logic_vector(35 downto 0); 	
	signal dataa1: 	std_logic_vector(35 downto 0); 	
	signal dataa2: 	std_logic_vector(35 downto 0); 	
	signal dataa3: 	std_logic_vector(35 downto 0); 	
	--VGA--
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
	--Dimensions of scope grid--
	signal grid_top: 	unsigned(9 downto 0):=to_unsigned(0,10);
	signal grid_left: 	unsigned(9 downto 0):=to_unsigned(0,10);
	signal grid_bottom: unsigned(9 downto 0):=to_unsigned(256,10); -- 10 + (256-1)
	signal grid_right: 	unsigned(9 downto 0):=to_unsigned(480,10); -- 10 + (330-1)
	signal grid_width: 	unsigned(9 downto 0):=to_unsigned(480,10);
	signal grid_height: unsigned(9 downto 0):=to_unsigned(256,10);
	--Button shift registers-- upper 4 bits shift from 4->7, lower 4 shift 3->0
	signal ud_btn_sh: 	std_logic_vector(7 downto 0):=(others=>'0'); -- upper 4 bits (shift up), 		lower 4 bits (shift down)
	signal lr_btn_sh:   std_logic_vector(7 downto 0):=(others=>'0'); -- upper 4 bits (shift left), 		lower 4 bits (shift right)
	signal vs_btn_sh:	std_logic_vector(7 downto 0):=(others=>'0'); -- upper 4 bits (voltage scale up),lower 4 bits (scale down)
	signal ts_btn_sh:   std_logic_vector(7 downto 0):=(others=>'0'); -- upper 4 bits (time stretch), 	lower 4 bits (time compress)
	signal ram_led:   	std_logic_vector(3 downto 0);

begin
    --BEGIN WITH OSCILLISCOPE MEASUREMENT
	gui:  Oscilliscope_gui generic map (SAMPLES=>samples)
	                port map(clk=>clk,rx=>rx,tx=>tx,addr=>addra,data=>dataa(11 downto 0));
	cmt:  Oscilliscope_cmt port map(clk_i=>clk,clk_o=>fclk);
	adc:  Oscilliscope_adc port map(clk=>fclk,vaux5_n=>vaux5_n,vaux5_p=>vaux5_p,rdy=>rdy,data=>datab(11 downto 0));
	ram0: Oscilliscope_ram port map(
		clka_i=>clk,  		-- port A read only output to VGA
		wea_i=>'0',
		addra_i=>addr_a, 	-- 10 bits
		dataa_i=>(others=>'0'),
		dataa_o=>dataa0,  	-- 36 bits
		clkb_i=>fclk, 		
		web_i=>web(0),     
		addrb_i=>addrb,     
		datab_i=>datab,    
		datab_o=>open 
    );
	ram1: Oscilliscope_ram port map(
		clka_i=>clk,  		
		wea_i=>'0',
		addra_i=>addr_a, 	
		dataa_i=>(others=>'0'),
		dataa_o=>dataa1,  	
		clkb_i=>fclk, 		
		web_i=>web(1),    	 	
		addrb_i=>addrb,     
		datab_i=>datab,     
		datab_o=>open 
    );
	ram2: Oscilliscope_ram port map(
		clka_i=>clk,  		
		wea_i=>'0',
		addra_i=>addr_a, 	
		dataa_i=>(others=>'0'),
		dataa_o=>dataa2,  	
		clkb_i=>fclk, 		
		web_i=>web(2),     	
		addrb_i=>addrb,     
		datab_i=>datab,     
		datab_o=>open 
    );
	ram3: Oscilliscope_ram port map(
		clka_i=>clk,  		
		wea_i=>'0',
		addra_i=>addr_a, 	
		dataa_i=>(others=>'0'),
		dataa_o=>dataa3,  	
		clkb_i=>fclk, 		
		web_i=>web(3),	     	
		addrb_i=>addrb,     
		datab_i=>datab,     
		datab_o=>open 
    );

	------------------------------------------------------------------
	-- Button Metastability Logic
	------------------------------------------------------------------
	process(clkfx)
	begin
		if rising_edge(clkfx)
			ud_btn_sh(4)<=btn(1); -- upper 4 bits for up shift button
			ud_btn_sh(5)<=ud_btn_sh(4);
			ud_btn_sh(6)<=ud_btn_sh(5);
			ud_btn_sh(7)<=ud_btn_sh(6); -- use bits 7,6 for edge detection

			ud_btn_sh(3)<=btn(0); -- lower 4 bits for down shift button
			ud_btn_sh(2)<=ud_btn_sh(3);
			ud_btn_sh(1)<=ud_btn_sh(2);
			ud_btn_sh(0)<=ud_btn_sh(1); -- use bits 0,1 for edge detection
		end if;
		-- TODO: add debouncing

		-- TODO: add edge detection to shift up

		-- TODO: set magnitude of shift

		-- TODO: pick input (for button press) and output (for button pull-up thought 3.3-10kOhm) ports
	end process;
	------------------------------------------------------------------
	-- RAM from Buffer Chain logic
	------------------------------------------------------------------
	addr_a <= std_logic_vector(hcount);
	--* Switch ram block to read from after each frame * --
	process(clkfx) -- clkfx from cmt2 25.2 MHz for VGA
	begin
		-- Select ram most-recently used by adc as next vga_loc
		if vga_loc=adc_loc-1 then
			vga_loc_next <= vga_loc-1;
		else
			vga_loc_next <= adc_loc-1;
		end if;
		
		if rising_edge(clkfx) then
			if frame='1' then
				vga_loc <= vga_loc_next;	-- Only update vga_loc on every new frame
				if vga_loc_next=to_unsigned(0,2) then
					dataa <= dataa0;
				elsif vga_loc_next<=to_unsigned(1,2) then
					dataa <= dataa1;
				elsif vga_loc_next<=to_unsigned(2,2) then
					dataa <= dataa2;
				else
					dataa <= dataa3;
				end if;
			else
				if vga_loc=to_unsigned(0,2) then
					dataa <= dataa0;
				elsif vga_loc<=to_unsigned(1,2) then
					dataa <= dataa1;
				elsif vga_loc<=to_unsigned(2,2) then
					dataa <= dataa2;
				else
					dataa <= dataa3;
				end if;
			end if;
		end if;
	end process;

	------------------------------------------------------------------
	-- ADC to Buffer Chain logic
	------------------------------------------------------------------
	led <= ram_led;
	process(fclk) 
	begin
		-- Select next ram in buffer chain, skipping vga_loc
		if adc_loc=vga_loc-1 then
			adc_loc_next <= vga_loc+1;
		else
			adc_loc_next <= adc_loc+1;
		end if;

		-- * Write to incremented address of ram block at rising edge of rdy * --
		if rising_edge(fclk) then -- fclk from cmt 52 MHz for ADC; rdy is synced with fclk
			if rdy='1' then
				if (addrb=std_logic_vector(to_unsigned(samples-1,10))) then
					addrb<=b"00_0000_0000";
					adc_loc <= adc_loc_next;	-- Only update adc_loc when finished writing a ram block
					if adc_loc_next=to_unsigned(0,2) then
						web <= (0=>rdy,others=>'0');
					elsif adc_loc_next=to_unsigned(1,2) then
						web <= (1=>rdy,others=>'0');
					elsif adc_loc_next=to_unsigned(2,2) then
						web <= (2=>rdy,others=>'0');
					else
						web <= (3=>rdy,others=>'0');
					end if;
				else
					addrb<=std_logic_vector(unsigned(addrb) + to_unsigned(1,10));
					if adc_loc=to_unsigned(0,2) then
						web <= (0=>rdy,others=>'0');
						ram_led <= b"0001";
					elsif adc_loc=to_unsigned(1,2) then
						web <= (1=>rdy,others=>'0');
						ram_led <= b"0010";
					elsif adc_loc=to_unsigned(2,2) then
						web <= (2=>rdy,others=>'0');
						ram_led <= b"0100";
					else
						web <= (3=>rdy,others=>'0');
						ram_led <= b"1000";
					end if;
				end if;
			else
				web <= b"0000";
			end if;
		end if;
	end process;

	------------------------------------------------------------------
	-- Generate output signal: square wave
	------------------------------------------------------------------
	pio31 <= out31;
	-- * Test_sig_1: square wave alternate every 1040-1 counts * --
	process(fclk) 
	begin
		if rising_edge(fclk) then
			counter <= counter + to_unsigned(1,11);
			if (counter = "10000010000") then -- 1040
				out31 <= not out31;
				counter <= b"00000000001";
			end if;
		end if;
	end process;	

	-- * Test_sig_2: square wave alternate every 1280-1 counts * --
	-- process(fclk) 
	-- begin
	-- 	if rising_edge(fclk) then
	-- 		counter <= counter + to_unsigned(1,11);
	-- 		if (counter = "10100000000") then
	-- 			out31 <= not out31;
	-- 			counter <= b"00000000001";
	-- 		end if;
	-- 	end if;
	-- end process;	
	
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
		CLKFBOUT=>clkfb, -- 1-bit output: Feedback clock
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
				(vcount=grid_top+grid_height/4 or vcount=grid_top+3*grid_height/4 or 
				 hcount=grid_left+grid_width/4 or hcount=grid_left+3*grid_width/4 or
				 hcount=grid_left+grid_width/8 or hcount=grid_left+3*grid_width/8 or
				 hcount=grid_left+5*grid_width/8 or hcount=grid_left+7*grid_width/8) then
				grd_red<=b"01";            
				grd_grn<=b"01";
				grd_blu<=b"01";
			elsif vcount>=grid_top and vcount<=grid_bottom and hcount>=grid_left and hcount<=grid_right and 
				(vcount=grid_top or vcount=grid_top+grid_height/2 or vcount=grid_bottom or 
				 hcount=grid_left or hcount=grid_left+grid_width/2 or hcount=grid_right) then
				grd_red<=b"10";
				grd_grn<=b"10";
				grd_blu<=b"10";
            else
                grd_red<=b"00";            
                grd_grn<=b"00";
                grd_blu<=b"00";
            end if;
			
			-- Draw line/trace using one RAM block (ram0)
            if vcount>=grid_top and vcount<=grid_bottom and hcount>=grid_left and hcount<=grid_right and 
				vcount=(grid_top+grid_height-unsigned(dataa(11 downto 0))/(4096/grid_height)) then
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