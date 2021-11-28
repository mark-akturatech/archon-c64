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
    sta board.flag__render_square_ctl
    jsr board.draw_board
    // Swap player because the main game as alternates the player, so it will swaps it back to the correct player.
    lda state.flag__is_light_turn
    eor #$FF
    sta state.flag__is_light_turn
    ldy board.countdown_timer
    bpl !next+
    sta state.flag__ai_player_ctl // AI set to both players on options timeout (demo mode)
!next:
    // Get player and convert to 0 for light, 1 for dark.
    lda state.flag__is_light_turn
    and #$01
    eor #$01
    tay
    lda board.sprite.icon_color,y
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
    // Set position of icon selection sprite.
    ldx #$04 // Sprite 4
    lda #$FE // Column - FE is 2 columns left of 1st column (column 0)
    bit state.flag__is_light_turn
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
    sta common.sprite.curr_animation_frame,y
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
    lda (FREEZP),y // Get ID of icon on magic square
    bmi !check_win_next+ // Square unoccupied
    // This is clever - continually OR $40 for light or $80 for dark. If all squares are occupied by the same player
    // then the result should be $40 or $80. If sqaures are occupied by multiple players, the result will be $C0
    // (ie $80 OR $40) and therefore no winner.
    ldy #$40
    cmp #$12
    bcc !next+ // Player 1 icon?
    ldy #$80
!next:
    tya
    ora main.temp.data__curr_count
    sta main.temp.data__curr_count
    dex
    bpl !loop-
    lda main.temp.data__curr_count
    cmp #$C0 // All icons the same?
    beq !check_win_next+
    jmp game_over
    // Checks if any of the players have no icons left. This is done similar to the magic square occupancy above.
    // If any icons has strength left, a $40 (player 1) or $80 (player 2) is ORed with a total. If both players
    // have icons, the result will be $C0. Otherwise player 1 ($40) or player 2 ($80) is the winner.
!check_win_next:
    lda #$00
    sta main.temp.data__dark_icon_count
    sta main.temp.data__light_icon_count
    sta main.temp.data__curr_count
    ldx #(BOARD_NUM_ICONS - 1)
!loop:
    lda curr_icon_strength,x
    beq !check_next+
    ldy #$40
    cpx #$12
    bcc !next+
    inc main.temp.data__dark_icon_count
    stx main.temp.data__remaining_dark_icon_id
    ldy #$80
    bmi !next++
!next:
    inc main.temp.data__light_icon_count
    stx main.temp.data__remaining_light_icon_id
!next:
    tya
    ora main.temp.data__curr_count
    sta main.temp.data__curr_count
!check_next:
    dex
    bpl !loop-
    lda main.temp.data__curr_count
    bne !next+
    jmp game_over // No icons left on any side. Not sure how this is possible.
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
    bne check_light_icons
    // Board is black
    lda #$FF
    sta imprisoned_icon_id+1 // Remove imprisoned dark icon
    ldx #$23 // Dark player icon offset
    jsr regenerate_hitpoints
    jmp !next+
check_light_icons:
    cmp #$0E
    bne !next+
    // Board is white
    lda #$FF
    sta imprisoned_icon_id // Remove imprisoned light icon
    ldx #$11 // Light player icon offset
    jsr regenerate_hitpoints
!next:
    // Increase strength of all icons on magic squares.
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
    lda curr_icon_strength,x
    ldy board.icon.init_matrix,x
    cmp board.icon.init_strength,y
    bcs !next+
    inc curr_icon_strength,x
!next:
    pla
    tax
    dex
    bpl !loop-
!check_win_next:
    // End the game if player has only one icon and that icon is imprisoned.
    lda game.state.flag__is_light_turn
    bpl !next+
    // Check if dark icon is imprisoned.
    ldy main.temp.data__dark_icon_count
    cpy #$02
    bcs check_game_state
    ldy main.temp.data__remaining_dark_icon_id
    cpy imprisoned_icon_id+1
    bne check_game_state
    jmp game_over__imprisoned
!next:
    // Check if light icon is imprisoned.
    ldy main.temp.data__light_icon_count
    cpy #$02
    bcs check_game_state
    ldy main.temp.data__remaining_light_icon_id
    cpy imprisoned_icon_id
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
    lda #$01 // Each turn can have up to 2 icons enabled - 00=icon sprite, and 01=square selection sprite
    sta main.temp.data__curr_sprite_ptr
    lda #$00
    sta curr_icon_move_speed
    sta game.state.flag__is_turn_started
    sta flag__is_battle_required
    sta curr_icon_num_moves
    sta curr_spell_cast_selection
    sta flag__icon_can_cast
    ldx #$05 // Short delay before start of turn
    // Check AI turn.
    lda game.state.flag__ai_player_ctl
    cmp game.state.flag__is_light_turn
    bne !next+
    jsr ai.board_calculate_move
    ldx #$60 // Normal AI start delay
    lda board.countdown_timer // Will be FF is option timer expired
    bmi !next+
    ldx  #$40 // Short AI start delay if AI vs AI
!next:
    stx delay_before_turn
    jsr wait_for_state_change
    //
    // Get selected icon. The above method only returns after an icon was selected or moved to a destination.
    ldy board.icon.type
    lda board.icon.init_matrix,y
    sta board.icon.offset
    // Display icon name and number of moves.
    tax
    lda board.icon.string_id,x
    ldx #$0A
    jsr board.write_text
    // Configure icon initial location.
    lda main.temp.data__curr_board_col
    sta main.temp.data__curr_icon_col
    sta icon_move_col_buffer
    ldy main.temp.data__curr_board_row
    sty main.temp.data__curr_icon_col
    sty icon_move_row_buffer
    // Copy sprite animation set for selected icon in to graphical memory.
    ldx #$00
    jsr board.convert_coord_sprite_pos
    jsr board.sprite_initialize
    lda #$36
    sta board.sprite.copy_length

    // 8258... TODO
    // ...
    jmp wait_for_state_change // TODO: delete this
    jmp play_turn // TODO: delete this

// 64EB
// Regenerate hitpoints for all icons of the current player.
// - X register is $23 (dark) or $11 (light)
// Loops through all players icons (backwards) and increases all icon's hitpoints up to the initial hitpoints.
// This operation is performed when the board color is strongest for the player (ie white for light and black for
// dark).
regenerate_hitpoints:
    txa
    sec
    sbc #$12
    sta main.temp.data__temp_store // First player icon (offset by 1)
!loop:
    lda curr_icon_strength,x
    beq !next+ // Icon is dead
    ldy board.icon.init_matrix,x
    cmp board.icon.init_strength,y
    bcs !next+ // Icon is fully healed
    inc curr_icon_strength,x
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
// Display game over message if last icon is imprisoned.
// NOTE do not relocate this without jumping to `game_over` method.
game_over__imprisoned:
    lda #STRING_ICON_IMPRISONED
    ldx #$00
    jsr board.write_text
    // Set winner (opposite to current player as current player has the imprisoned icon).
    lda state.flag__is_light_turn
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
    lda game.state.flag__is_turn_started
    bmi new_player_sound
    // Initialize turn.
    lda #$80
    sta game.state.flag__is_turn_started
    lda #$00
    sta main.temp.data__dark_icon_count
    sta main.temp.data__light_icon_count
    sta flag__icon_selected
    sta curr_debounce_count
    // Configure new player turn sound.
    tax
    ldy state.flag__is_light_turn
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
    lda sound.pattern_ptr+4,y
    sta OLDTXT
    lda sound.pattern_ptr+5,y
    sta OLDTXT+1
new_player_sound:
    jsr board.play_icon_sound
    // Wait before turn can begin.
    lda delay_before_turn
    beq !next+
    dec delay_before_turn
    jmp common.complete_interrupt
!next:
    lda curr_icon_move_speed
    beq !next+
    eor #$FF
    sta curr_icon_move_speed
    bmi !next+
    jmp common.complete_interrupt
!next:
    lda #$00
    sta flag__new_square_selected
    sta main.temp.flag__board_sprite_moved
    // Set player offset.
    tay
    lda state.flag__is_light_turn
    bpl !next+
    iny
!next:
    sty curr_player_offset
    tya
    eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
    tax
    lda state.flag__is_light_turn
    cmp state.flag__ai_player_ctl
    bne !next+
    jmp ai.board_cursor_to_icon
    //
!next:
    // Get joystick command. x=0 for joystick 2 and 1 for joystick 1.
    lda CIAPRA,x
    and #%0001_0000 // Fire button
    beq joystick_icon_select
    // Fire button debounce delay countdown to stop accidental selection of piece while moving directly after selecting
    // a piece.
    lda curr_debounce_count
    beq !next+
    dec curr_debounce_count
    jmp move_sprite_to_square
!next:
    sta flag__icon_selected
    beq move_sprite_to_square
joystick_icon_select:
    lda curr_spell_cast_selection
    cmp #SPELL_END
    beq !next+
    // Ensure selected column is within bounds.
    lda main.temp.data__curr_board_col
    bmi move_sprite_to_square
    cmp #$09
    bcs move_sprite_to_square
!next:
    lda flag__icon_selected
    bmi move_sprite_to_square
    // Don't select icon if selection square is still moving (ie not directly over an icon).
    lda main.temp.data__board_sprite_move_x_cnt
    ora main.temp.data__board_sprite_move_y_cnt
    and #$7F
    bne move_sprite_to_square
    // Select icon.
    lda #$80
    sta flag__icon_selected
    lda #$10 // Wait 10 interrupts before allowing icon destination sqaure selection
    sta curr_debounce_count
    jsr select_or_move_icon
    lda main.temp.flag__icon_destination_valid
    bmi !next+
    lda flag__new_square_selected
    bpl move_sprite_to_square
    jsr show_selection_error_message // Display message if selected icon is imprisoned
    jmp common.complete_interrupt
!next:
    sta main.interrupt.flag__enable
    // 844C  8D 55 BD   sta  WBD55 // TODO
    jmp  common.complete_interrupt
    //
move_sprite_to_square:
    lda curr_player_offset
    eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
    tax
    // The icon select cursor can move diagonally. Icons cannot.
    lda curr_icon_num_moves
    beq check_joystick_left_right
    bmi check_joystick_left_right
    // Don't bother checking joystick position until we reach the previously selected square.
    lda main.temp.data__board_sprite_move_x_cnt
    ora main.temp.data__board_sprite_move_y_cnt
    and #$7F
    beq check_joystick_left_right
    jmp set_sprite_square_position
check_joystick_left_right:
    lda  CIAPRA,x
    pha // Put joystick status on stack
    lda curr_spell_cast_selection
    cmp #SPELL_END
    beq check_joystick_up_down
    // Disable joystick left/right movement if sprite has not reached X direction final position.
    lda main.temp.data__board_sprite_move_x_cnt
    and #$7F
    bne move_up_down
    pla
    pha
    and  #$08 // Joystick right
    bne !next+
    jsr set_square_right
    jmp move_up_down
!next:
    pla
    pha
    and #$04 // Joystick left
    bne move_up_down
    jsr set_square_left
move_up_down:
    lda curr_icon_num_moves
    beq check_joystick_up_down
    bmi check_joystick_up_down
    lda flag__new_square_selected
    beq check_joystick_up_down
    bmi check_joystick_up_down
    pla
    jmp set_sprite_square_position
    // Disable joystick up/down movement if sprite has not reached Y direction final position.
check_joystick_up_down:
    lda main.temp.data__board_sprite_move_y_cnt
    and #$7F
    beq !next+
    pla
    jmp set_sprite_square_position
!next:
    pla
    lsr // Joystick up (bit 1 set)
    pha
    bcs !next+
    jsr set_square_up
!next:
    pla
    lsr // Joystick down (bit 2 set)
    bcs !next+
    jsr set_square_down
//
!next:
    lda flag__new_square_selected
    bpl set_sprite_square_position
    jsr show_selection_error_message
set_sprite_square_position:
    ldx main.temp.data__curr_sprite_ptr // 01 if moving selection sqaure, 00 if moving icon
    lda main.temp.data__board_sprite_move_x_cnt // Number of pixels to move in x direction ($00-$7f for right, $80-ff for left)
    beq !next+
    bmi check_move_sprite_left
    // Move sprite right.
    inc common.sprite.curr_x_pos,x
    dec main.temp.data__board_sprite_move_x_cnt
    inc main.temp.flag__board_sprite_moved
    bpl !next+
check_move_sprite_left:
    and #$7F
    beq !next+
    // Move sprite left.
    dec common.sprite.curr_x_pos,x
    dec main.temp.data__board_sprite_move_x_cnt
    inc main.temp.flag__board_sprite_moved
!next:
    lda main.temp.data__board_sprite_move_y_cnt // Number of pixels to move in y direction ($00-$7f for down, $80-ff for up)
    beq !next+
    bmi check_move_sprite_up
    // Move sprite down.
    inc common.sprite.curr_y_pos,x
    dec main.temp.data__board_sprite_move_y_cnt
    inc main.temp.flag__board_sprite_moved
    bpl !next+
check_move_sprite_up:
    and #$7F
    beq !next+
    // Move sprite up.
    dec common.sprite.curr_y_pos,x
    dec main.temp.data__board_sprite_move_y_cnt
    inc main.temp.flag__board_sprite_moved
!next:
    lda main.temp.flag__board_sprite_moved
    bne !next+
    // Stop sound and reset current animation frame when movemement stopped.
    sta common.sprite.curr_animation_frame,x // A = 00
    cpx #$01 // X is 01 if moving sqaure, 00 for moving icon
    beq render_selected_sprite
    sta common.sound.flag__enable_voice
    sta VCREG1
    sta common.sound.new_note_delay
    jmp render_selected_sprite
!next:
    lda curr_spell_cast_selection
    bmi !next+
    jsr board.clear_text_row
!next:
    cpx #$01 // X is 01 if moving sqaure, 00 for moving icon
    beq render_selected_sprite
    // Set animation frame for selected icon and increment frame after 4 pixels of movement.
    // The selected initial frame is dependent on the direction of movement.
    lda icon_dir_frame_offset
    sta common.sprite.init_animation_frame,x
    inc main.temp.data__curr_frame_adv_count
    lda main.temp.data__curr_frame_adv_count
    and #$03
    cmp #$03
    bne render_selected_sprite
    inc common.sprite.curr_animation_frame,x
    // Configure movement sound effect for selected piece.
    lda #$80
    cmp common.sound.flag__enable_voice
    beq render_selected_sprite
    sta common.sound.flag__enable_voice
    lda #$00
    sta common.sound.new_note_delay
    lda board.sound.pattern_lo_ptr
    sta OLDTXT
    lda board.sound.pattern_hi_ptr
    sta OLDTXT+1
render_selected_sprite:
    jsr board.render_sprite
    jmp common.complete_interrupt

// 861E
set_square_right:
    lda main.temp.data__curr_board_col
    bmi !next+
    cmp #$08 // Already on last column?
    bcs !return+
    tay
    iny
    sty main.temp.data__curr_column
    lda main.temp.data__curr_board_row
    sta main.temp.data__curr_line
    lda #$00 // Stating animation frame 0
    sta icon_dir_frame_offset
    jsr verify_valid_move
!next:
    lda #$0C // Move 12 pixels to the right
    sta main.temp.data__board_sprite_move_x_cnt
    inc main.temp.data__curr_board_col
    inc flag__new_square_selected
!return:
    rts

// 8646
set_square_left:
    lda main.temp.data__curr_board_col
    bmi !return+
    beq !return+ // Already on first column?
    tay
    dey
    sty main.temp.data__curr_column
    lda main.temp.data__curr_board_row
    sta main.temp.data__curr_line
    lda #$11 // Stating animation frame 17
    sta icon_dir_frame_offset
    jsr verify_valid_move
    lda #$8C // Move 12 pixels to the left
    sta main.temp.data__board_sprite_move_x_cnt
    dec main.temp.data__curr_board_col
    inc flag__new_square_selected
!return:
    rts

// 866C
set_square_up:
    lda main.temp.data__curr_board_row
    beq !return+ // Already on first row?
    tay
    dey
    sty main.temp.data__curr_line
    lda main.temp.data__curr_board_col
    sta main.temp.data__curr_column
    lda flag__new_square_selected
    cmp #$01
    beq !next+ // Pefer left/right facing when moving diagonally
    lda #$08  // Stating animation frame 8
    sta icon_dir_frame_offset
!next:
    jsr verify_valid_move
    lda #$90 // Move 16 pixels up
    sta main.temp.data__board_sprite_move_y_cnt
    dec main.temp.data__curr_board_row
    lda #$01
    sta flag__new_square_selected
!return:
    rts

// 8699
set_square_down:
    lda main.temp.data__curr_board_row
    cmp #$08 // Already on last row?
    bcs !return+
    tay
    iny
    sty main.temp.data__curr_line
    lda main.temp.data__curr_board_col
    sta main.temp.data__curr_column
    lda flag__new_square_selected
    cmp #$01
    beq !next+ // Pefer left/right facing when moving diagonally
    lda #$04 // Start animation frame 4
    sta icon_dir_frame_offset
!next:
    jsr verify_valid_move
    lda #$10 // Move down 16 pixels
    sta main.temp.data__board_sprite_move_y_cnt
    inc main.temp.data__curr_board_row
    lda #$01
    sta flag__new_square_selected
!return:
    rts

// 86C8
// This method keeps track of movement and ensures an icon can only move a certain number of squares and also stops
// the icon from moving in to an occupied sqaure.
// Little bit naughty here - many of the subroutines include 4 PLAs before the RTS if the square cannot be selected.
// The effect of this is to pull the return address for the subroutine and this subroutine from the stack and therefore
// the RTS will return from the calling subroutine. The calling subroutine calls this sub just before adding to the
// X or Y movement counters, so this stops the icon or sqaure from moving.
// Prerequisites:
// - Selected square column must be stored in `main.temp.data__curr_column`
// - Selected square row must be stored in `main.temp.data__curr_line`
verify_valid_move:
    rts // TODO!!!!!!!!!!!

// 870D
// Selects an icon on joystick fire button or moves a selected icon to the selected destination on joystick fire.
// This method also detects double fire on a spell caster and activates spell selection.
select_or_move_icon:
    lda #$40 // Default to no action - used $40 here so can do quick asl to turn in to $80 (flag_enable)
    sta main.temp.flag__icon_destination_valid
    ldy main.temp.data__curr_board_row
    lda main.temp.data__curr_board_col
    jsr get_square_occupancy
    ldx curr_spell_cast_selection // Magic caster selected
    beq !next+
    // 8720  4C BC 87   jmp  W87BC   // TODO cast spell TODO
!next:
    ldx curr_icon_num_moves // is 0 when char is first selected
    beq select_icon_to_move
check_icon_destination:
    cmp #BOARD_EMPTY_SQUARE
    // Note that square will be empty if drop of selected piece source square. We'll check for that later.
    beq select_icon_destination
    sta curr_battle_icon_type
    tay
    lda board.icon.init_matrix,y
    eor state.flag__is_light_turn
    and #$08
    beq !return+ // Do nothing if click on occupied square of same color
    lda #FLAG_ENABLE // Valid action
    sta main.temp.flag__icon_destination_valid
    sta flag__is_battle_required
    // Set flag if icon transports instead of moves. Used to determine if should show icon moving between sqaures or
    // keep the current sqaure selection icon.
    lda curr_icon_num_moves
    and #ICON_CAN_CAST
    asl
    sta flag__icon_can_cast
!return:
    rts
    //
select_icon_destination:
    lda main.temp.data__curr_board_col
    cmp main.temp.data__curr_icon_col
    bne set_icon_destination
    lda main.temp.data__curr_board_row
    cmp main.temp.data__curr_icon_row
    bne set_icon_destination
    bit curr_icon_num_moves
    bvc !return+ // Don't allow drop on selected piece source square if not a spell caster
    // If spell caster is selected, set spell cast mode if source square selected as destination
    lda #FLAG_ENABLE
    sta curr_spell_cast_selection
    bmi add_icon_to_destination
set_icon_destination:
    lda curr_icon_num_moves
    and #ICON_CAN_CAST
    asl
    sta flag__icon_can_cast
    bmi !next+
add_icon_to_destination:
    // Add piece to the destination square.
    lda board.icon.type
    sta (FREEZP),y
!next:
    asl main.temp.flag__icon_destination_valid // Set valid move
!return:
    rts
    //
select_icon_to_move:
    // Ignore if no icon in selected source sqaure
    cmp #BOARD_EMPTY_SQUARE
    beq !return-
    sta board.icon.type
    // Ignore if selected other player piece.
    tax
    lda board.icon.init_matrix,x
    eor state.flag__is_light_turn
    and #$08
    bne !return-
    // Ignore and set error message if selected icon is imprisoned.
    ldx curr_player_offset
    lda imprisoned_icon_id,x
    cmp board.icon.type
    beq !next+
    // Accept destination.
    lda #FLAG_ENABLE
    sta main.temp.flag__icon_destination_valid
    ldx curr_spell_cast_selection // Don't clear square if selected a magic caster as they teleport instead of moving
    bmi !return-
    sta (FREEZP),y // Clears current square as piece is now moving
    rts
!next:
    lda #(FLAG_ENABLE + STRING_ICON_IMPRISONED)
    sta flag__new_square_selected
    rts

// 88AF
// Returns the icon type (in A) at board row (in Y) and column (in A).
get_square_occupancy:
    pha
    lda data.row_occupancy_lo_ptr,y
    sta FREEZP
    lda data.row_occupancy_hi_ptr,y
    sta FREEZP+1
    pla
    tay
    lda (FREEZP),y
    rts

// 8953
// Displays an error message on piece selection. The message has $80 added to it and is stored in
// `flag__new_square_selected`. This method specifically preserves the X register.
show_selection_error_message:
    jsr board.clear_text_row
    txa
    pha
    ldx #CHARS_PER_SCREEN_ROW
    lda flag__new_square_selected
    and #$7F
    jsr board.write_text      
    pla
    tax
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace sound {
    // 95f4
    pattern_ptr:
        .word board.sound.pattern_hit_player_light   // 00
        .word board.sound.pattern_hit_player_dark    // 02
        .word board.sound.pattern_player_light_turn  // 04
        .word board.sound.pattern_player_dark_turn   // 06
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
    flag__is_light_turn: .byte $00 // Is positive for light, negative for dark

    // BCD2
    flag__is_turn_started: .byte $00 // Is positive if player turn has just started
}

//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
//
.segment DynamicData

// BCEB
icon_dir_frame_offset: .byte $00 // Icon direction initial sprite frame offset

// BCED
flag__round_complete: .byte $00 // Toggles after each play so is high after both players had completed thier turn

// BCDE
curr_player_offset: .byte $00 // Is 0 for player 1 and 1 for player 2. Used mostly as a memory offset index.

// BCF2
curr_debounce_count: .byte $00 // Current debounce counter (used when debouncing fire button presses)

// BCF3
delay_before_turn: .byte $00 // Delay before start of each turn can commence

// BCFC
flag__icon_selected: .byte $00 // An icon is currently selected for movemement

// BCFD
curr_icon_num_moves: .byte $00 // Selected icon number moves (+$40 if can cast spells, +$80 if can fly)

// BCFF
flag__is_battle_required: .byte $00 // Is enabled if the icon must battle for the destination square

// BD00
curr_battle_icon_type: .byte $00 // Type of selected icon to battle for the destination square

// BD09
curr_icon_move_speed: .byte $00 // Delay between movement for selected icon. Is only delayed for Golem and Troll.

// BD0E
curr_spell_cast_selection: .byte $00 // Is 0 for spell caster not selected, $80 for selected and +$80 for selected spell

// BD0F
// Is $80 if the selected icon can cast spells. Used to determine if icon transports or moves.
flag__icon_can_cast: .byte $00

// BD11
curr_color_phase: .byte $00 // Current board color phase (colors phase between light and dark as time progresses)

// BD24
imprisoned_icon_id: .byte $00, $00 // Imprisoned icon ID for each player (offset 0 for light, 1 for dark)

// BD3D
flag__new_square_selected: .byte $00 // Is set to non-zero if a new board square was selected

// BD70
curr_stalemate_count: .byte $00 // Countdown of moves left until stalemate occurs (0 for disabled)

// BD7C
curr_square_occupancy: .fill BOARD_NUM_ROWS*BOARD_NUM_COLS, $00 // Board square occupant data (#$80 for no occupant)

// BDFD
curr_icon_strength: .fill BOARD_NUM_ICONS, $00 // Current strength of each board icon

// BEA2
// Stores each column the icon enters as it is being moved. Used to calculate number of moves.
// Allows for a total of 5 moves (maximum move count) plus the starting column.
icon_move_col_buffer: .byte $00, $00, $00, $00, $00, $00

// BEA8
// Stores each row the icon enters as it is being moved. Used to calculate number of moves.
// Allows for a total of 5 moves (maximum move count) plus the starting row.
icon_move_row_buffer: .byte $00, $00, $00, $00, $00, $00
