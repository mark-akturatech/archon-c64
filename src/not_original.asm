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

#if INCLUDE_INTRO
// Imports intro page sprites in the graphics sprite area.
import_intro_sprites:
    lda #<sprite.intro_offset
    sta FREEZP
    lda #>sprite.intro_offset
    sta FREEZP+1
    lda #<sprite.intro_source
    sta FREEZP+2
    lda #>sprite.intro_source
    sta FREEZP+3
    jmp move_sprites
#endif

// Moves sprites from a given memory location to a sprite locations specified in a sprite matrix.
// Prerequisites:
// - Set word FREEZP to the source location of the sprite matrix.
// - Set word FREEZP+2 to the source location of the sprite data.
// The sprite matrix contains an offset for each sprite index. The sprite is moved to GRPMEM plus the offset. The offset
// is indexed in the same order that the sprites appear (in blocks of 64 bytes) within the source. Special commands
// can be used within the matrix as follows:
// - FFFF: The matrix must be terminated with FFFF after the last sprite copy.
// - FFFE: Do not copy the current sprite. Handy if you want to copy some of the source sprites but not all.
.enum { COMMAND=$ff, COMMAND_EXIT=$ff, COMMAND_SKIP=$fe }
move_sprites:
    ldy #$00
!loop:
    lda (FREEZP),y
    tax
    clc
    adc #<GRPMEM
    sta VARTAB
    iny
    bne !next+
    inc FREEZP+1
!next:
    lda (FREEZP),y
    cmp #COMMAND
    bne !next++
    cpx #COMMAND_EXIT
    bne !next+
    rts
!next:
    cpx #COMMAND_SKIP
    bne !next+
    iny
    bne skip_copy
    inc FREEZP+1
    jmp skip_copy
!next:
    clc
    adc #>GRPMEM
    sta VARTAB+1
    iny
    bne !next+
    inc FREEZP+1
!next:
    tya
    tax
    ldy #$00
!loop:
    lda (FREEZP+2),y
    sta (VARTAB),y
    iny
    cpy #BYTES_PER_SPRITE
    bne !loop-
    txa
    tay
skip_copy:
    lda FREEZP+2
    clc
    adc #$40
    sta FREEZP+2
    bcc !loop--
    inc FREEZP+3
    jmp !loop--
!return:
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

#if INCLUDE_INTRO
.namespace sprite {
    // sprites used by title page
    // sprites are contained in the following order:
    // - 0-3: Archon logo
    // - 4-6: Freefall logo
    // - 7-10: left facing knight animation frames
    // - 11-14: left facing troll animation frames
    // - 15-18: right facing golum animation frames
    // - 19-22: right facing goblin animation frames
    intro_source: .import binary "/assets/sprites-intro.bin"

    // Represents the sprite locations within grapphics memory that each sprite will occupy. See comment on
    // `title_sprites` for a list of which sprite occupies which slot. The first word represents the first sprite,
    // second word the second sprite and so on. The sprite location is calculated by adding the offset to the GRPMEM
    // location. The location list is ffff terminated. Use fffe to skip a sprite without copying it.
    intro_offset:
        .word $0000, $0040, $0080, $00C0, $0100, $0140, $0180, $0600
        .word $0640, $0680, $06C0, $0700, $0740, $0780, $07C0, $0800
        .word $0840, $0880, $08C0, $0900, $0940, $0980, $09C0, $ffff
}
#endif

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
