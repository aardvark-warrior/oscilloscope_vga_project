library IEEE;
use IEEE.std_logic_1164.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity Oscilliscope_ram is
	port(
		clka_i:  in  std_logic;
		wea_i:   in  std_logic; -- pull high to write
		addra_i: in  std_logic_vector(9 downto 0);
		dataa_i: in  std_logic_vector(35 downto 0);  -- data to be written
		dataa_o: out std_logic_vector(35 downto 0);  -- data to be read
		clkb_i:  in  std_logic;
		web_i:   in  std_logic;
		addrb_i: in  std_logic_vector(9 downto 0);
		datab_i: in  std_logic_vector(35 downto 0);
		datab_o: out std_logic_vector(35 downto 0)
	);
end Oscilliscope_ram;

architecture arch of Oscilliscope_ram is
	signal wea_l:   std_logic_vector(3 downto 0);
	signal addra_l: std_logic_vector(15 downto 0);
	signal web_l:   std_logic_vector(7 downto 0);
	signal addrb_l: std_logic_vector(15 downto 0);
begin
	wea_l<=(others=>wea_i);
	addra_l<='1'&addra_i&b"00000";
	web_l<=(others=>web_i);
	addrb_l<='1'&addrb_i&b"00000";

	ram: RAMB36E1 generic map (
		-- Address Collision Mode:
		RDADDR_COLLISION_HWCONFIG=>"DELAYED_WRITE",
		-- Collision check:
		SIM_COLLISION_CHECK=>"ALL", -- Generate warnings on all collisions
		-- Optional output registers:
		DOA_REG=>0, -- Disable output register on port A
		DOB_REG=>0, -- Disable output register on port B
		-- Optional error correction circuitry
		EN_ECC_READ=>FALSE, -- Disable ECC on read
		EN_ECC_WRITE=>FALSE,-- Disable ECC on write
		-- Initial values on output ports
		INIT_A=>X"000000000",
		INIT_B=>X"000000000",
		-- Initialization File:
		INIT_FILE=>"NONE",
		-- RAM Mode:
		RAM_MODE=>"TDP",-- True dual port mode
		-- Selects cascade mode:
		RAM_EXTENSION_A=>"NONE",
		RAM_EXTENSION_B=>"NONE",
		-- Read/write width per port:
		READ_WIDTH_A=>36,
		READ_WIDTH_B=>36,
		WRITE_WIDTH_A=>36,
		WRITE_WIDTH_B=>36,
		-- Reset or enable priority:
		RSTREG_PRIORITY_A=>"RSTREG",
		RSTREG_PRIORITY_B=>"RSTREG",
		-- Set/reset value for output:
		SRVAL_A=>X"000000000",
		SRVAL_B=>X"000000000",
		-- Simulation Device:
		SIM_DEVICE=>"7SERIES",
		-- WriteMode:
		WRITE_MODE_A=>"WRITE_FIRST",
		WRITE_MODE_B=>"WRITE_FIRST"
	) port map (
		-- Cascade Signals:
		CASCADEOUTA=>open,              -- 1-bit output: A port cascade
		CASCADEOUTB=>open,              -- 1-bit output: B port cascade
		-- ECC Signals:
		DBITERR=>open,                  -- 1-bit output: Double bit error status
		ECCPARITY=>open,                -- 8-bit output: Generated error correction parity
		RDADDRECC=>open,                -- 9-bit output: ECC read address
		SBITERR=>open,                  -- 1-bit output: Single bit error status
		-- Port A Data Out:
		DOADO=>dataa_o(31 downto 0),    -- 32-bit output: A port data/LSB data
		DOPADOP=>dataa_o(35 downto 32), -- 4-bit output: A port parity/LSB parity
		-- Port B Data Out:
		DOBDO=>datab_o(31 downto 0),    -- 32-bit output: B port data/MSB data
		DOPBDOP=>datab_o(35 downto 32), -- 4-bit output: B port parity/MSB parity
		-- Cascade Signals:
		CASCADEINA=>'0',                -- 1-bit input: A port cascade
		CASCADEINB=>'0',                -- 1-bit input: B port cascade
		-- ECC Signals:
		INJECTDBITERR=>'0',             -- 1-bit input: Inject a double bit error
		INJECTSBITERR=>'0',             -- 1-bit input: Inject a single bit error
		-- Port A Address/Control Signals:
		ADDRARDADDR=>addra_l,           -- 16-bit input: A port address
		CLKARDCLK=>clka_i,              -- 1-bit input: A port clock
		ENARDEN=>'1',                   -- 1-bit input: A port enable
		REGCEAREGCE=>'1',               -- 1-bit input: A port register enable
		RSTRAMARSTRAM=>'0',             -- 1-bit input: A port set/reset
		RSTREGARSTREG=>'0',             -- 1-bit input: A port register set/reset
		WEA=>wea_l,                     -- 4-bit input: A port write enable
		-- Port A Data In:
		DIADI=>dataa_i(31 downto 0),    -- 32-bit input: A port data
		DIPADIP=>dataa_i(35 downto 32),  -- 4-bit input: A port parity
		-- Port B Address/Control Signals:
		ADDRBWRADDR=>addrb_l,           -- 16-bit input: B port address
		CLKBWRCLK=>clkb_i,              -- 1-bit input: B port clock
		ENBWREN=>'1',                   -- 1-bit input: B port enable
		REGCEB=>'1',                    -- 1-bit input: B port register enable
		RSTRAMB=>'0',                   -- 1-bit input: B port set/reset
		RSTREGB=>'0',                   -- 1-bit input: B port register set/reset
		WEBWE=>web_l,                   -- 8-bit input: B port write enable
		-- Port B Data: 32-bit (each) input: Port B data
		DIBDI=>datab_i(31 downto 0),    -- 32-bit input: B port data
		DIPBDIP=>datab_i(35 downto 32)  -- 4-bit input: B port parity
	);
end arch;