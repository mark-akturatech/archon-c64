.filenamespace game

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for playiong the game.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Game

// 8019
entry:
    jsr common.clear_sprites
    jsr board.clear_text_area
    jsr common.stop_sound
    lda #FLAG_DISABLE
    sta board.flag__render_square_control
    jsr board.draw_board
    lda state.flag__is_curr_player_light
    eor #$FF                         
    sta state.flag__is_curr_player_light
//     ldy WBCCB  // TODO!!!!!!!!!!!!!
//     bpl W803A
//     sta WBCC0
// W803A:
    // Get player and convert to 0 for light, 1 for dark.
    lda state.flag__is_curr_player_light
    and #$01
    eor #$01
    tay
    lda board.sprite.piece_color,y
    sta SP1COL // Set logo color
    sta SP2COL
W804B:
    sta SP3COL // Set selection square color
    jsr board.create_logo
    jsr board.set_player_color
    jsr board.draw_border
    lda SPMC
    and #%0111_0001 // Set sprites 1, 2, 3 to single color
    sta SPMC
    lda #BLACK
    sta SPMC0
    jsr board.create_selection_square
    lda #%1111_1110 // Expand sprites 1, 2 and 3 horizontally
    sta XXPAND
    lda #%0000_0000
    sta YXPAND
    //....... 8071


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
    // BCC1
    ai_player_control: .byte $00 // Is 0 for none, 1 for computer plays light, 2 for computer plays dark

    // BCC2
    flag__is_first_player_light: .byte $00 // Is positive for light, negative for dark

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
