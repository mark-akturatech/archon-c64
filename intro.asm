#import "io.asm"
#import "const.asm"

.segment Intro
intro:
    rts






/*
// source start: A835
configure:
    // configure screen
    lda SCROLX
    and #%1110_1111     // multicolor bitmap mode off
    sta SCROLX
    lda #%0001_0000     // $0000-$07FF char memory, $2000-$23FF screen memory
    sta VMCSB
    // configure sprites
    lda #%0000_1111     // first 4 sprites multicolor; last 4 sprints single color
    sta SPMC
    lda #%1111_0000     // first 4 sprites double width; last 4 sprites single width
    sta XXPAND
    lda #%1111_1111     // enable all sprites
    sta SPENA
    //
// sei                        
// lda  #$42
// sta  $BCCC
// lda  #$AA
// WA859:
// sta  $BCCD
// cli
// lda  #$00                  
// sta  $BCC7
// sta  $D020
// sta  $D021
// A868  AD 88 A9   LDA  $A988                 BASIC ROM
// A86B  8D 25 D0   STA  WD025                 Multicolor animation 0 register
// A86E  8D 26 D0   STA  WD026                 Multicolor animation 1 register
// A871  A9 56      LDA  #$56                  
// A873  8D 30 BD   STA  WBD30                 BASIC ROM
// A876  A9 AA      LDA  #$AA                  
// A878  8D 31 BD   STA  WBD31                 BASIC ROM    
    rts


intro:
    rts



*/
