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
//     bpl !next+
//     sta WBCC0
!next:
    // Get player and convert to 0 for light, 1 for dark.
    lda state.flag__is_curr_player_light
    and #$01
    eor #$01
    tay
    lda board.sprite.piece_color,y
    sta SP1COL // Set logo color
    sta SP2COL
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
    // Set position of piece selection sprite.
    ldx #$04 // Sprite 4
    lda #$FE // Column - FE is 2 columns left of 1st column (column 0)
    bit state.flag__is_curr_player_light
    bpl !next+
    lda #$0A // 2 columns after last column
!next:
    sta main.temp.data__curr_board_col
    ldy #$04 // row
    sty main.temp.data__curr_board_row
    jsr board.convert_coord_sprite_pos
    sec
    sbc #$02
    sta common.sprite.curr_x_pos+1
    tya
    sec
    sbc #$01
    sta common.sprite.curr_y_pos+1
    lda #%1000_1111
    sta SPENA
    // Clear sprite render variables.
    ldy #$03
    lda #$00
!loop:
    sta common.sprite.init_animation_frame,y
    sta common.sprite.number,y
    dey
    bne !loop-
    //
    ldx #$01
    jsr board.render_sprite
    jsr board.create_magic_square_sprite
    // Set interrupt handler to set intro loop state.
    sei
    lda #<main.play_game
    sta main.interrupt.system_fn_ptr
    lda #>main.play_game
    sta main.interrupt.system_fn_ptr+1
    cli
    // Check and see if the same player is occupying all of the magic squares. If so, the game is ended and that player
    // wins.
    lda #$00
    sta main.temp.data__curr_count
    ldx #$04 // Number of magic squares (0 based - so 5)
!loop:
    ldy board.data.magic_square_col,x
    lda data.row_occupancy_lo_ptr,y
    sta FREEZP
    lda data.row_occupancy_hi_ptr,y
    sta FREEZP+1
    ldy board.data.magic_square_col,x
    lda (FREEZP),y // Get ID of piece on magic square
    bmi !check_win_next+ // Square unoccupied
    // This is clever - continually OR $40 for light or $80 for dark. If all squares are occupied by the same player
    // then the result should be $40 or $80. If sqaures are occupied by multiple players, the result will be $C0
    // (ie $80 OR $40) and therefore no winner.
    ldy #$40
    cmp #$12
    bcc !next+ // Player 1 piece?
    ldy #$80
!next:
    tya
    ora  main.temp.data__curr_count
    sta  main.temp.data__curr_count
    dex
    bpl !loop-
    lda main.temp.data__curr_count
    cmp #$C0 // All pieces the same?
    beq !check_win_next+
    jmp game_over
    // Checks if any of the players have no pieces left. This is done similar to the magic square occupancy above.
    // If any pieces has strength left, a $40 (player 1) or $80 (player 2) is ORed with a total. If both players
    // have pieces, the result will be $C0. Otherwise player 1 ($40) or player 2 ($80) is the winner.
!check_win_next:
    lda #$00
    sta main.temp.data__dark_piece_count
    sta main.temp.data__light_piece_count
    sta main.temp.data__curr_count
    ldx #(BOARD_NUM_PIECES - 1)
!loop:
    lda curr_piece_strength,x
    beq !check_next+
    ldy #$40
    cpx #$12
    bcc !next+
    inc main.temp.data__dark_piece_count
    stx main.temp.data__last_dark_piece_id
    ldy #$80
    bmi !next++
!next:
    inc main.temp.data__light_piece_count
    stx main.temp.data__last_light_piece_id
!next:
    tya
    ora main.temp.data__curr_count
    sta main.temp.data__curr_count
!check_next:
    dex
    bpl !loop-
    lda main.temp.data__curr_count
    bne !next+
    jmp game_over // No pieces left on any side. Not sure how this is possible.
!next:
    cmp #$C0
    beq !check_win_next+
    jmp game_over

!check_win_next:
    // ...

    jmp * // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// 8377
interrupt_handler: // board interurpt handler?
    jsr board.draw_magic_square
    lda main.interrupt.flag__enable
    bpl !next+
    jmp common.complete_interrupt
!next:
    // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    jmp common.complete_interrupt

// 66F8
game_over:
    jsr board.clear_text_row
    // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
curr_piece_strength: .fill BOARD_NUM_PIECES, $00 // Current strength of each board piece
