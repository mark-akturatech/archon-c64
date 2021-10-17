.filenamespace unofficial

//---------------------------------------------------------------------------------------------------------------------
// Contains routines that are not part of the original source code but have been developed to replace original
// routines that were not easily movable, contained self modifying code or dealt with decrypting/deobfuscating
// original memory that has been replaced with unofuscated/decrypted resources.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

.segment Common

// LOAD CHARACTER MAPS
// Source 6152 to 623e copies the character maps in to graphics area. I can't be sure here, but the code seems to
// deofuscate (or decrypt) the character maps as they don't appear to be directly represented anywhere in memory.
// So instead, i created a added a breakpoint after the copy was completed and saved direct bin copies of the
// character maps (so that they can be loaded in to character map tools such as vchar64). Therefore, i now need to
// implement my own code to load the character maps.
//
// Archon loads 2 character maps:
//  4000 - 43ff: Half character map for title page characters
//  4800 - 4fff: Game character set including game characters
//
// The following compiler definitions (defined in const.asm) affect this method:
// - INCLUDE_INTRO: If not defined, the build will NOT include the introduction/title pages. In this case, we
//   do not load (or include) the title page character map.
// - INCLUDE_GAME: If not defined, the build will NOT include the game pages. In this case, we do not load (or include)
//   the board page character map.
//
// The character set will be loaded in to the correct locations within the selected `videoBank`.
import_charsets:
#if INCLUDE_INTRO
    lda #<main.charset.intro
    sta FREEZP
    lda #>main.charset.intro
    sta FREEZP+1
    lda #<CHRMEM1
    sta FREEZP+2
    lda #>CHRMEM1
    sta FREEZP+3
    ldx #$04
    jsr block_copy
#endif
#if INCLUDE_GAME
    lda #<main.charset.game
    sta FREEZP
    lda #>main.charset.game
    sta FREEZP+1
    lda #<CHRMEM2
    sta FREEZP+2
    lda #>CHRMEM2
    sta FREEZP+3
    ldx #$08
    jsr block_copy
#endif
    rts

// BLOCK COPY 
// Copy a block of code from one memory location to another. A block consists of one or more contiguous blocks of
// 255 bytes. 
// Prerequisites:
// - Put source location in FREEZP (lo, hi)
// - Put destination location in FREEZP+2 (lo, hi)
// - Load X register with number of blocks to copy + 1
block_copy:
    ldy #$00
!loop:
    lda (FREEZP), y
    sta (FREEZP+2), y
    iny
    bne !loop-
    inc FREEZP+1
    inc FREEZP+3
    dex 
    bne !loop-
    rts

// MOVE SPRITES
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
