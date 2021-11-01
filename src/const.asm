//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Application constants
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
#importonce

//---------------------------------------------------------------------------------------------------------------------
// Build control
//---------------------------------------------------------------------------------------------------------------------
#define INCLUDE_INTRO // comment to build the application without the introduction/title sequence

//---------------------------------------------------------------------------------------------------------------------
// Keyboard key constants
//---------------------------------------------------------------------------------------------------------------------
.const KEY_NONE = $40  // Matrix code returned from LSTX if no key pressed
.const KEY_F3 = $05 // F3 KEY
.const KEY_F5 = $06 // F5 KEY
.const KEY_F7 = $03 // F7 KEY
.const KEY_Q = $Bf // Q key

//---------------------------------------------------------------------------------------------------------------------
// Video memory configuration
//---------------------------------------------------------------------------------------------------------------------

// Define video bank memory constants
.var videoBankCode = List().add(%11, %10, %01, %00).lock()
.var videoBankAddress = List().add($0000, $4000, $8000, $C000).lock()
.var videoBankGrphMemOffset = List().add($2000, $1000, $2000, $1000).lock()

// Set the video memory bank:
// Bank 0 - configuration: %11; memory offset: $0000
// Bank 1 - configuration: %10; memory offset: $4000
// Bank 2 - configuration: %01; memory offset: $8000
// Bank 3 - configuration: %00; memory offset: $C000
.const videoBank = 2;
.const VICBANK = videoBankCode.get(videoBank)
.const VICMEM = videoBankAddress.get(videoBank)
.const VICGOFF = videoBankGrphMemOffset.get(videoBank);

// Derive applications specific video bank constants
.const CHRMEM1  = VICMEM + $0000    // start of character set memory for intro (half set only)
.const CHRMEM2  = VICMEM + $0800    // start of character set memory for board (full set)
.const SCNMEM = VICMEM + $0400    // start of screen memory (overlaps bottom half CHRMEM1 as CHRMEM1 is a half set)
.const SPTMEM = SCNMEM + $03f8    // start of sprite location memory
.const GRPMEM = VICMEM + VICGOFF // start of graphics/sprite memory

// Bytes consumed by each sprite
.const BYTES_PER_SPRITE = 64; // each sprite consumes 64 bytes of memory

// Characters per screen row
.const CHARS_PER_SCREEN_ROW = 40;

//---------------------------------------------------------------------------------------------------------------------
// Application specific constants
//---------------------------------------------------------------------------------------------------------------------
// Not needed here - is used by original source to indicate that memory range 4400-6000 has already been moved out of
// the graphics area. we don't need it as this source representation is fully relocatable and does not load any logic in
// to the graphcis area.
.const INITIALIZED = $02A7 // 00 for uninitialized, $80 for initialized

.const STATE_PTR = $0334 // Pointers used to jump to various game states (intro, board, play)

// Character piece types
.const VALKYRIE = $00        // Sprite offset: 04
.const ARCHER = $01          // Sprite offset: 02
.const GOLEM = $02           // Sprite offset: 03
.const KNIGHT = $03          // Sprite offset: 07
.const UNICORN = $04         // Sprite offset: 00
.const DJINNI = $06          // Sprite offset: 05
.const WIZARD = $08          // Sprite offset: 01
.const PHOENIX = $0A         // Sprite offset: 06
.const MANTICORE = $12       // Sprite offset: 0A
.const BANSHEE = $13         // Sprite offset: 0E
.const GOBLIN = $14          // Sprite offset: 0F
.const TROLL = $15           // Sprite offset: 0B
.const BASILISK = $17        // Sprite offset: 08
.const SHAPESHIFTER = $19    // Sprite offset: 0C
.const SORCERESS = $1B       // Sprite offset: 09
.const DRAGON = $1D          // Sprite offset: 0D
.const AIR_ELEMENTAL = $24   // Sprite offset: 10
.const FIRE_ELEMENTAL = $25  // Sprite offset: 11
.const EARTH_ELEMENTAL = $26 // Sprite offset: 12
.const WATER_ELEMENTAL = $27 // Sprite offset: 13

// Sound
.const SOUND_CMD_STOP_NOTE = $00    // Stop note
.const SOUND_CMD_SET_DELAY = $FB    // Set delay
.const SOUND_CMD_RELEASE_NOTE = $FC // Immediate release
.const SOUND_CMD_NEXT_STATE = $FD   // End state - used to trigger code at points in the music
.const SOUND_CMD_NEXT_PHRASE = $FE  // Go to next phrase (or repeat current phrase)
.const SOUND_CMD_END = $FF          // End phrase and turn off voice
