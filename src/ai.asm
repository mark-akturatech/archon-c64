.filenamespace ai
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used for AI in board and challenge game play.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 6D3C
board_calculate_move: // TODO
    rts

// 7A1D
magic_select_spell: // TODO
    rts

// 82E5
// This logic is inline in the original source. We split it out here so that the logic can be included in the AI
// file.
select_piece:
    rts

// 8560
board_cursor_to_icon: // TODO
    jmp common.complete_interrupt
