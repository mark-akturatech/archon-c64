#import "io.asm"
#import "const.asm"

.segment Game
game:
    jsr import_board_charset
    rts


// import the board charset in to the upper character memory
import_board_charset:
    lda #<board_charset
    sta FREEZP
    lda #>board_charset
    sta FREEZP+1
    lda #<CHRMEM2
    sta FREEZP+2
    lda #>CHRMEM2
    sta FREEZP+3
    ldx #$04
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

//---------------------------------------------------------------------------------------------------------------------
// Binaries
//---------------------------------------------------------------------------------------------------------------------
.segment Binaries

// char set used by board/game pages
board_charset: .import binary "assets/board-charset.bin"
