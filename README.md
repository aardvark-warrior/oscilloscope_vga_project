# Oscilloscope with VGA Display 

## **I. Description** <br />
A self-contained 0 - 3.3 V rising-edge, normal, adjustable trigger oscilloscope with VGA display on [Xilinx Cmod S7: Breadboardable Spartan-7 FPGA Module](https://www.xilinx.com/products/boards-and-kits/1-w51rey.html) written in VHDL.

### **Features** <br />
- Static grid (display)
- Buffering (4-block ring)
- Adjustable, normal trigger (vertical and horizontal)
- Vertical signal display adjustment
- Horizontal signal display adjustment
- Time base adjustment
- Amplitude/gain adjustment

## **II. Design** <br />
### **1. Oscilloscope** <br />
Oscilloscope uses on-board ADC to sample through analog input pins at 1 MHz and writes 12-bit data to 4-block RAM buffer ring. Each block RAM can hold 1024 readings. Uses 52 MHz clock from CMT1.

### **2. VGA** <br />
VGA module draws signal (in green) over 8x4 static grid (in grey) the covers 640x256 pixels in a 640x480 screen. Adjustable trigger shown as cross (in white), spans the entire grid and follows shifts/scales of signal display. Uses 25.2 MHz clock from CMT2; chosen to account for front-porch, back-porch, and sync delays of 640x480 screen to achieve 60 Hz.

### **3. RAM buffer ring** <br />
Block RAM buffer chain uses 4-block design to prevent ping-ponging. ADC writes to buffer chain in a circle, skipping the RAM block used by the VGA. This design is resilient against cases where ADC and VGA operate at different rates on the same RAM block, causing data to be overwritten mid-read. VGA always reads from RAM block most recently-used by ADC to get newest data.




## **III. Files** <br />
**Top level:** <br />
- `Ocilloscope` in Oscilloscope.vhd

**Dependencies:** <br />
- `Oscilloscope_gui` in Oscilloscope_gui.vhd: gui to interface with MATLAB oscope *(currently unused)*

- `Oscilloscope_adc` in Oscilloscope_adc.vhd: Analog/Digital Converter 

- `Oscilloscope_ram` in Oscilloscope_ram.vhd: Block RAM 

- `Oscilloscope_cmt` in Oscilloscope_cmt.vhd: Clock Management Tile (used for RAM and VGA in top level)

**Constraints:** <br />
- `Oscilloscope` in Oscilloscope.xdc

