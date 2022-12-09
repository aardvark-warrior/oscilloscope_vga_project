library IEEE;
use IEEE.std_logic_1164.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity Oscilliscope_adc is
	port(
		clk:     in  std_logic;
		vaux5_n: in  std_logic;  -- neg terminal
		vaux5_p: in  std_logic;  -- pos terminal
		rdy:     out std_logic;  -- 
		data:    out std_logic_vector(11 downto 0)
	);
end Oscilliscope_adc;

architecture arch of Oscilliscope_adc is
	signal eoc:   std_logic;
	signal vauxn: std_logic_vector(15 downto 0);
	signal vauxp: std_logic_vector(15 downto 0);
	signal temp:  std_logic_vector(15 downto 0);
begin
	vauxn<=b"0000000000"&vaux5_n&b"00000";
	vauxp<=b"0000000000"&vaux5_p&b"00000";
	data<=temp(15 downto 4);

	adc: XADC generic map (
		-- INIT_40 to INIT_5F: see page 34 of user guide ug480 
		--
		-- INIT_40: Configuration register 0
		-- bits   4-0: CH4-0  ADC channel
		-- bits   7-5:        unused
		-- bit      8: ACQ    enable increased settling time (+6 clock cycles)
		-- bit      9: E/C    event/not continuous
		-- bit     10: B/U    bipolar/not unipolar
		-- bit     11: MUX    enable external multiplexor
		-- bits 13-12: AVG1-0 averaging mode:
		--                    00 no averaging
		--                    01 average 16 samples
		--                    10 average 64 samples
		--                    11 average 256 samples
		-- bit     14:        unused
		-- bit     15: CAVG   enable calibration averaging
		INIT_40=>b"0_0_00_0_0_0_0_000_10101",
		--
		-- INIT_41: Configuration register 1
		-- bit      0: OT   disable over-temperature alarm
		-- bit      1: ALM0 disable 
		-- bit      2: ALM1 disable Vccint alarm
		-- bit      3: ALM2 disable Vccaux alarm
		-- bit      4: CAL0 enable offset correction
		-- bit      5: CAL1 enable gain and offset correction
		-- bit      6: CAL2 enable supply sensor offset correction
		-- bit      7: CAL3 enable supply sensor gain and offset correction
		-- bit      8: ALM3 disable Vccbram alarm
		-- bit      9: ALM4 disable Vccpint alarm (Zynq only)
		-- bit     10: ALM5 disable Vccpaux alarm (Zynq only)
		-- bit     11: ALM6 disable Vcco_ddr alarm (Zynq only)
		-- bits 15-12: SEQ3-0 sequencer operation:
		--                    0000 default mode
		--                    0001 single pass sequence
		--                    0010 continuous sequence mode
		--                    0011 single channel mode (sequencer off)
		--                    01xx simultaneous sampling mode
		--                    10xx independent ADC mode
		--                    11xx default mode
		INIT_41=>b"0011_1111_0000_111_1",
		--
		-- INIT_42: Configuration register 2
		-- bits  3-0:       unused
		-- bits  5-4: PD1-0 power down selection:
		--                  00 all powered up
		--                  01 not valid - do not select
		--                  10 ADC B powered down
		--                  11 all powered down
		-- bits  7-6:       unused
		-- bits 15-8: CD7-0 DCLK divider
		--                  00000000 divide by 2
		--                  00000001 divide by 2
		--                  00000010 divide by 2
		--                  00000011 divide by 3
		--                  00000100 divide by 4
		--                  ...
		--                  11111111 divide by 255
		INIT_42=>b"00000010_00_10_0000",
		-- 
		-- INIT_43 to INIT_47: test registers, leave at 0x0000
		INIT_43=>X"0000",
		INIT_44=>X"0000",
		INIT_45=>X"0000",
		INIT_46=>X"0000",
		INIT_47=>X"0000",
		--
		-- INIT_48: Sequencer channel selection register
		--          Enable channel acquisition in seqence
		-- bit    0: calibration channel (channel 8, sequence 1)
		-- bits 7-1: invalid channels (channels 9 to 15)
		-- bit    8: on-chip temperature (channel 0, sequence 2)
		-- bit    9: Vccint (channel 1, sequence 3)
		-- bit   10: Vccaux (channel 2, sequence 4)
		-- bit   11: Vp/n (channel 3, sequence 5)
		-- bit   12: Vrefp (channel 4, sequence 6)
		-- bit   13: Vrefn (channel 5, sequence 7)
		-- bit   14: Vccbram (channel 6, sequence 8)
		-- bit   15: invalid channel (channel 7)
		INIT_48=>X"0000",
		--
		-- INIT_49: Sequencer auxiliary channel selection register
		--          Enable channel acquisition in seqence
		-- bit  0: Vauxp/n[0] (channel 16, sequence 9)
		-- bit  1: Vauxp/n[1] (channel 17, sequence 10)
		-- bit  2: Vauxp/n[2] (channel 18, sequence 11)
		-- bit  3: Vauxp/n[3] (channel 19, sequence 12)
		-- bit  4: Vauxp/n[4] (channel 20, sequence 13)
		-- bit  5: Vauxp/n[5] (channel 21, sequence 14)
		-- bit  6: Vauxp/n[6] (channel 22, sequence 15)
		-- bit  7: Vauxp/n[7] (channel 23, sequence 16)
		-- bit  8: Vauxp/n[8] (channel 24, sequence 17)
		-- bit  9: Vauxp/n[9] (channel 25, sequence 18)
		-- bit 10: Vauxp/n[10] (channel 26, sequence 19)
		-- bit 11: Vauxp/n[11] (channel 27, sequence 20)
		-- bit 12: Vauxp/n[12] (channel 28, sequence 21)
		-- bit 13: Vauxp/n[13] (channel 29, sequence 22)
		-- bit 14: Vauxp/n[14] (channel 30, sequence 23)
		-- bit 15: Vauxp/n[15] (channel 31, sequence 24)
		INIT_49=>X"0000",
		--
		-- INIT_4A: Sequencer channel averaging register
		--          Enable averaging on specified channel
		-- bit    0: calibration channel (channel 8, sequence 1)
		-- bits 7-1: invalid channels (channels 9 to 15)
		-- bit    8: on-chip temperature (channel 0, sequence 2)
		-- bit    9: Vccint (channel 1, sequence 3)
		-- bit   10: Vccaux (channel 2, sequence 4)
		-- bit   11: Vp/n (channel 3, sequence 5)
		-- bit   12: Vrefp (channel 4, sequence 6)
		-- bit   13: Vrefn (channel 5, sequence 7)
		-- bit   14: Vccbram (channel 6, sequence 8)
		-- bit   15: invalid channel (channel 7)
		INIT_4A=>X"0000",
		--
		-- INIT_4B: Sequencer auxiliary channel averaging register
		--          Enable averaging on specified channel
		-- bit  0: Vauxp/n[0] (channel 16, sequence 9)
		-- bit  1: Vauxp/n[1] (channel 17, sequence 10)
		-- bit  2: Vauxp/n[2] (channel 18, sequence 11)
		-- bit  3: Vauxp/n[3] (channel 19, sequence 12)
		-- bit  4: Vauxp/n[4] (channel 20, sequence 13)
		-- bit  5: Vauxp/n[5] (channel 21, sequence 14)
		-- bit  6: Vauxp/n[6] (channel 22, sequence 15)
		-- bit  7: Vauxp/n[7] (channel 23, sequence 16)
		-- bit  8: Vauxp/n[8] (channel 24, sequence 17)
		-- bit  9: Vauxp/n[9] (channel 25, sequence 18)
		-- bit 10: Vauxp/n[10] (channel 26, sequence 19)
		-- bit 11: Vauxp/n[11] (channel 27, sequence 20)
		-- bit 12: Vauxp/n[12] (channel 28, sequence 21)
		-- bit 13: Vauxp/n[13] (channel 29, sequence 22)
		-- bit 14: Vauxp/n[14] (channel 30, sequence 23)
		-- bit 15: Vauxp/n[15] (channel 31, sequence 24)
		INIT_4B=>X"0000",
		--
		-- INIT_4C: Sequencer channel input mode register
		--          Enable bipolar mode/disable unipolar mode (Vp/n only)
		-- bit    0: calibration channel (channel 8, sequence 1)
		-- bits 7-1: invalid channels (channels 9 to 15)
		-- bit    8: on-chip temperature (channel 0, sequence 2)
		-- bit    9: Vccint (channel 1, sequence 3)
		-- bit   10: Vccaux (channel 2, sequence 4)
		-- bit   11: Vp/n (channel 3, sequence 5)
		-- bit   12: Vrefp (channel 4, sequence 6)
		-- bit   13: Vrefn (channel 5, sequence 7)
		-- bit   14: Vccbram (channel 6, sequence 8)
		-- bit   15: invalid channel (channel 7)
		INIT_4C=>X"0000",
		--
		-- INIT_4D: Sequencer auxiliary channel input mode register
		--          Enable bipolar mode/disable unipolar mode
		-- bit  0: Vauxp/n[0] (channel 16, sequence 9)
		-- bit  1: Vauxp/n[1] (channel 17, sequence 10)
		-- bit  2: Vauxp/n[2] (channel 18, sequence 11)
		-- bit  3: Vauxp/n[3] (channel 19, sequence 12)
		-- bit  4: Vauxp/n[4] (channel 20, sequence 13)
		-- bit  5: Vauxp/n[5] (channel 21, sequence 14)
		-- bit  6: Vauxp/n[6] (channel 22, sequence 15)
		-- bit  7: Vauxp/n[7] (channel 23, sequence 16)
		-- bit  8: Vauxp/n[8] (channel 24, sequence 17)
		-- bit  9: Vauxp/n[9] (channel 25, sequence 18)
		-- bit 10: Vauxp/n[10] (channel 26, sequence 19)
		-- bit 11: Vauxp/n[11] (channel 27, sequence 20)
		-- bit 12: Vauxp/n[12] (channel 28, sequence 21)
		-- bit 13: Vauxp/n[13] (channel 29, sequence 22)
		-- bit 14: Vauxp/n[14] (channel 30, sequence 23)
		-- bit 15: Vauxp/n[15] (channel 31, sequence 24)
		INIT_4D=>X"0000",
		--
		-- INIT_4E: Sequencer channel acquisition time register
		--          Enable extended acquisition time (+6 clock cycles)
		-- bit    0: calibration channel (channel 8, sequence 1)
		-- bits 7-1: invalid channels (channels 9 to 15)
		-- bit    8: on-chip temperature (channel 0, sequence 2)
		-- bit    9: Vccint (channel 1, sequence 3)
		-- bit   10: Vccaux (channel 2, sequence 4)
		-- bit   11: Vp/n (channel 3, sequence 5)
		-- bit   12: Vrefp (channel 4, sequence 6)
		-- bit   13: Vrefn (channel 5, sequence 7)
		-- bit   14: Vccbram (channel 6, sequence 8)
		-- bit   15: invalid channel (channel 7)
		INIT_4E=>X"0000",
		--
		-- INIT_4F: Sequencer auxiliary channel acquisition time register
		--          Enable extended acquisition time (+6 clock cycles)
		-- bit  0: Vauxp/n[0] (channel 16, sequence 9)
		-- bit  1: Vauxp/n[1] (channel 17, sequence 10)
		-- bit  2: Vauxp/n[2] (channel 18, sequence 11)
		-- bit  3: Vauxp/n[3] (channel 19, sequence 12)
		-- bit  4: Vauxp/n[4] (channel 20, sequence 13)
		-- bit  5: Vauxp/n[5] (channel 21, sequence 14)
		-- bit  6: Vauxp/n[6] (channel 22, sequence 15)
		-- bit  7: Vauxp/n[7] (channel 23, sequence 16)
		-- bit  8: Vauxp/n[8] (channel 24, sequence 17)
		-- bit  9: Vauxp/n[9] (channel 25, sequence 18)
		-- bit 10: Vauxp/n[10] (channel 26, sequence 19)
		-- bit 11: Vauxp/n[11] (channel 27, sequence 20)
		-- bit 12: Vauxp/n[12] (channel 28, sequence 21)
		-- bit 13: Vauxp/n[13] (channel 29, sequence 22)
		-- bit 14: Vauxp/n[14] (channel 30, sequence 23)
		-- bit 15: Vauxp/n[15] (channel 31, sequence 24)
		INIT_4F=>X"0000",
		--
		-- INIT_50: Temperature upper alarm limit
		INIT_50=>X"0000",
		--
		-- INIT_51: Vccint upper alarm limit
		INIT_51=>X"0000",
		--
		-- INIT_52: Vccaux upper alarm limit
		INIT_52=>X"0000",
		--
		-- INIT_53: OT power down set threshold
		INIT_53=>X"0000",
		--
		-- INIT_54: Temperature lower alarm limit
		INIT_54=>X"0000",
		--
		-- INIT_55: Vccint lower alarm limit
		INIT_55=>X"0000",
		--
		-- INIT_56: Vccaux lower alarm limit
		INIT_56=>X"0000",
		--
		-- INIT_57: OT power down reset threshold
		INIT_57=>X"0000",
		--
		-- INIT_58: Vccbram upper alarm limit
		INIT_58=>X"0000",
		--
		-- INIT_59: Vccpint upper alarm limit (Zynq only)
		INIT_59=>X"0000",
		--
		-- INIT_5A: Vccpaux upper alarm limit (Zynq only)
		INIT_5A=>X"0000",
		--
		-- INIT_5B: Vcco_ddr upper alarm limit (Zynq only)
		INIT_5B=>X"0000",
		--
		-- INIT_5C: Vccbram lower alarm limit
		INIT_5C=>X"0000",
		--
		-- INIT_5D: Vccpint lower alarm limit (Zynq only)
		INIT_5D=>X"0000",
		--
		-- INIT_5E: Vccpaux lower alarm limit (Zynq only)
		INIT_5E=>X"0000",
		--
		-- INIT_5F: Vcco_ddr lower alarm limit (Zynq only)
		INIT_5F=>X"0000",
		--
		-- Simulation attributes:
		SIM_DEVICE=>"7SERIES",        -- Select target device (values)
		SIM_MONITOR_FILE=>"data.txt"  -- Analog simulation data file name
	) port map (
		-- ALARMS:
		ALM=>open,          -- 8-bit output: Output alarm for temp, Vccint, Vccaux and Vccbram
		OT=>open,           -- 1-bit output: Over-Temperature alarm
		-- Dynamic Reconfiguration Port (DRP):
		DO=>temp,           -- 16-bit output: DRP output data bus
		DRDY=>rdy,          -- 1-bit output: DRP data ready
		-- XADC status ports:
		BUSY=>open,         -- 1-bit output: ADC busy output
		CHANNEL=>open,      -- 5-bit output: Channel selection outputs
		EOC=>eoc,           -- 1-bit output: End of Conversion
		EOS=>open,          -- 1-bit output: End of Sequence
		JTAGBUSY=>open,     -- 1-bit output: JTAG DRP transaction in progress output
		JTAGLOCKED=>open,   -- 1-bit output: JTAG requested DRP port lock
		JTAGMODIFIED=>open, -- 1-bit output: JTAG Write to the DRP has occurred
		MUXADDR=>open,      -- 5-bit output: External MUX channel decode
		-- Auxiliary Analog-Input Pairs:
		VAUXN=>vauxn,       -- 16-bit input: N-side auxiliary analog input
		VAUXP=>vauxp,       -- 16-bit input: P-side auxiliary analog input
		-- Event Conversion Clock and Reset:
		CONVST=>'0',        -- 1-bit input: Convert start input (not clock net)
		CONVSTCLK=>'0',     -- 1-bit input: Convert start input (from clock net)
		RESET=>'0',         -- 1-bit input: Active-high reset
		-- Dedicated Analog Input Pair:
		VN=>'0',            -- 1-bit input: N-side analog input
		VP=>'0',            -- 1-bit input: P-side analog input
		-- Dynamic Reconfiguration Port (DRP):
		DADDR=>b"001_0101", -- 7-bit input: DRP address bus
		DCLK=>clk,          -- 1-bit input: DRP clock
		DEN=>eoc,           -- 1-bit input: DRP enable signal
		DI=>x"0000",        -- 16-bit input: DRP input data bus
		DWE=>'0'            -- 1-bit input: DRP write enable
	);
end arch;