# 12 MHz System Clock
set_property -dict { PACKAGE_PIN M9    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L13P_T2_MRCC_14 Sch=gclk
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { clk }];

# USB UART
set_property -dict { PACKAGE_PIN L12   IOSTANDARD LVCMOS33 } [get_ports { tx }]; #IO_L6N_T0_D08_VREF_14 Sch=uart_rxd_out
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { rx }]; #IO_L5N_T0_D07_14 Sch=uart_txd_in

# Analog Inputs on PIO Pins 32 and 33
set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports { vaux5_p }]; #IO_L12P_T1_MRCC_AD5P_15 Sch=ain_p[32]
set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports { vaux5_n }]; #IO_L12N_T1_MRCC_AD5N_15 Sch=ain_n[32]

# Neighboring pin
set_property -dict { PACKAGE_PIN J11   IOSTANDARD LVCMOS33 } [get_ports { pio31 }]; #IO_0_14 Sch=pio[31]

# Digital I/O for Buttons
set_property -dict { PACKAGE_PIN N1    IOSTANDARD LVCMOS33 } [get_ports { pio9 }]; #IO_L22N_T3_34 Sch=pio[09]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { pio16 }]; #IO_L11P_T1_SRCC_14 Sch=pio[16]
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { pio17 }]; #IO_L11N_T1_SRCC_14 Sch=pio[17]
set_property -dict { PACKAGE_PIN N13   IOSTANDARD LVCMOS33 } [get_ports { pio18 }]; #IO_L8N_T1_D12_14 Sch=pio[18]
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { pio19 }]; #IO_L10N_T1_D15_14 Sch=pio[19]
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { pio20 }]; #IO_L10P_T1_D14_14 Sch=pio[20]
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { pio21 }]; #IO_L9N_T1_DQS_D13_14 Sch=pio[21]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { pio22 }]; #IO_L9P_T1_DQS_14 Sch=pio[22]
set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { pio23 }]; #IO_L4N_T0_D05_14 Sch=pio[23]

# LEDs
set_property -dict { PACKAGE_PIN E2    IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L8P_T1_34 Sch=led[1]
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; #IO_L16P_T2_34 Sch=led[2]
set_property -dict { PACKAGE_PIN J1    IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; #IO_L16N_T2_34 Sch=led[3]
set_property -dict { PACKAGE_PIN E1    IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; #IO_L8N_T1_34 Sch=led[4]

# Push Buttons
set_property -dict { PACKAGE_PIN D2    IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]; #IO_L6P_T0_34 Sch=btn[0]
set_property -dict { PACKAGE_PIN D1    IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; #IO_L6N_T0_VREF_34 Sch=btn[1]

# VGA
# Pmod Header JA
set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports { red[0] }]; #IO_L14P_T2_SRCC_34 Sch=ja[1]
set_property -dict { PACKAGE_PIN H3    IOSTANDARD LVCMOS33 } [get_ports { red[1] }]; #IO_L13N_T2_MRCC_34 Sch=ja[7]
set_property -dict { PACKAGE_PIN H2    IOSTANDARD LVCMOS33 } [get_ports { green[0] }]; #IO_L14N_T2_SRCC_34 Sch=ja[2]
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { green[1] }]; #IO_L12P_T1_MRCC_34 Sch=ja[8]
set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { blue[0] }]; #IO_L13P_T2_MRCC_34 Sch=ja[3]
set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { blue[1] }]; #IO_L12N_T1_MRCC_34 Sch=ja[9]
set_property -dict { PACKAGE_PIN F4    IOSTANDARD LVCMOS33 } [get_ports { hsync }]; #IO_L11P_T1_SRCC_34 Sch=ja[10]
set_property -dict { PACKAGE_PIN F3    IOSTANDARD LVCMOS33 } [get_ports { vsync }]; #IO_L11N_T1_SRCC_34 Sch=ja[4]

# USB UART
set_property -dict { PACKAGE_PIN L13   IOSTANDARD LVCMOS33 } [get_ports { tvx }]; #IO_L6N_T0_D08_VREF_14 Sch=uart_rxd_out