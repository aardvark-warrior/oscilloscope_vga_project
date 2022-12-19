library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity Oscilliscope is
	port(
		btn: 	in  std_logic_vector(1 downto 0);
		led:	out std_logic_vector(3 downto 0);
		--Oscilliscope
		clk:	in  std_logic;
		vaux5_n:in  std_logic;
		vaux5_p:in  std_logic;
		pio31:  out std_logic;  -- square wave signal; pin 30 detects signal (first white circle)
		rx:     in  std_logic;
		tx:     out std_logic;
		--VGA
        tvx:   	out   std_logic;
		red:   	out   std_logic_vector(1 downto 0);
		green: 	out   std_logic_vector(1 downto 0);
		blue:  	out   std_logic_vector(1 downto 0);
		hsync: 	out   std_logic;
		vsync: 	out   std_logic;
		--Control buttons
		pio23:	in	std_logic;
		pio22:	in	std_logic;
		pio21:	out std_logic;
		pio20:	in	std_logic;
		pio19:	in	std_logic;
		pio18:	out std_logic;
		pio17:	in	std_logic;
		pio16:	in	std_logic;
		pio9:	out std_logic;
		pio8:	in	std_logic;
		pio7:	in	std_logic;
		pio6:	out std_logic
	);
end Oscilliscope;

architecture arch of Oscilliscope is
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
			addra_i: in  std_logic_vector(9 downto 0);  -- 2^10 -1 addresses (1024 -1)
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
	signal fclk:    	std_logic;
	signal rdy:  		std_logic;
	signal out31: 		std_logic;
	signal web: 		std_logic_vector(3 downto 0):= b"0000";
	signal counter: 	unsigned(10 downto 0):= b"00000000001";		-- for generated square wave frequency
	signal addr_a:		std_logic_vector(9 downto 0); 	-- driven by VGA hcount
	signal dataa: 		std_logic_vector(35 downto 0); 	-- original scope reading from RAM ...
	signal addrb: 		std_logic_vector(9 downto 0);
	signal datab: 		std_logic_vector(35 downto 0); 	-- from ADC ...
	signal dataa0: 		std_logic_vector(35 downto 0); 	
	signal dataa1: 		std_logic_vector(35 downto 0); 	
	signal dataa2: 		std_logic_vector(35 downto 0); 	
	signal dataa3: 		std_logic_vector(35 downto 0); 
	signal adc_loc: 	unsigned(1 downto 0):=b"00";	-- track adc location in buffer chain
	signal adc_loc_n: 	unsigned(1 downto 0);
	signal vga_loc: 	unsigned(1 downto 0):=b"00";	-- track vga location in buffer chain
	signal vga_loc_n: 	unsigned(1 downto 0);
	signal prev_adc: 	unsigned(1 downto 0);	
	--VGA--
	signal clkfb:    	std_logic;
	signal clkfx:    	std_logic;
	signal blank:    	std_logic;
	signal frame:    	std_logic;
	signal hcount:   	unsigned(9 downto 0);
	signal vcount:   	unsigned(9 downto 0);
	signal ram_idx:		std_logic_vector(19 downto 0);
	signal grd_red:  	std_logic_vector(1 downto 0):=(others=>'0');  -- grid
	signal grd_grn:  	std_logic_vector(1 downto 0):=(others=>'0');
	signal grd_blu:  	std_logic_vector(1 downto 0):=(others=>'0');
	signal line_red: 	std_logic_vector(1 downto 0):=(others=>'0');  -- reading
	signal line_grn: 	std_logic_vector(1 downto 0):=(others=>'0');
	signal line_blu: 	std_logic_vector(1 downto 0):=(others=>'0');
	signal trig_red: 	std_logic_vector(1 downto 0):=(others=>'0');  -- trigger level indicator
	signal trig_grn: 	std_logic_vector(1 downto 0):=(others=>'0');
	signal trig_blu: 	std_logic_vector(1 downto 0):=(others=>'0');
	signal screen_red: 	std_logic_vector(1 downto 0):=(others=>'0');  -- screen <= reading over trigger over grid
	signal screen_grn: 	std_logic_vector(1 downto 0):=(others=>'0');
	signal screen_blu: 	std_logic_vector(1 downto 0):=(others=>'0');
	--Signal Vertical Shift and Amp Scale
	signal ratio: 		unsigned(9 downto 0);						-- adc_range(4096)/grid_height; 
	signal scaled_sig:	unsigned(23 downto 0); 						-- signal after gain 
	signal gn_state:	signed(7 downto 0):=(others=>'0');	
	signal gn_state_n:	signed(7 downto 0):=(others=>'0');
	signal vshift:		signed(11 downto 0):=to_signed(0,12);
	signal vshift_n:	signed(11 downto 0):=to_signed(0,12);
	signal gain:		unsigned(11 downto 0):=to_unsigned(1,12);	
	signal gain_n:		unsigned(11 downto 0):=to_unsigned(1,12);
	--Signal Horizontal Shift and Time Scale
	signal hshift:		signed(9 downto 0):=to_signed(0,10);
	signal hshift_n:	signed(9 downto 0):=to_signed(0,10);
	signal t_scale:		unsigned(9 downto 0):=to_unsigned(1,10);
	signal t_scale_n:   unsigned(9 downto 0):=to_unsigned(1,10);
	--Scope grid dimensions
	signal grid_top: 	unsigned(9 downto 0):=to_unsigned(0,10);
	signal grid_left: 	unsigned(9 downto 0):=to_unsigned(0,10);
	signal grid_bottom: unsigned(9 downto 0):=to_unsigned(256,10); 
	signal grid_height: unsigned(9 downto 0):=to_unsigned(256,10);		
	signal grid_right: 	unsigned(9 downto 0):=to_unsigned(640,10); 
	signal grid_width: 	unsigned(9 downto 0):=to_unsigned(640,10);
	--Button shift registers
	signal toggle:		std_logic:='1'; 								-- 1 -> adjust trigger; 0 -> adjust signal
	signal ud_btn_sh: 	std_logic_vector(7 downto 0):=(others=>'0'); 	
	signal vs_btn_sh:	std_logic_vector(7 downto 0):=(others=>'0'); 	
	signal tog_btn_sh:	std_logic_vector(7 downto 0):=(others=>'0');
	signal tr_ts_btn_sh:std_logic_vector(7 downto 0):=(others=>'0');
	signal lr_btn_sh:	std_logic_vector(7 downto 0):=(others=>'0');		
	signal ram_led:   	std_logic_vector(3 downto 0);					-- debugging LEDs
	--Debounce flags and counts
	signal b23_f:		std_logic:='1';
	signal b22_f:		std_logic:='1';
	signal b20_f:		std_logic:='1';
	signal b19_f:		std_logic:='1';
	signal b17_f:		std_logic:='1';
	signal b16_f:		std_logic:='1';
	signal b8_f:		std_logic:='1';
	signal b7_f:		std_logic:='1';
	signal b1_f:		std_logic:='1';
	signal b0_f:		std_logic:='1';
	signal b23_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b22_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b20_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b19_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b17_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b16_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b8_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b7_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b1_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	signal b0_cnt:		unsigned(20 downto 0):=to_unsigned(0,21);
	--Trigger
	constant lvl_step:	unsigned(11 downto 0):=to_unsigned(128,12);
	signal wr_state:	unsigned(1 downto 0):=to_unsigned(0,2);
	signal detected:	std_logic:='0';
	signal init:		std_logic:='1';
	signal pretrig:		std_logic_vector(11 downto 0);
	signal tr_addr:		std_logic_vector(9 downto 0);	-- ADC side of trigger takes care of h_shift
	signal tr_addr0:	std_logic_vector(9 downto 0);	-- when read by VGA, tr_addrX already includes shift
	signal tr_addr1:	std_logic_vector(9 downto 0);
	signal tr_addr2:	std_logic_vector(9 downto 0);
	signal tr_addr3:	std_logic_vector(9 downto 0);
	signal read_addr:	std_logic_vector(9 downto 0);
	signal read_addr_n:	std_logic_vector(9 downto 0);
	signal scaled_trig:	unsigned(11 downto 0);			-- scaled_tr <= grid_height - thresh/ratio;
	signal lvl:			unsigned(11 downto 0):=to_unsigned(3900,12);
	signal lvl_n:		unsigned(11 downto 0):=to_unsigned(3900,12);
	signal tr_h:		unsigned(9 downto 0):=to_unsigned(320,10);
	signal tr_h_n:		unsigned(9 downto 0):=to_unsigned(320,10);

begin
    --BEGIN WITH OSCILLISCOPE MEASUREMENT
	cmt:  Oscilliscope_cmt port map(clk_i=>clk,clk_o=>fclk);
	adc:  Oscilliscope_adc port map(clk=>fclk,vaux5_n=>vaux5_n,vaux5_p=>vaux5_p,rdy=>rdy,data=>datab(11 downto 0));
	ram0: Oscilliscope_ram port map(
		clka_i=>clk,  		-- port A output to VGA
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
	-- Button Metastability Shift
		-- TODO: Debounce
			-- Ignore btn(1) btn(0) to start (on board buttons don't bounce much)
			-- Start with btn23/22 (up/down shift signal) and test to make sure working
			-- Then btn8/7 (toggle button modes) and test to make sure working
			-- Finally, do btn17/16 and btn20/19 and test to make sure working
				-- these are prob most complicated because of nested logic
				-- Big idea: 
					-- when toggle='1': btn17/16 moves trigger level up and down
					--					btn20/19 moves trigger left and right
					-- when toggle='0': btn17/16 compresses/stretches signal time scale
					--					btn20/19 moves signal left and right
		-- Basic idea:
			-- Vertical stretch   -> multiply/divide dataa (before comparing to vcount)
			-- Vertical shift 	  -> add/subtract dataa
			-- Horizontal stretch -> ??
			-- Horizontal shift   -> on ADC-side, add h_shift to addrb before comparing
	------------------------------------------------------------------
	pio21 <= '1'; -- btns pio23,22
	pio18 <= '1'; -- btns pio20,19
	pio9  <= '1'; -- btns pio17,16
	pio6  <= '1'; -- btns pio8,7
	process(clkfx)
	begin
		if rising_edge(clkfx) then
			--Toggle b8,7 and b20,19 functions			
			--btn8
			-- Metastability shift register
			tog_btn_sh(4)<=pio8;
			tog_btn_sh(5)<=tog_btn_sh(4);
			tog_btn_sh(6)<=tog_btn_sh(5);
			tog_btn_sh(7)<=tog_btn_sh(6);
			-- Saturation counter
			if (tog_btn_sh(7)='1') then
					if b8_cnt/=to_unsigned(300000,21) then
						b8_cnt <= b8_cnt + 1;
					else
						if b8_f='1' then
							b8_f<='0';
							toggle <= '1';
						end if;
					end if;
			else
					if (b8_cnt/=to_unsigned(0,21)) then
						b8_cnt<=b8_cnt-1;
					else
						if b8_f='0' then
							b8_f<='1';
						end if;
					end if;
			end if;
			--btn7
			tog_btn_sh(3)<=pio7;
			tog_btn_sh(2)<=tog_btn_sh(3);
			tog_btn_sh(1)<=tog_btn_sh(2);
			tog_btn_sh(0)<=tog_btn_sh(1);
			if (tog_btn_sh(0)='1') then
				if b7_cnt/=to_unsigned(300000,21) then
					b7_cnt <= b7_cnt + 1;
				else
					if b7_f='1' then
						b7_f<='0';
						toggle <= '0';
					end if;
				end if;
			else
				if (b7_cnt/=to_unsigned(0,21)) then
					b7_cnt<=b7_cnt-1;
				else
					if b7_f='0' then
						b7_f<='1';
					end if;
				end if;
			end if;
			--btn17
			tr_ts_btn_sh(4)<=pio17;
			tr_ts_btn_sh(5)<=tr_ts_btn_sh(4);
			tr_ts_btn_sh(6)<=tr_ts_btn_sh(5);
			tr_ts_btn_sh(7)<=tr_ts_btn_sh(6);
			if (tr_ts_btn_sh(7)='1') then
				if b17_cnt/=to_unsigned(300000,21) then
					b17_cnt <= b17_cnt + 1;
				else
					if b17_f='1' then
						b17_f<='0';
						--Trigger up/down (toggle='1') or Time-scale (toggle='0')
						if toggle='1' and lvl<=to_unsigned(4095,12)-lvl_step then
							lvl_n <= lvl + lvl_step;
						elsif toggle='0' and t_scale < 5 then
							t_scale_n <= t_scale + 1;
						end if;
					end if;
				end if;
			else
				if (b17_cnt/=to_unsigned(0,21)) then
					b17_cnt<=b17_cnt-1;
				else
					if b17_f='0' then
						b17_f<='1';
					end if;
				end if;
			end if;
			--btn16
			tr_ts_btn_sh(3)<=pio16;
			tr_ts_btn_sh(2)<=tr_ts_btn_sh(3);
			tr_ts_btn_sh(1)<=tr_ts_btn_sh(2);
			tr_ts_btn_sh(0)<=tr_ts_btn_sh(1);
			if (tr_ts_btn_sh(0)='1') then
				if b16_cnt/=to_unsigned(300000,21) then
					b16_cnt <= b16_cnt + 1;
				else
					if b16_f='1' then
						b16_f<='0';
						--Trigger up/down (toggle='1') or Time-scale (toggle='0')
						if toggle='1' and lvl>=to_unsigned(0,12)+lvl_step then
							lvl_n <= lvl - lvl_step;
						elsif toggle='0' and t_scale > 1 then
							t_scale_n <= t_scale - 1;
						end if;
					end if;
				end if;
			else
				if (b16_cnt/=to_unsigned(0,21)) then
					b16_cnt<=b16_cnt-1;
				else
					if b16_f='0' then
						b16_f<='1';
					end if;
				end if;
			end if;
			if frame='1' then
				if toggle='1' then
					lvl <= lvl_n;
				else
					t_scale <= t_scale_n;
				end if;
			end if;
			--btn20
			lr_btn_sh(4)<=pio20;
			lr_btn_sh(5)<=lr_btn_sh(4);
			lr_btn_sh(6)<=lr_btn_sh(5);
			lr_btn_sh(7)<=lr_btn_sh(6);
			if (lr_btn_sh(7)='1') then
				if b20_cnt/=to_unsigned(300000,21) then
					b20_cnt <= b20_cnt + 1;
				else
					if b20_f='1' then
						b20_f<='0';
						--Trigger left/right (toggle='1') or Signal left/right (toggle='0')
						if toggle='1' and (tr_h > to_unsigned(5,10)) then
							tr_h_n<=tr_h-to_unsigned(5,10);
						elsif toggle='0' then
							hshift_n<=hshift+to_signed(-5,10);
						end if;
					end if;
				end if;
			else
				if (b20_cnt/=to_unsigned(0,21)) then
					b20_cnt<=b20_cnt-1;
				else
					if b20_f='0' then
						b20_f<='1';
					end if;
				end if;
			end if;


			--btn19
			lr_btn_sh(3)<=pio19;
			lr_btn_sh(2)<=lr_btn_sh(3);
			lr_btn_sh(1)<=lr_btn_sh(2);
			lr_btn_sh(0)<=lr_btn_sh(1);
			if (lr_btn_sh(0)='1') then
				if b19_cnt/=to_unsigned(300000,21) then
					b19_cnt <= b19_cnt + 1;
				else
					if b19_f='1' then
						b19_f<='0';
						--Trigger left/right (toggle='1') or Signal left/right (toggle='0')
						if toggle='1' and (tr_h < grid_left-to_unsigned(6,10)) then
							tr_h_n<=tr_h+to_unsigned(5,10);
						elsif toggle='0' then
							hshift_n<=hshift+to_signed(5,10);
						end if;
					end if;
				end if;
			else
				if (b19_cnt/=to_unsigned(0,21)) then
					b19_cnt<=b19_cnt-1;
				else
					if b19_f='0' then
						b19_f<='1';
					end if;
				end if;
			end if;
			if frame='1' then
				if toggle='1' then
					tr_h<=tr_h_n;
				else
					hshift<=hshift_n;
				end if;
			end if;

			------------------------------------------------------------
			-- DO NOT TOUCH BELOW (Chris: ignore this. Add debounce pls)
			------------------------------------------------------------
			--Up/Down shift--
			--btn23
			ud_btn_sh(4)<=pio23; 
			ud_btn_sh(5)<=ud_btn_sh(4);
			ud_btn_sh(6)<=ud_btn_sh(5);
			ud_btn_sh(7)<=ud_btn_sh(6); 
			if (ud_btn_sh(7)='1') then
				if b23_cnt/=to_unsigned(300000,21) then
					b23_cnt <= b23_cnt + 1;
				else
					if b23_f='1' then
						b23_f<='0';
						if vshift>to_signed(-255,12) then
							vshift_n<=vshift+to_signed(-5,12);
						end if;
					end if;
				end if;
			else
				if (b23_cnt/=to_unsigned(0,21)) then
					b23_cnt<=b23_cnt-1;
				else
					if b23_f='0' then
						b23_f<='1';
					end if;
				end if;
			end if;
			
			--btn22
			ud_btn_sh(3)<=pio22; 
			ud_btn_sh(2)<=ud_btn_sh(3);
			ud_btn_sh(1)<=ud_btn_sh(2);
			ud_btn_sh(0)<=ud_btn_sh(1); 
			if (ud_btn_sh(0)='1') then
				if b22_cnt/=to_unsigned(300000,21) then
					b22_cnt <= b22_cnt + 1;
				else
					if b22_f='1' then
						b22_f<='0';
						if vshift<to_signed(255,12) then
							vshift_n<=vshift+to_signed(5,12);
						end if;
					end if;
				end if;
			else
				if (b22_cnt/=to_unsigned(0,21)) then
					b22_cnt<=b22_cnt-1;
				else
					if b22_f='0' then
						b22_f<='1';
					end if;
				end if;
			end if;
			--Up/Down shift--
			if frame='1' then
				vshift<=vshift_n;
			end if;

			--Amplitude-scale--
			--btn1 (onboard)
			vs_btn_sh(4)<=btn(1); 
			vs_btn_sh(5)<=vs_btn_sh(4);
			vs_btn_sh(6)<=vs_btn_sh(5);
			vs_btn_sh(7)<=vs_btn_sh(6);
			if (vs_btn_sh(7)='1') then
				if b1_cnt/=to_unsigned(300000,21) then
					b1_cnt <= b1_cnt + 1;
				else
					if b1_f='1' then
						b1_f<='0';
						gn_state_n <= gn_state+1;
						if gn_state<to_signed(0,8) then
							if gn_state_n=to_signed(0,8) then
								gain_n <= to_unsigned(1,12);
							else
								gain_n <= gain-1;
							end if;
						else
							gain_n <= gain+1;
						end if;
					end if;
				end if;
			else
				if (b1_cnt/=to_unsigned(0,21)) then
					b1_cnt<=b1_cnt-1;
				else
					if b1_f='0' then
						b1_f<='1';
					end if;
				end if;
			end if;
			--btn0 (onboard)
			vs_btn_sh(3)<=btn(0);
			vs_btn_sh(2)<=vs_btn_sh(3);
			vs_btn_sh(1)<=vs_btn_sh(2);
			vs_btn_sh(0)<=vs_btn_sh(1); 
			if (vs_btn_sh(0)='1') then
				if b0_cnt/=to_unsigned(300000,21) then
					b0_cnt <= b0_cnt + 1;
				else
					if b0_f='1' then
						b0_f<='0';
						gn_state_n <= gn_state - 1;
						if gn_state>to_signed(0,8) then
							if gn_state_n=to_signed(0,8) then
								gain_n <= to_unsigned(1,12);
							else 
								gain_n <= gain-1;
							end if;
						else
							gain_n <= gain+1;
						end if;
					end if;
				end if;
			else
				if (b0_cnt/=to_unsigned(0,21)) then
					b0_cnt<=b0_cnt-1;
				else
					if b0_f='0' then
						b0_f<='1';
					end if;
				end if;
			end if;
			if frame='1' then
				gn_state<=gn_state_n;
				gain<=gain_n;
			end if;
		end if;
	end process;

	------------------------------------------------------------------
	-- ADC Write Buffer Chain
	------------------------------------------------------------------
	led <= ram_led;
	process(fclk,adc_loc,vga_loc) 
	begin
		-- Select next ram in buffer chain, skipping vga_loc
		if adc_loc=vga_loc-1 then
			adc_loc_n <= vga_loc+1;
		else
			adc_loc_n <= adc_loc+1;
		end if;

		if rising_edge(fclk) then -- fclk from cmt 52 MHz for ADC; rdy is synced with fclk
			if rdy='1' then
				-- Transition from State 3->1: Save last-used RAM, Move to next RAM, Reset addrb and detected flag
				if (addrb = std_logic_vector(unsigned(tr_addr) - tr_h - 1))  and detected = '1' then
					prev_adc <= adc_loc;
					adc_loc <= adc_loc_n;
					addrb <= b"00_0000_0000";
					wr_state<=b"00";
					detected <= '0';
					if adc_loc_n = b"00" then
						web <= (0=>rdy,others=>'0');
					elsif adc_loc_n = b"01" then
						web <= (1=>rdy,others=>'0');
					elsif adc_loc_n = b"10" then
						web <= (2=>rdy,others=>'0');
					else
						web <= (3=>rdy,others=>'0');
					end if;
				else
					if adc_loc = b"00" then
						web <= (0=>rdy,others=>'0');
						ram_led(3 downto 2) <= b"00";
					elsif adc_loc = b"01" then
						web <= (1=>rdy,others=>'0');
						ram_led(3 downto 2) <= b"01";
					elsif adc_loc = b"10" then
						web <= (2=>rdy,others=>'0');
						ram_led(3 downto 2) <= b"10";
					else
						web <= (3=>rdy,others=>'0');
						ram_led(3 downto 2) <= b"11";
					end if;
					-- ADC State 1
					if (wr_state=b"00") then
						addrb <= std_logic_vector(unsigned(addrb) + to_unsigned(1,10));
						if addrb=std_logic_vector(tr_h) then
							pretrig <= datab(11 downto 0);
							wr_state<=b"01";
						end if;
					-- ADC State 2
					elsif (wr_state=b"01") then
						addrb <= std_logic_vector(unsigned(addrb) + to_unsigned(1,10));
						if (unsigned(datab(11 downto 0)) >= lvl) and 
							(unsigned(datab(11 downto 0)) > unsigned(pretrig)) then	
							init <= '0';
							detected <= '1';
							wr_state<=b"10";
							tr_addr <= addrb;
						else 
							pretrig <= datab(11 downto 0);
						end if;
					-- ADC State 3
					elsif (wr_state=b"10") then
						addrb <= std_logic_vector(unsigned(addrb) + to_unsigned(1,10));
						-- Save trigger address in the signal corresponding to the current RAM
						if adc_loc = b"00" then
							tr_addr0 <= tr_addr;
						elsif adc_loc = b"01" then
							tr_addr1 <= tr_addr;
						elsif adc_loc = b"10" then
							tr_addr2 <= tr_addr;
						else
							tr_addr3 <= tr_addr;
						end if;
					end if;
					-- -- State 3: Read grid_width/2 + h_shift values after trigger detected
					-- if (detected = '1') then
					-- 	if adc_loc = b"00" then
					-- 		tr_addr0 <= tr_addr;
					-- 	elsif adc_loc = b"01" then
					-- 		tr_addr1 <= tr_addr;
					-- 	elsif adc_loc = b"10" then
					-- 		tr_addr2 <= tr_addr;
					-- 	else
					-- 		tr_addr3 <= tr_addr;
					-- 	end if;
					-- -- State 2: Waiting for trigger (after reading 240 + h_shift initial values)
					-- elsif (signed(addrb) >= signed(grid_width/2) + tr_h) then		
					-- 	if (signed(addrb) = signed(grid_width/2) + tr_h) then		
					-- 		pretrig <= datab(11 downto 0);
					-- 	end if;
					-- 	-- rising edge trigger
					-- 	if (unsigned(datab(11 downto 0)) >= lvl) and 
					-- 		(unsigned(datab(11 downto 0)) > unsigned(pretrig)) then	
					-- 		init <= '0';
					-- 		detected <= '1';
					-- 		tr_addr <= addrb;
					-- 	end if;
					-- end if;
					-- -- State 1: Just read grid_width/2 + h_shift values (common in all 3 states, expect for when changing block RAMs)
					-- addrb <= std_logic_vector(unsigned(addrb) + to_unsigned(1,10));
				end if;
			else
				web <= b"0000";
			end if;
		end if;
	end process;

	------------------------------------------------------------------
	-- VGA read from Buffer Chain 
	------------------------------------------------------------------
	addr_a <= std_logic_vector(signed(ram_idx(9 downto 0))+hshift); 
	process(clkfx,prev_adc,tr_addr0,tr_addr1,tr_addr2,tr_addr3) -- clkfx from cmt2 25.2 MHz for VGA
	begin
		--Set next vga_loc to last RAM used by ADC
		vga_loc_n <= prev_adc;
		--Set addr to start reading at for next RAM
		if prev_adc=b"00" then
			read_addr_n <= tr_addr0;
		elsif prev_adc=b"01" then
			read_addr_n <= tr_addr1;
		elsif prev_adc=b"10" then
			read_addr_n <= tr_addr2;
		else
			read_addr_n <= tr_addr3;
		end if;

		if rising_edge(clkfx) then
			--On new frame, select new RAM-block and set the starting address for VGA read
			if frame='1' then
				vga_loc <= vga_loc_n;	
				read_addr <= read_addr_n;
				if vga_loc_n=to_unsigned(0,2) then
					dataa <= dataa0;
				elsif vga_loc_n<=to_unsigned(1,2) then
					dataa <= dataa1;
				elsif vga_loc_n<=to_unsigned(2,2) then
					dataa <= dataa2;
				else
					dataa <= dataa3;
				end if;
			--In the same frame, index to RAM using VGA starting address + hcount
			else
				ram_idx <= std_logic_vector(signed(unsigned(read_addr)+hcount));
				if vga_loc=to_unsigned(0,2) then
					dataa <= dataa0;
					ram_led(1 downto 0) <= b"00";
				elsif vga_loc<=to_unsigned(1,2) then
					dataa <= dataa1;
					ram_led(1 downto 0) <= b"01";
				elsif vga_loc<=to_unsigned(2,2) then
					dataa <= dataa2;
					ram_led(1 downto 0) <= b"10";
				else
					dataa <= dataa3;
					ram_led(1 downto 0) <= b"11";
				end if;
			end if;
		end if;
	end process;

	------------------------------------------------------------------
	-- Generate test signal: square wave
	------------------------------------------------------------------
	pio31 <= out31;
	--Test signal 1: square wave alternate every 1040-1 counts
	process(fclk) 
	begin
		if rising_edge(fclk) then
			counter <= counter + to_unsigned(1,11);
			if (counter = "00000000000") then -- 1040 10000010000
				out31 <= not out31;
				counter <= b"00000000001";
			end if;
		end if;
	end process;

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
	-- Output Trace, Trigger, Grid to VGA
	------------------------------------------------------------------
	ratio <= 4096/grid_height;
	
	process(clkfx,grd_red,grd_blu,grd_grn,line_red,line_grn,line_blu)
    begin
        if rising_edge(clkfx) then
			-- Draw grid
			if vcount>=grid_top and vcount<=grid_bottom and hcount>=grid_left and hcount<=grid_right and 
				(vcount=grid_top or vcount=scaled_trig or vcount=grid_bottom or --grid_top+grid_height/2
				 hcount=grid_left or hcount=unsigned(grid_left+tr_h) or hcount=grid_right) then
				grd_red<=b"10";
				grd_grn<=b"10";
				grd_blu<=b"10";
            elsif vcount>=grid_top and vcount<=grid_bottom and hcount>=grid_left and hcount<=grid_right and
				(vcount=grid_top+grid_height/4 or vcount=grid_top+grid_height/2 or vcount=grid_top+3*grid_height/4 or 
				 hcount=grid_left+grid_width/4 or hcount=grid_left+grid_width/2 or hcount=grid_left+3*grid_width/4 or
				 hcount=grid_left+grid_width/8 or hcount=grid_left+3*grid_width/8 or
				 hcount=grid_left+5*grid_width/8 or hcount=grid_left+7*grid_width/8) then
				grd_red<=b"01";            
				grd_grn<=b"01";
				grd_blu<=b"01";
            else
                grd_red<=b"00";            
                grd_grn<=b"00";
                grd_blu<=b"00";
            end if;
			-- Draw signal
			if gn_state>=to_signed(0,8) then
				scaled_sig <= grid_top+grid_height- gain*unsigned(dataa(11 downto 0))/ratio;
			else
				scaled_sig(11 downto 0) <= grid_top+grid_height- unsigned(dataa(11 downto 0))/ratio/gain;
			end if;
            if init='0' and 
				vcount>=grid_top and vcount<=grid_bottom and hcount>=grid_left and hcount<=grid_right and
				vcount=unsigned(signed(scaled_sig)+vshift) then	--unsigned(dataa(11 downto 0))/(4096/grid-height)
				line_red<=b"00";            
				line_grn<=b"11";
				line_blu<=b"00";
			else
				line_red<=b"00";            
				line_grn<=b"00";
				line_blu<=b"00";
			end if;
			-- Scale Trigger line
			scaled_trig <= grid_top+grid_height-lvl/ratio;
        end if;

		-- Make trace appear before grid and trigger line
		if (line_red=b"00" and line_grn=b"00" and line_blu=b"00") then
			if (trig_red=b"00" and trig_grn=b"00" and trig_blu=b"00") then
				screen_red <= grd_red;
				screen_grn <= grd_grn;
				screen_blu <= grd_blu;
			else
				screen_red <= trig_red;
				screen_grn <= trig_grn;
				screen_blu <= trig_blu;
			end if;
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