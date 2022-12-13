# FPGA Synthesis Lab Final Project

## Oscilloscope with VGA Display 

*using VHDL on Xilinx Cmod S7*

### **Files**

**Top level:** 

- `Ocilloscope` in Oscilloscope.vhd

**Components:**

- `Oscilloscope_gui` in Oscilloscope_gui.vhd: gui to interface with MATLAB oscope

- `Oscilloscope_adc` in Oscilloscope_adc.vhd: Analog/Digital Converter implementation

- `Oscilloscope_ram` in Oscilloscope_ram.vhd: RAM implementation

- `Oscilloscope_cmt` in Oscilloscope_cmt.vhd: Clock Management Tile for RAM

**Constraints:**

- `Oscilloscope` in Oscilloscope.xdc


### **12/13/2022 1:00 AM**
Worked on Buffer Chain 2.0 just now. Made two signals to track location of ADC and VGA in the buffer chain. Implemented two processes with two-segment style, `process(frame,adc_loc)` and `process(rdy,vga_loc)`, to update `vga_loc`, `vga_loc_next`, `adc_loc`, `adc_loc_next`, and to switch ram blocks that VGA and ADC use.

My current understanding is that is follows:

- Read: We let all ram blocks share `addra_i=>addr_a`; to switch ram block for VGA, we just change what `dataa_` (used by VGA) is driven by: `data0`, `data1`, `data2`, or `data3` (each is the output of a different ram block).

- Write: We let all ram blocks share `addrb_i=>addrb` and `datab_i=>datab_`; to switch ram block for ADC, we just toggle the bits in `web` so that only one-bit is ever hooked up to `rdy`: `web(0)`, `web(1)`, `web(2)`, `web(3)` (each bit controls write-enable for a different ram block).
