.filenamespace game

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for playiong the game.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Game
entry:
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace data {
    // BEC0
    row_occupancy_lo_ptr: // Low byte memory offset of square occupancy data for each board row
        .fill BOARD_NUM_COLS, <(curr_square_occupancy + i * BOARD_NUM_COLS)

    // BEC9
    row_occupancy_hi_ptr: // High byte memory offset of square occupancy data for each board row
        .fill BOARD_NUM_COLS, >(curr_square_occupancy + i * BOARD_NUM_COLS)
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
// Data in this area are not cleared on state change.
//
.segment Data

.namespace state {
    // BCC2
    flag__is_first_player_light: .byte $00 // Is positive for light, negative for dark // !!!!!!!!!! TODO MOVE TO OPTIONS.ASM

    // BCC6
    flag__is_curr_player_light: .byte $00 // Is positive for light, negative for dark
}

//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
//
.segment DynamicData

// BD11
curr_color_phase: .byte $00 // Current board color phase (colors phase between light and dark as time progresses)

// BD7C
curr_square_occupancy: .fill BOARD_NUM_ROWS*BOARD_NUM_COLS, $00 // Board square occupant data (#$80 for no occupant)

// BDFD
curr_piece_strength: .fill BOARD_INITIAL_NUM_PIECES, $00 // Current strength of each board piece
