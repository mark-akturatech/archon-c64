#import "io.asm"
#import "const.asm"

.filenamespace game

.segment Game
entry:
    rts
//     jsr import_charset
//     rts


// // import the board charset in to the upper character memory
// import_charset:
//     lda #<charset
//     sta FREEZP
//     lda #>charset
//     sta FREEZP+1
//     lda #<CHRMEM2
//     sta FREEZP+2
//     lda #>CHRMEM2
//     sta FREEZP+3
//     ldx #$08
//     jmp block_copy

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// char set used by board/game pages
// charset: .import binary "/assets/charset-game.bin"
