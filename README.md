# Archon
Reverse engineer of C64 Archon (c) 1983 by Free Fall Associates.

The code is not a byte for byte replciation. Instead, we remove all encryption, obfuscation and memory copying so
that the code is readable and understandable.

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

## Internal Notes
See this [Google doc](https://docs.google.com/document/d/1egaTTunRm6hVrAze3NAH2yh1l5LNVVXULeHMXNHla-w).

## Notes

Archon initially launches via a basic program with a sys command. The initial code just decrypts the code and
moves stuff around. We will therefore not reverse engineer this part of the application.

Below is a breif synopsis of what is going on here:

### Block1: 0801 to 0827
Basic program: 
1986 SYS2088

### Block2: 082B to 0858
Moves the entire code from the current loaded location to 0x68f7 to 0xffff. The move routine uses the zero page
registers 0x00ae/af which hold the end address of the last loaded file byte and copies backwards from there.
Therefore the app will not work if the file is not the exact correct size.

The block then copies in to 0x00ab: 4c 00 01 01 80 0c 6a

And finally copies 0x085f-0x095e to 0x0100-0x01ff and then executes 0x0100.

### Block3: 0100 to 01ff
Some crazy logic lives here. All it does is move stuff around and performs copy logic. Pretty sure it performs some
sort of decryption. It takes the source code in 0x6a00 to 0xffff and moves stuff around to various memory locations.
It then executes 6100.

### Block3: 6100 to 6128
This moves stuff out of the area of memory we will use for graphics (4400 - 6000) to 095D. It also copies several
constant values to many places in memory.

However, we do one important thng here, we store CINV pointer locally for use in our interrupt handler

We will start our app at address $6129 (but we will include the CINV copy code).
