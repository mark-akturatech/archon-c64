#import "io.asm"
#import "const.asm"

//---------------------------------------------------------------------------------------------------------------------
// Display introduction (title) page
//---------------------------------------------------------------------------------------------------------------------
.segment Intro
intro:
    jsr import_title_charset
    jsr clear_screen
    jsr clear_sprites
    jsr load_title_sprites
    rts

// import the title charset in to the lower character memory
import_title_charset:
    lda #<title_charset
    sta FREEZP
    lda #>title_charset
    sta FREEZP+1
    lda #<CHRMEM1
    sta FREEZP+2
    lda #>CHRMEM1
    sta FREEZP+3
    ldx #$02
    jmp block_copy    

// ok so the original code seems to be decrypted or something. is way too complex for my little brain. so here we
// include a simplified version of the sprite loader.
load_title_sprites:
    lda #<sprite_locations
    sta FREEZP
    lda #>sprite_locations
    sta FREEZP+1
    lda #<title_sprites
    sta FREEZP+2
    lda #>title_sprites
    sta FREEZP+3
    jmp move_sprites

//---------------------------------------------------------------------------------------------------------------------
// Local Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// Represents the sprite locations within grapphics memory that each sprite will occupy. See comment on
// `title_sprites` for a list of which sprite occupies which slot. The first word represents the first sprite, second
// word the second sprite and so on. The sprite location is calculated by adding the offset to the GRPMEM location.
// The location list is ffff terminated.
sprite_locations:
    .word $0000, $0040, $0080, $00C0, $0100, $0140, $0180, $0600
    .word $0640, $0680, $06C0, $0700, $0740, $0780, $07C0, $0800
    .word $0840, $0880, $08C0, $0900, $0940, $0980, $09C0, $ffff


//---------------------------------------------------------------------------------------------------------------------
// Binaries
//---------------------------------------------------------------------------------------------------------------------
.segment Binaries

// char set used by title page
title_charset: .import binary "assets/title-charset.bin"

// sprites used by title page
// sprites are contained in the following order:
// - 0-3: archon logo
// - 4-6: free fall logo
// - 7-10: left facing knight animation frames
// - 11-14: left facing troll animation frames
// - 15-18: right facing golum animation frames
// - 19-22: right facing goblin animation frames
title_sprites: .import binary "assets/title-sprites.bin"


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
