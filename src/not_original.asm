.filenamespace not_original

//---------------------------------------------------------------------------------------------------------------------
// Contains routines that are not part of the original source code but have been developed to replace original
// routines that were not easily movable, contained self modifying code or dealt with decrypting/deobfuscating
// original memory that has been replaced with unofuscated/decrypted resources.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

.segment Common

// Load the following character maps in to graphics memory:
//  4000 - 43ff: Half character map for title page characters
//  4800 - 4fff: Game character set including game characters
//
// The following compiler definitions (defined in const.asm) affect this method:
// - INCLUDE_INTRO: If not defined, the build will NOT include the introduction/title pages. In this case, we
//   do not load (or include) the title page character map.
//
// The character set will be loaded in to the correct locations within the selected `videoBank`.
import_charsets:
#if INCLUDE_INTRO
    lda #<charset.intro
    sta FREEZP
    lda #>charset.intro
    sta FREEZP+1
    lda #<CHRMEM1
    sta FREEZP+2
    lda #>CHRMEM1
    sta FREEZP+3
    ldx #$04
    jsr block_copy
#endif
    lda #<charset.game
    sta FREEZP
    lda #>charset.game
    sta FREEZP+1
    lda #<CHRMEM2
    sta FREEZP+2
    lda #>CHRMEM2
    sta FREEZP+3
    ldx #$08
    jmp block_copy

// Copy a block of code from one memory location to another. A block consists of one or more contiguous blocks of
// 255 bytes.
// Prerequisites:
// - Put source location in FREEZP (lo, hi)
// - Put destination location in FREEZP+2 (lo, hi)
// - Load X register with number of blocks to copy + 1
block_copy:
    ldy #$00
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+1
    inc FREEZP+3
    dex
    bne !loop-
    rts

// Ensures that the variable space used by the application is reset to 00 values. This is required so that we don't
// have to include the blank variables in our output file.
clear_variable_space:
    lda #<data_start
    sta FREEZP
    lda #>data_start
    sta FREEZP+1
    ldy #$00
    lda #$00
!loop:
    sta (FREEZP),y
    inc FREEZP
    bne !next+
    inc FREEZP+1
!next:
    ldx FREEZP
    cpx #<data_end
    bne !loop-
    ldx FREEZP+1
    cpx #>data_end
    bne !loop-
    rts

// empty subroutine for use when code is disabled using compiler variables
empty_sub:
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace charset {
#if INCLUDE_INTRO
    intro: .import binary "/assets/charset-intro.bin"
#endif
    game: .import binary "/assets/charset-game.bin"
}

//---------------------------------------------------------------------------------------------------------------------
// Define data address boundaries.
// Main.asm defines segments `DataStart` and `DataEnd` to bookend the data segment. We can use labels in the bookends
// to read the start and end of the data segment memory reason. We need to do this as data is not stored in the source
// file and we therefore need to "zero out' the data area before we can use it.
//---------------------------------------------------------------------------------------------------------------------
.segment DataStart
    data_start:

.segment DataEnd
    data_end:
