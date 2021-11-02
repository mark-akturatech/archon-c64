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
// Define data address boundaries.
// Main.asm defines segments `DataStart` and `DataEnd` to bookend the data segment. We can use labels in the bookends
// to read the start and end of the data segment memory reason. We need to do this as data is not stored in the source
// file and we therefore need to "zero out' the data area before we can use it.
//---------------------------------------------------------------------------------------------------------------------
.segment DataStart
    data_start:

.segment DataEnd
    data_end:
