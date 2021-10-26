.filenamespace board

//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used for rendering the game board.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

// 915B
set_player:
    rts

// 9076
draw_board:
    rts

// 916E
draw_border:
    rts

// 927A
draw_magic_squares:
    rts

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC2
flag__first_player: .byte $00 // Is positive for light, negative for dark.
    
// BCC6
flag__current_player: .byte $00 // Is positive for light, negative for dark.
