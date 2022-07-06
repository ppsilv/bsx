# bsx forked from breakintoprogram/bsx

#### Z80 based homebrew computer
This project is a Z80 based computer designed to run as a MSX.
It is a work-in-progress, and the current specs are:
- 32K of ROM (EEPROM for ease of reprogramming)
- 64K of RAM
- A very basic machine code monitor and disassembler in ROM
- BBC Basic for Z80
- Serial I/O via an TL16C550CN UART
- Serial I2C LCD1602 only for fun

The intention is to work towards a fully functioning MSX1 clone , with a TMS9938 video chip and AY-8912 sound
#### What's provided
I am providing all the files under an MIT license for the hardware and the software, with the following exceptions:
- BBC Basic: This is provided under the terms of a [zlib license](https://opensource.org/licenses/Zlib) by R.T.Russell
