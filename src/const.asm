//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Application constants
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
#importonce

// comment to build the application without the introduction/title sequence
#define INCLUDE_INTRO

//---------------------------------------------------------------------------------------------------------------------
// Keyboard key constants
//---------------------------------------------------------------------------------------------------------------------

.const KEY_NONE = $40  // Matrix code returned from LSTX if no key pressed
.const KEY_Q    = $Bf  // Q key 

//---------------------------------------------------------------------------------------------------------------------
// Video memory configuration
//---------------------------------------------------------------------------------------------------------------------

// Define video bank memory constants
.var videoBankCode = List().add(%11, %10, %01, %00).lock()
.var videoBankAddress = List().add($0000, $4000, $8000, $C000).lock()

// Set the video memory bank:
// Bank 0 - configuration: %11; memory offset: $0000
// Bank 1 - configuration: %10; memory offset: $4000
// Bank 2 - configuration: %01; memory offset: $8000
// Bank 3 - configuration: %00; memory offset: $C000
.const videoBank = 2;
.const VICBANK = videoBankCode.get(videoBank)
.const VICMEM = videoBankAddress.get(videoBank)

// Derive applications specific video bank constants
.const CHRMEM1  = VICMEM + $0000    // start of character set memory for intro (half set only)
.const CHRMEM2  = VICMEM + $0800    // start of character set memory for board (full set)
.const SCNMEM   = VICMEM + $0400    // start of screen memory (overlaps bottom half CHRMEM1 as CHRMEM1 is a half set)
.const SPTMEM   = SCNMEM + $07f8    // start of sprite location memory
.const GRPMEM   = VICMEM + $1000    // start of graphics/sprite memory
