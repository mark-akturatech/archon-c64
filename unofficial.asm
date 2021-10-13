//---------------------------------------------------------------------------------------------------------------------
// Contains routines that are not part of the original source code but have been developed to replace original
// routines that were not easily movable, contained self modifying code or dealt with decrypting/deobfuscating
// original memory that has been replaced with unofuscated/decrypted resources.
//---------------------------------------------------------------------------------------------------------------------

.segment Main

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
// Moves sprites from a given memory location to a sprite locations specified in a sprite matrix
// Prerequisites:
// - Set word FREEZP to the source location of the sprite matrix. The matrix is ffff terminated.
// - Set word FREEZP+2 to the source location of the sprite data.
// The sprite matrix contains an offset for each sprite index. The sprite is moved to GRPMEM plus the offset. The offset
// is indexed in the same order that the sprites appear (in blocks of 64 bytes) within the source.
move_sprites:
    lda FREEZP+2
    sta sprite_source+1
    lda FREEZP+3
    sta sprite_source+2
    ldy #$00
!loop:
    // read fromt he matrix and add the offset to the sprite memory location and store as the destination
    lda (FREEZP),y
    tax
    clc
    adc #<GRPMEM
    sta FREEZP+2
    iny
    bne !next+
    inc FREEZP+1
!next:
    lda (FREEZP),y
    // exit if matrix end is reached
    cmp #$ff
    bne !next+
    cpx #$ff
    beq !return+
!next:
    clc
    adc #>GRPMEM
    sta FREEZP+3
    iny
    bne !next+
    inc FREEZP+1
!next:
    tya
    tax
    // copy 64 bytes of sprite data to the destination
    ldy #$00
sprite_source:
    // the next line is self modified to point to the current sprite source location
    lda $ffff 
    sta (FREEZP+2),y
    inc sprite_source+1
    bne !next+
    inc sprite_source+2
!next:
    iny
    cpy #$40 // sprites consist of 64 bytes
    bne sprite_source
    txa
    tay
    jmp !loop-
!return:
    rts
