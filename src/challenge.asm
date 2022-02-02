.filenamespace challenge

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for challenge battles.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Game

// 7ACE
entry:
    // Redraw board without any icons.
    jsr board.clear_text_area
    lda #$80
    sta board.flag__render_square_ctl
    jsr board.draw_board
    ldx #$40 // ~ 1 second
    jsr common.wait_for_jiffy
    rts // TODO remove


// 938D
interrupt_handler:
    jmp common.complete_interrupt // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
.segment DynamicDataStart

// BD23
curr_square_color: .byte $00 // Color of square where challenge was initiated. Used for determining icon strength.
