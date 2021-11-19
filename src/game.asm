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
    // Swap player because the main game as alternates the player, so it will swaps it back to the correct player.
    lda state.flag__is_curr_player_light
    eor #$FF
    sta state.flag__is_curr_player_light
    ldy board.countdown_timer
    bpl !next+
    sta state.flag__ai_player_ctl // AI set to both players on options timeout (demo mode)
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
    ora main.temp.data__curr_count
    sta main.temp.data__curr_count
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
    stx main.temp.data__remaining_dark_piece_id
    ldy #$80
    bmi !next++
!next:
    inc main.temp.data__light_piece_count
    stx main.temp.data__remaining_light_piece_id
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
    lda flag__round_complete
    eor #$FF
    sta flag__round_complete
    bmi round_complete
    jmp !check_win_next+
round_complete:
    // Counter is loaded with $FC when both sides first have 3 players or less left. The counter is decremented
    // after each side has moved. The coutner is reset though when a fight occurs. If the counter reaches ($F0)
    // then the game is a stalemate. It is loaded with $FC instead of $12 so we can differentiate beteew a 0 (ie
    // not set) and $F0 (ie stalemate).
    lda curr_stalemate_count
    beq change_phase_color
    and #$0F
    bne !next+
    lda #$01 // Stalemate
    sta main.temp.data__curr_count
    jmp game_over
!next:
    dec curr_stalemate_count
change_phase_color:
    ldy #$03 // Board phase state
    jsr cycle_phase_counters
    jsr board.draw_board
    lda main.state.curr_cycle+3 // Board color
    bne check_light_pieces
    // Board is black
    lda #$FF
    sta imprisoned_piece_id+1 // Remove imprisoned dark piece
    ldx #$23 // Dark player piece offset
    jsr regenerate_hitpoints
    jmp !next+
check_light_pieces:
    cmp #$0E
    bne !next+
    // Board is white
    lda #$FF
    sta imprisoned_piece_id // Remove imprisoned light piece
    ldx #$11 // Light player piece offset
    jsr regenerate_hitpoints
!next:
    // Increase strength of all pieces on magic squares.
    ldx #$04 // 5 magic sqaures (0 offset)
!loop:
    ldy board.data.magic_square_col,x
    lda data.row_occupancy_lo_ptr,y
    sta FREEZP
    lda data.row_occupancy_hi_ptr,y
    sta FREEZP+1
    ldy board.data.magic_square_col,x
    txa
    pha
    lda (FREEZP),y
    bmi !next+ // Unoccupied
    tax
    lda curr_piece_strength,x
    ldy board.piece.init_matrix,x
    cmp board.piece.init_strength,y
    bcs !next+
    inc curr_piece_strength,x
!next:
    pla
    tax
    dex
    bpl !loop-
!check_win_next:
    // End the game if player has only one piece and that piece is imprisoned.
    lda game.state.flag__is_curr_player_light
    bpl !next+
    // Check if dark piece is imprisoned.
    ldy main.temp.data__dark_piece_count
    cpy #$02
    bcs check_game_state
    ldy main.temp.data__remaining_dark_piece_id
    cpy imprisoned_piece_id+1
    bne check_game_state
    jmp game_over__imprisoned
!next:
    // Check if light piece is imprisoned.
    ldy main.temp.data__light_piece_count
    cpy #$02
    bcs check_game_state
    ldy main.temp.data__remaining_light_piece_id
    cpy imprisoned_piece_id
    bne check_game_state
    jmp game_over__imprisoned
    //
check_game_state:
    lda main.curr_pre_game_progress
    beq play_turn // In game?
    // Play game with 0 players if option timer expires.
    lda TIME+1
    cmp main.state.last_stored_time
    beq !next+
    sta main.state.last_stored_time
    dec board.countdown_timer
    bpl !next+
    // Start game.
    lda #$00
    sta main.curr_pre_game_progress
    jmp main.restart_game_loop
!next:
    jsr board.display_options
    jmp check_game_state
    //
play_turn:
    // 81F2  A9 01      lda  #$01 // TODO 
    // 81F4  8D 26 BD   sta  temp_data__sprite_count // idk yet
    lda #$00
    // 81F9  8D 09 BD   sta  WBD09 ??? // NFI! - seems to never get set
    sta game.state.flag__is_player_turn_started
    // 81FF  8D FF BC   sta  WBCFF ??? // TODO  NFI
    // 8202  8D FD BC   sta  WBCFD ??? // seems to flag set to redraw board? maybe after fight??
    // 8205  8D 0E BD   sta  WBD0E ??? // seems to get set if select spell is enabled???
    // 8208  8D 0F BD   sta  WBD0F ??? // maybe set if spell requires a peice select???
    ldx #$05 // Short delay before start of turn
    // Check AI turn.
    lda game.state.flag__ai_player_ctl
    cmp game.state.flag__is_curr_player_light
    bne !next+
    jsr ai.board_calculate_move
    ldx #$60 // Normal AI start delay
    lda board.countdown_timer // Will be FF is option timer expired
    bmi !next+
    ldx  #$40 // Short AI start delay if AI vs AI
!next:
    stx delay_before_turn
    jsr wait_for_state_change

    // 8227... TODO
    // ...
    jmp play_turn // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// 64EB
// Regenerate hitpoints for all pieces of the current player.
// - X register is $23 (dark) or $11 (light)
// Loops through all players pieces (backwards) and increases all piece's hitpoints up to the initial hitpoints.
// This operation is performed when the board color is strongest for the player (ie white for light and black for
// dark).
regenerate_hitpoints:
    txa
    sec
    sbc #$12
    sta main.temp.data__temp_store // First player piece (offset by 1)
!loop:
    lda curr_piece_strength,x
    beq !next+ // Piece is dead
    ldy board.piece.init_matrix,x
    cmp board.piece.init_strength,y
    bcs !next+ // Piece is fully healed
    inc curr_piece_strength,x
!next:
    dex
    cpx main.temp.data__temp_store
    bne !loop-
    rts

// 6578
// Cycles counters at the end of each turn. The counters are used to set game phases such as the board color.
// - Y register is set with the counter offset as follows:
//   - 0: TBA
//   - 1: TBA
//   - 2: TBA
//   - 3: Board color phase
// The logic below cycles forwards or backwards between a fixed set of numbers. The direction is dependent on the
// counter state. If positive, it cycles forwards, negative backwards.
// The cycle is a bid odd, but it makes sense when the resulting number is shifted right.
// Backward cycle:
//   8 => 6 0110 lsr => 011 (3)
//   6 => 2 0010        001 (1)
//   2 => 0 0000        000 (0)
//   0 => E 1110        111 (7)
//   E => C 1100        110 (6)
//   C => 8 1000        100 (4)
// For Y=3, the right shifted cycle is used as an index in to the board color array. This results (using backwards)
// example in colors:
// - PURPLE, BLUE, BLACK, WHITE, CYAN, GREEN (repeat)
// Note that the colors don't actually do this. The direction is swapped when we reach black or white.
cycle_phase_counters:
    lda main.state.counter,y
    bmi cycle_phase_counters__reverse
    lda main.state.curr_cycle,y
    cmp #$0E
    bne increase_cycle_count
    lda #$00 // Reset cycle
    beq !next+
increase_cycle_count:
    clc
    adc #$02
    cpy #$03
    bcc !next+
    cmp #$04
    beq increase_cycle_count_again
    cmp #$0A
    bne !next+
increase_cycle_count_again:
    // Skip 04 and 0A cycle. I suspect the original game had extra board colors as the logic allows red and yellow
    // colors to be used for these cycles.
    clc
    adc #$02
!next:
    sta main.state.curr_cycle,y
    cmp #$0E
    bcc set_phase_color
    lda #$FF // Reverse phase
    sta main.state.counter,y
set_phase_color:
    cpy #$03
    bcc !return+
    // Set board color.
    lda main.state.curr_cycle+3
    lsr
    tay
    lda board.data.color_phase,y
    sta curr_color_phase
!return:
    rts
cycle_phase_counters__reverse:
    lda main.state.curr_cycle,y
    bne decrease_cycle_count
    lda #$0E // Reset cycle
    bpl !next+
decrease_cycle_count:
    sec
    sbc #$02
    cpy #$03
    bcc !next+
    cmp #$04
    beq decrease_cycle_count_again
    cmp #$0A
    bne !next+
decrease_cycle_count_again:
    // Skip 04 and 0A cycle. I suspect the original game had extra board colors as the logic allows red and yellow
    // colors to be used for these cycles.
    sec
    sbc #$02
!next:
    sta main.state.curr_cycle,y
    cmp #$00
    bne set_phase_color
    sta main.state.counter,y // Reverse phase
    jmp set_phase_color

// 66E9
// Display game over message if last piece is imprisoned.
// NOTE do not relocate this without jumping to `game_over` method.
game_over__imprisoned:
    lda #STRING_ICON_IMPRISONED
    ldx #$00
    jsr board.write_text
    // Set winner (opposite to current player as current player has the imprisoned piece).
    lda state.flag__is_curr_player_light
    eor #$FF
    sta main.temp.data__curr_count
// 66F8
// Print game over message, play outro music and reset game.
// `main.temp.data__curr_count` contains the winning side:
// - $40: light player
// - $80: dark player
// - $C0: tie
// - $01: stalemate
game_over:
    jsr board.clear_text_row
    lda #STRING_GAME_ENDED
    ldx #CHARS_PER_SCREEN_ROW
    jsr board.write_text
    lda main.temp.data__curr_count
    cmp #$01 // Stalemate?
    bne !next+
    lda #STRING_STALEMATE
    jmp game_over__show_winner
!next:
    // Determine the winner. This is a little bit counter intuitive. We start with $86 (so high bit is set). The BIT
    // check then increments to $87 if the high bit is set in `data__curr_count` (ie winner is dark or tie). The value
    // is incremented again if the value > $80 (tie).
    // The result is then set as the string ID - but the string ID only goes up to $46 (70). This is OK as the write
    // method multiples the ID by 2 (ignoreing overflow), so we get offset 12 (for 86) or 14 or 16 which is string
    // 6 (light wins) and 7 (dark wins) or 8 (tie). Makes sense eventually.
    ldy #$86 // Light wins
    bit main.temp.data__curr_count
    bvs !next+
    iny // Dark wins
    lda main.temp.data__curr_count
    bmi !next+
    iny // Tie
!next:
    tya
game_over__show_winner:
    jsr board.write_text
    // Play outro music.
    lda #FLAG_ENABLE
    sta common.sound.flag__play_outro
    lda #$04
    sta main.state.counter
    sei
    lda #<board.interrupt_handler
    sta main.interrupt.system_fn_ptr
    lda #>board.interrupt_handler
    sta main.interrupt.system_fn_ptr+1
    lda #<board.interrupt_handler__play_music
    sta main.state.curr_fn_ptr
    lda #>board.interrupt_handler__play_music
    sta main.state.curr_fn_ptr+1
    cli
    jsr common.initialize_music
    // Wait for about 30 seconds before restarting the game.
    jsr common.wait_for_key
    lda TIME+1
    sta main.state.last_stored_time
    lda board.countdown_timer
    beq !loop+
    lda #$07 // Approx 30s (each tick is ~4s)
    sta board.countdown_timer
    lda #$80 // Intro
    sta main.curr_pre_game_progress
!loop:
    jsr common.check_option_keypress
    lda main.curr_pre_game_progress
    beq !next+
    lda TIME+1
    cmp main.state.last_stored_time
    beq !next+
    sta main.state.last_stored_time
    dec board.countdown_timer
    bpl !next+
    lda #$00
    sta main.curr_pre_game_progress
    jmp main.restart_game_loop
!next:
    jmp !loop-

// 8367
// wait for interrupt or 'Q' kepress
wait_for_state_change:
    lda #$00
    sta main.interrupt.flag__enable
!loop:
    jsr common.check_stop_keypess
    lda main.interrupt.flag__enable
    beq !loop-
    jmp common.stop_sound

// 8377
interrupt_handler:
    jsr board.draw_magic_square
    lda main.interrupt.flag__enable
    bpl !next+
    jmp common.complete_interrupt
!next:
    lda game.state.flag__is_player_turn_started
    bmi new_player_sound
    // Initialize turn.
    lda #$80
    sta game.state.flag__is_player_turn_started
    lda #$00
    sta main.temp.data__dark_piece_count
    sta main.temp.data__light_piece_count
    // sta  WBCFC // TODO unknown !!!!!
    // sta  WBCF2 // TODO unknown !!!!!
    // Configure new player turn sound.
    tax
    ldy state.flag__is_curr_player_light
    bpl !next+
    inx
!next:
    lda #$81
    sta common.sound.flag__enable_voice
    lda #$00
    sta common.sound.new_note_delay
    txa
    asl
    tay
    lda sound.phrase_ptr+4,y
    sta OLDTXT
    lda sound.phrase_ptr+5,y
    sta OLDTXT+1
new_player_sound:
    jsr board.play_character_sound
    // Wait before turn can begin.
    lda delay_before_turn
    beq !next+
    dec delay_before_turn 
    jmp common.complete_interrupt 
!next:
    // 83C6  AD 09 BD   lda WBD09 // TODO
    beq !next+
    eor #$FF
    // 83CD  8D 09 BD   sta WBD09 // TODO
    bmi !next+                
    jmp common.complete_interrupt 
!next:
    lda #$00
    // 83D7  8D 3D BD   sta WBD3D // TODO
    // 83DA  8D 0D BD   sta temp_data__sprite_x_direction_offset_1
    // Set player offset.
    tay
    lda state.flag__is_curr_player_light
    bpl !next+
    iny
!next:
    sty curr_player_offset
    tya
    eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
    tax
    lda state.flag__is_curr_player_light
    cmp state.flag__ai_player_ctl
    bne !next+
    jmp ai.board_cursor_to_piece
!next:
    // Get joystick command. x=0 for joystick 2 and 1 for joystick 1.
    lda CIAPRA,x
    and #%0001_0000 // Fire button


    jmp common.complete_interrupt // TODO - remove!

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace sound {
    // 95f4
    phrase_ptr:
        .word board.sound.phrase_hit_player_light   // 00
        .word board.sound.phrase_hit_player_dark    // 02
        .word board.sound.phrase_player_light_turn  // 04
        .word board.sound.phrase_player_dark_turn   // 06
}

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
    // BCC0
    // Is positive (55) for AI light, negative (AA) for AI dark, (00) for neither, (FF) or both.
    flag__ai_player_ctl: .byte $00

    // BCC2
    flag__is_first_player_light: .byte $00 // Is positive (55) for light, negative (AA) for dark

    // BCC6
    flag__is_curr_player_light: .byte $00 // Is positive for light, negative for dark

    // BCD2
    flag__is_player_turn_started: .byte $00 // Is positive if player turn has just started
}

//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
//
.segment DynamicData

// BCED
flag__round_complete: .byte $00 // Toggles after each play so is high after both players had completed thier turn

// BCDE
curr_player_offset: .byte $00 // Is 0 for player 1 and 1 for player 2. Used mostly as a memory offset index.

// BCF3
delay_before_turn: .byte $00 // Delay before start of each turn can commence

// BD11
curr_color_phase: .byte $00 // Current board color phase (colors phase between light and dark as time progresses)

// BD24
imprisoned_piece_id: .byte $00, $00 // Imprisoned piece ID for each player (offset 0 for light, 1 for dark)

// BD70
curr_stalemate_count: .byte $00 // Countdown of moves left until stalemate occurs (0 for disabled)

// BD7C
curr_square_occupancy: .fill BOARD_NUM_ROWS*BOARD_NUM_COLS, $00 // Board square occupant data (#$80 for no occupant)

// BDFD
curr_piece_strength: .fill BOARD_NUM_PIECES, $00 // Current strength of each board piece
