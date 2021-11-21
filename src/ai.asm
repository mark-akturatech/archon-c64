.filenamespace ai

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for board and fight gameplay AI.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Game

// 6D3C
board_calculate_move:
    rts

// 8560
board_cursor_to_icon:
    // TODO
    jmp common.complete_interrupt
