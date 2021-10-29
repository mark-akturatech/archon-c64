# Archon

Reverse engineer of C64 Archon (c) 1983 by Free Fall Associates.

The code is intended to be a byte by byte replication of the source logic possible. Some very minor liberties have
been taken where there were no options. In this case, i have included the code in an 'not_original.asm' file.

NOTE that the code does not reside in the original memory locations. The code was replicated to be fully relocatable
and therefore is loaded in to contiguous memory for ultimate readability.

Extensive comments have been provided to help understand the code.

## Build

Build using Kick Assembler.

## Tools

Extensive use of the following tools were used to help with this project:
- [Jc64dis](https://iceteam.itch.io/jc64dis): disassembler
- [Infiltrator](https://csdb.dk/release/?id=100129): disassembler, reverse engineering tool
- [VChar64](https://github.com/ricardoquesada/vchar64): for loading and previewing character sets
- [Sprite Pad](https://csdb.dk/release/?id=132081): for exporting sprites
- [Kick Assembler](http://theweb.dk/KickAssembler/Main.html#frontpage) and [KickAss (C64)](https://marketplace.visualstudio.com/items?itemName=CaptainJiNX.kickass-c64&ssr=false#review-details)
  vscode extension
- [Mapping the C64](http://unusedino.de/ec64/technical/project64/mapping_c64.html) and [C64 memory map](http://unusedino.de/ec64/technical/project64/mapping_c64.html).

## Notes

Archon initially launches via a basic program with a sys command. The initial code just decrypts the code and
moves stuff around. We will therefore not reverse engineer this part of the application.

Below is a breif synopsis of what is going on here:

### Block 1: 0801 to 0827

Basic program:
1986 SYS2088

### Block 2: 082B to 0858

Moves the entire code from the current loaded location to 0x68f7 to 0xffff. The move routine uses the zero page
registers 0x00ae/af which hold the end address of the last loaded file byte and copies backwards from there.
Therefore the app will not work if the file is not the exact correct size.

The block then copies in to 0x00ab: 4c 00 01 01 80 0c 6a

And finally copies 0x085f-0x095e to 0x0100-0x01ff and then executes 0x0100.

### Block 3: 0100 to 01ff

Some interesting logic lives here. All it does is move stuff around and performs copy logic. It takes the source code in
0x6a00 to 0xffff and moves stuff around to various memory locations. This block also copies data in to the character
data area on our graphic block.

It then executes 6100.

### Block 4: 6100 to 6128

This moves stuff out of the area of memory we will use for graphics (4400 - 6000) to 095D. It also copies several
constant values to many places in memory.

However, we do one important thng here, we store CINV pointer locally for use in our interrupt handler

We will use a snapshot of the app with a breakpoint at address $6129 (after 4400 stuff is moved), however we will begin disassembly at $6100 and will just skip any moves that occur with the prep method starting at $4700.

NOTE that since we are no longer implenting block 3, we will need to implement our own code to clear variable space and import the character sets in to graphical memory.
