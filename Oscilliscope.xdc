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

#VGA
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