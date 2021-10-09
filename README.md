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

