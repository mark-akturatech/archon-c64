# Archon

## Purpose

This project the result of reverse engineering the iconic Commodore 64 game **Archon (c) 1983** by Free Fall Associates.

The reproduction code is intended to be a true replication of the source logic with the exception of original memory locations.

The code is fully relocatable and pays no heed to original memory locations. Original memory locations are provided as comments above each variable, constant or routine for reference.

Extensive comments have been provided to help understand the source code.

## Why?

Archon formed a large part of my childhood. I spent many hours playing Archon with my friends and the AI was way ahead of it's time.

I was recently thinking about source code from games like Archon being lost forever and decided to do something about it.

It's likely no-one will ever see this code, but at least I can show my respect by faithfully replicating the source and making every effort to understand and document every byte.

Also, this is my first reverse engineering project and I wanted to spend time to develop standards and styles that can be carried over to other projects. I've refactored this code more than I can count, but I think the result was worth it.

## Additional Documentation

Additional documentation is provided in the following files:

- [TERMINOLOGY.md](TERMINOLOGY.md) for a list of terms used within labels and source code comments.
- [INTERESTING.md](INTERESTING.md) for interesting insights and functionality derived from the source code.
- [Mapping the C64](http://unusedino.de/ec64/technical/project64/mapping_c64.html) for extensive documentation on various C64 memory addresses and kernal functionality.

## Development Environment

Source code was replicated within Visual Studio Code using the `KickAss (C64)` extension.

## Conventions

### Labels

#### Variable Labels

Variable labels will be prefixed with the following:
- `data__` : Calculated or derived results or data stored for use later.
- `flag__` : Used to specifically for conditional logic.
- `ptr__` : Pointer to a memory address location.
- `idx__` : Index to an item within a block of memory (or array).
- `cnt__` : A value that is incremented within a loop. Typically from 0. Is different to idx__ as an index is used to reference memory where a counter is used to perform operations a specific number of times.
- `temp__` : Value stored specifically so that it can be retrieved later after some interim operations. Temp data will not be used outside of the routine that stored it.
- `txt__`: Pointer to the start memory location of a string of text.
- `snd__`: Pointer to the start memory location containing a sound pattern (string of notes and sound commands).
- `param__`: The memory address is a parameter used to configure a subroutine.

Labels may also contain the following:
- `_list` : The label is followed by two or more related items. For example, a list of colors or positions.
- `_fn` : may be used with the ptr__ prefix to denote a pointer to a routine (function)/code.
- `_ctl` : may be used with a flag__ prefix to denote that the flag could contain multiple values and will be used to control how the code will run (eg flag may contain an enum constant to increment a row, or a column or both).
- `_curr` : typically used with a data__ prefix to denote a variable that holds the current value of a calculation, loop or repeated logic (eg current color when rendering a string)

#### Code Labels

Labels used to identify code addresses will be named to appropriately describe the functionality of the proceeding code.

Multi-labels will be used specifically for the following:
- !skip : logic is being skipped as part of a condition check
- !loop : looping logic
- !next : breaking out of a loop
- !return : exiting from a subroutine
Double or more jumps (eg jmp !loop++) will not be used.

For readability, code labels within a subroutine that are not intended to be called externally to the subroutine will be treated as multi-labels (use multilabel identifier).

#### Constants

Constant labels will use all caps.

IO and kernel address constants are named using labels defined in `Mapping the Commodore 64` book by Sheldon Leemon.

### Files

Each file will implement a separate namespace.

Code and labels that are not used outside of the file will be wrapped in a private namespace within the file.

### Multiple Use Memory

The source uses some temporary memory addresses for multiple different purposes. For example `$BF24` may store the current color phase, a sprite animation frame or a sprite x position offset.

To simplify code readability, we do not reuse temporary memory addresses for more than one purpose.

### Magic Numbers

Where relevant, all magic numbers will be replaced with a descriptive constant.

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
- Kick Assembler is just amazing. It is feature packed and bullet proof. I don't normally personally comment on tools in the README file but I just needed to say somewhere that I am really impressed with Kick Assembler.
- Jc64Dis is also impressive. It has some bugs and memory leaks and sometimes corrupts the project (got to save often), but it is also feature packed and perfect for disassembling C64 code. It isn't as popular as Infiltrator or Ghidra etc, but I highly recommend it.
- I use VSCode for many projects (including my daytime job). It is an awesome IDE and I recommend it to anyone independent of the language used.

## Entry Point

Archon initially launches via a basic program with a sys command. Running the program executes code that moves block of memory around. For readability, we will not implement this functionality and will instead start the reverse engineering effort when everything is residing in the final memory location.

We will use a snapshot with a breakpoint at address $6129 (after resources are relocated out of graphic memory) and we will begin disassembly at $6100.

Below is a brief synopsis of what is going on here:

### Block 1: 0801 to 0827

Basic program:
1986 SYS2088

### Block 2: 082B to 0858

Moves the entire code from the current loaded location to 0x68f7 to 0xffff. The move routine uses the zero page registers 0x00ae/af which hold the end address of the last loaded file byte and copies backwards from there. Therefore the app will not work if the file is not the exact correct size.

The code then copies 0x085f-0x095e to 0x0100-0x01ff and then executes 0x0100.

### Block 3: 0100 to 01ff

Some interesting logic lives here. All it does is move stuff around and performs copy logic. It takes the source code in 0x6a00 to 0xffff and moves it around to various memory locations.

It then executes 6100.

### Block 4: 6100 to 6128

This is the main game loop.

The logic first however moves resources out of the graphics memory area (4400-4800 and 5000-6000) as this area will be cleared and used for screen and sprite graphics.
