# Archon

## Purpose

This project is reverse engineer of the iconic Commodore 64 game **Archon (c) 1983** by Free Fall Associates.

The reporduced code is intended to be a true replication of the source logic with the exception of original memory locations.

The code is fully relocatable and pays no heed to original memory locations. Original memory locations are provided as comments above each variable, constant or method for reference.

The source uses some temporary memory addresses for multiple different purposes. For example `$BF24` may store the current color phase, a sprite animation frame or a sprite x position offset. To simplify code readability, we do not reuse temporary memory addresses.

Extensive comments have been provided to help understand the source code.

## Additional Documentation

Additional documentation is provided in the following files:

- [TERMINOLOGY.md](TERMINOLOGY.md) for a list of terms used within labels and source code comments.
- [INTERESTING.md](INTERESTING.md) for interesting insights and funcitonality derived from the source code.
- [Mapping the C64](http://unusedino.de/ec64/technical/project64/mapping_c64.html) for extensive documentation on various C64 memory addresses and kernal fucntionality.

## Development Environment

Source code was replicated entirely within Visual Studio Code using the `KickAss (C64)` extension.

## Conventions

### Variable Labels 

Variable lables will be prefixed with the following:
- data__ : Calculated or derived results or data stored for use later.
- flag__ : Used to specifically for conditional logic.
- ptr__ : Pointer to a memory address location.
- index__ : Index to an item within a block of memory (or array).
- pos__ : Data used specifically for positioning a sprite or screen data.
- counter__ : A value that is incremented within a loop. Typically from 0. Is different to index__ as an index is used to reference memory where a counter is used to perform operations a specific number of times.
- temp__ : Value stored specifically so that it can be retrieved later after some interim operations. Temp data will not be use doutside of the routine that stored it.

### Code Labels

Lables used to identify code addresses will be named to appropriately describe the functionality of the proceeding code.

Multilables will be used specifically for the following:
- !skip : only when logic is being skipped as part of a condition check
- !loop : loops
- !next : breaking out of a loop
- !return : exiting from a subroutine

## Build

Build using Kick Assembler V5.24.

## Tools

Extensive use of the following tools were used to help with this project:

- [Jc64dis](https://iceteam.itch.io/jc64dis) was used for disassembling and reverse engineering.
- [Infiltrator](https://csdb.dk/release/?id=100129) was primarily used for memory inspection of VICE snapshots.
- [VChar64](https://github.com/ricardoquesada/vchar64) was used for loading and previewing character sets from VICE snapshots.
- [Sprite Pad](https://csdb.dk/release/?id=132081) was used for previewing sprite sets, however Archon stores sprites using 54 bytes (not 64 as per normal) and therefore Sprite Pad wasn't that useful.
- [Visual Studio Code](https://code.visualstudio.com/) was used as the IDE.
- [Kick Assembler](http://theweb.dk/KickAssembler/Main.html#frontpage) and [KickAss (C64)](https://marketplace.visualstudio.com/items?itemName=CaptainJiNX.kickass-c64&ssr=false#review-details)
  vscode extension was used to compile the reproduced source code.

Some notes regarding the above tools:
- Kick Assembler is just amazing. It is feature packed and bullet proof. I don't normally personally comment on tools in the README file but I just needed to say somehwere that I am really impressed with Kick Assembler.
- Jc64Dis is also impressive. It has some bugs and memory leaks and sometimes corrupts the project (gotta save often), but it is also feature packed and perfect for disassembling C64 code. It isn't as populat as Infiltrator or Ghidra etc, but I highly recommend it. 
- I use VSCode for many projects (including my daytime job). It is an awesome IDE and I truely recommend it to anyone independant of the language used.

## Reverse Engineering Entry Point

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
0x6a00 to 0xffff and moves it around to various memory locations. This block also copies data in to the character
data area on our graphic block.

It then executes 6100.

### Block 4: 6100 to 6128

This moves sprite resources out of the area of memory we will use for graphics (4400 - 6000) to 095D. It also copies
several constant values to many places in memory.

However, we do one important thing here, we store CINV pointer locally for use in our interrupt handler

We will use a snapshot of the app with a breakpoint at address $6129 (after 4400 block is moved), however we will begin disassembly at $6100 and will just skip any moves that occur with the prep method starting at $4700.
