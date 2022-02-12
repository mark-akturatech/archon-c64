.filenamespace game

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for playing the board game.
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
    lda #$FE // 2 columns to the left of board for light player
    bit state.flag__is_light_turn
    bpl !next+
    lda #$0A // Or 2 columns to the right of board for dark player
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
    sta main.interrupt.raster_fn_ptr
    lda #>main.play_game
    sta main.interrupt.raster_fn_ptr+1
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
    ldy board.data.magic_square_row,x
    lda (FREEZP),y // Get ID of icon on magic square
    bmi !check_win_next+ // Square unoccupied
    // This is clever - continually OR $40 for light or $80 for dark. If all squares are occupied by the same player
    // then the result should be $40 or $80. If squares are occupied by multiple players, the result will be $C0
    // (ie $80 OR $40) and therefore no winner.
    ldy #$40
    cmp #BOARD_NUM_PLAYER_ICONS
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
    sta data__dark_icon_count
    sta data__light_icon_count
    sta main.temp.data__curr_count
    ldx #(BOARD_TOTAL_NUM_ICONS - 1)
!loop:
    lda curr_icon_strength,x
    beq !check_next+
    ldy #$40
    cpx #BOARD_NUM_PLAYER_ICONS
    bcc !next+
    inc data__dark_icon_count
    stx data__remaining_dark_icon_id
    ldy #$80
    bmi !next++
!next:
    inc data__light_icon_count
    stx data__remaining_light_icon_id
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
    // after each side has moved. The coutner is reset though when a challenge occurs. If the counter reaches ($F0)
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
    cmp #PHASE_CYCLE_LENGTH
    bne !next+
    // Board is white
    lda #$FF
    sta imprisoned_icon_id // Remove imprisoned light icon
    ldx #$11 // Light player icon offset
    jsr regenerate_hitpoints
!next:
    // Increase strength of all icons on magic squares.
    ldx #$04 // 5 magic squares (0 offset)
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
    ldy data__dark_icon_count
    cpy #$02
    bcs check_game_state
    ldy data__remaining_dark_icon_id
    cpy imprisoned_icon_id+1
    bne check_game_state
    jmp game_over__imprisoned
!next:
    // Check if light icon is imprisoned.
    ldy data__light_icon_count
    cpy #$02
    bcs check_game_state
    ldy data__remaining_light_icon_id
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
    lda #FLAG_DISABLE
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
    sta flag__is_challenge_required
    sta curr_icon_total_moves
    sta magic.curr_spell_cast_selection
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
    ldx #$40 // Short AI start delay if AI vs AI
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
    sty main.temp.data__curr_icon_row
    sty icon_move_row_buffer
    // Copy sprite animation set for selected icon in to graphical memory.
    ldx #$00
    jsr board.convert_coord_sprite_pos
    jsr board.sprite_initialize
    lda #BYTERS_PER_STORED_SPRITE
    sta board.sprite.copy_length
    jsr board.add_sprite_set_to_graphics
    // detect if piece can move?
    ldx board.icon.offset
    lda board.icon.number_moves,x
    sta curr_icon_total_moves
    bmi select_icon // Selected icon can fly - don't need to check surrounding squares
    // Check if piece is surrounded by the same player icons and cannot move.
    jsr board.surrounding_squares_coords
    ldx #$07 // Starting at 7 and reducing by 2 means we do not check the diagonal our selected icon sqaures
!loop:
    // Check if adjacent square is occupied by an icon of the same color or is off board.
    lda board.surrounding_square_row,x
    bmi !next+
    cmp #$09
    bcs !next+
    tay
    lda board.surrounding_square_column,x
    bmi !next+
    cmp #$09
    bcs !next+
    jsr get_square_occupancy
    bmi select_icon // Empty adjacent square found
    tay
    lda board.icon.init_matrix,y
    eor state.flag__is_light_turn
    and #$08
    bne select_icon // Adjacent enemy piece found
!next:
    dex
    dex
    bpl !loop-
    // Show cannot move warning.
    ldx #CHARS_PER_SCREEN_ROW
    lda #STRING_CANNOT_MOVE
    jsr board.write_text
    jsr board.add_icon_to_matrix
    ldx #$60 // ~1.5 sec
    jsr common.wait_for_jiffy
    jsr board.clear_text_area
    jmp play_turn
select_icon:
    bit curr_icon_total_moves
    bvs set_icon_speed // Don't remove piece from board if selected icon can teleport
    jsr board.draw_board
    lda #$00 // 00 for moving select icon (01 for moving selection square)
    sta main.temp.data__curr_sprite_ptr
    // Configure and enable selected icon sprite.
    lda SPMC
    ora #%0000_0001
    sta SPMC
    lda XXPAND
    and #%11111_1110
    sta XXPAND
    lda SPENA
    ora #%0000_0001
    sta SPENA
set_icon_speed:
    lda #$00
    sta curr_icon_move_speed
    lda board.icon.offset
    and #$07
    cmp #$03 // Golem or Troll?
    bne !next+
    inc curr_icon_move_speed // Slow down movement of golem and troll
!next:
    lda state.flag__ai_player_ctl
    cmp state.flag__is_light_turn
    bne configure_selected_icon
    // AI piece selection. // TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // 82E5  AD FD BC   lda curr_icon_total_moves
    // 82E8  30 20      bmi W830A
    // 82EA  AC 38 BD   ldy temp_data__num_icons
    // 82ED  B9 32 BD   lda WBD32,y
    // 82F0  A0 00      ldy #$00
    // W82F2:
    // 82F2  38         sec
    // 82F3  E9 09      sbc #$09
    // 82F5  90 03      bcc W82FA
    // 82F7  C8         iny
    // 82F8  B0 F8      bcs W82F2
    // W82FA:
    // 82FA  69 09      adc #$09
    // 82FC  A2 04      ldx #$04
    // 82FE  20 22 64   jsr board.convert_coord_sprite_pos
    // 8301  8D 17 BD   sta main_temp_data__sprite_final_x_pos
    // 8304  8C 15 BD   sty intro_sprite_final_y_pos
    // 8307  CE 38 BD   dec temp_data__num_icons
    // W830A:
    // 830A  AE 22 BF   ldx main.temp.flag__is_valid_square
    // 830D  BD 5B BE   lda WBE5B,x
    // 8310  8D 28 BD   sta WBD28
    // 8313  BC 6D BE   ldy WBE6D,x
    // 8316  8C 29 BD   sty WBD29
    // 8319  AE FD BC   ldx curr_icon_total_moves
    // 831C  10 1A      bpl configure_selected_icon
    // 831E  A2 04      ldx #$04
    // 8320  20 22 64   jsr board.convert_coord_sprite_pos
    // 8323  2C FD BC   bit curr_icon_total_moves
    // 8326  50 0A      bvc W8332
    // 8328  38         sec
    // 8329  E9 02      sbc #$02
    // 832B  48         pha
    // 832C  98         tya
    // 832D  38         sec
    // 832E  E9 01      sbc #$01
    // 8330  A8         tay
    // 8331  68         pla
    // W8332:
    // 8332  8D 17 BD   sta main_temp_data__sprite_final_x_pos
    // 8335  8C 15 BD   sty intro_sprite_final_y_pos
    //
configure_selected_icon:
    ldx #$00
    stx curr_icon_move_count
    jsr board.get_sound_for_icon
    jsr wait_for_state_change
    //
    // Icon destination selected.
    lda magic.curr_spell_cast_selection
    beq !next+
    jsr magic.select_spell
!next:
    lda flag__icon_can_cast
    bpl end_turn
    // Transport piece (selected from trasport spell or when moving spell caster)
    ldx board.icon.type
    lda board.icon.init_matrix,x
    sta board.icon.offset
    jsr transport_icon
end_turn:
    lda flag__is_challenge_required
    bmi !next+
    jmp entry
!next:
    jmp challenge.entry

// 64EB
// Regenerate hitpoints for all icons of the current player.
// - X register is $23 (dark) or $11 (light)
// Loops through all players icons (backwards) and increases all icon's hitpoints up to the initial hitpoints.
// This operation is performed when the board color is strongest for the player (ie white for light and black for
// dark).
regenerate_hitpoints:
    txa
    sec
    sbc #BOARD_NUM_PLAYER_ICONS
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
    cmp #PHASE_CYCLE_LENGTH
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
    cmp #PHASE_CYCLE_LENGTH
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
    lda #PHASE_CYCLE_LENGTH
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
// Description:
// - Print game over message, play outro music and reset game.
// Prerequisites:
// - `main.temp.data__curr_count` contains the winning side:
//      $40: light player
//      $80: dark player
//      $C0: tie
//      $01: stalemate
game_over:
    jsr board.clear_last_text_row
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
    sta main.interrupt.raster_fn_ptr
    lda #>board.interrupt_handler
    sta main.interrupt.raster_fn_ptr+1
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
    lda #FLAG_ENABLE // Intro
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
    lda #FLAG_DISABLE
    sta main.curr_pre_game_progress
    jmp main.restart_game_loop
!next:
    jmp !loop-

// 7906
// Description:
// - Checks if any of the squares surrounding the current square is empty and non-magical.
// Prerequisites:
// - `main.temp.data__curr_icon_row`: row of source square
// - `main.temp.data__curr_icon_col`: column of source square
// Sets:
// - `main.temp.flag__is_valid_square`: #$80 if one or more surrounding squares are empty and non-magical
// - `surrounding_square_row`: Contains an array of rows for all 9 squares (including source)
// - `surrounding_square_column`: Contains an array of columns for all 9 squares (including source)
check_empty_non_magic_surrounding_square:
    lda #(FLAG_ENABLE/2) // Default to no action - used $40 here so can do quick asl to turn in to $80 (flag_enable)
    sta main.temp.flag__is_valid_square
    jsr board.surrounding_squares_coords
    ldx #$08 // Number of surrounding squares (and current square)
!loop:
    // Test if surrounding sqaure is occupied or is a magic sqaure. If so, test the next square. Set ENABLE flag and
    // exit as soon as an empty/non-magic sqaure is found.
    lda board.surrounding_square_row,x
    bmi !next+
    cmp #$09 // Only test columns 0-8
    bcs !next+
    tay
    sty main.temp.data__curr_row
    lda board.surrounding_square_column,x
    bmi !next+
    cmp #$09 // Only test rows 0-8
    bcs !next+
    sta main.temp.data__curr_column
    jsr get_square_occupancy
    bpl !next+
    jsr board.test_magic_square_selected
    lda main.temp.flag__icon_destination_valid
    bmi !next+
    // Empty non-magical square found.
    lda state.flag__is_light_turn
    cmp state.flag__ai_player_ctl
    // 7948  F0 04      beq W794E // TODO: AI
    asl main.temp.flag__is_valid_square
    rts
!next:
    dex
    bpl !loop-
    rts

// 8367
// wait for interrupt or 'Q' kepress
wait_for_state_change:
    lda #FLAG_DISABLE
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
    lda #FLAG_ENABLE
    sta game.state.flag__is_turn_started
    lda #$00
    sta data__dark_icon_count
    sta data__light_icon_count
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
    lda resource.sound.board_pattern_ptr+4,y
    sta OLDTXT
    lda resource.sound.board_pattern_ptr+5,y
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
    lda #FLAG_DISABLE
    sta flag__new_square_selected
    sta flag__board_sprite_moved
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
    lda magic.curr_spell_cast_selection
    cmp #(FLAG_ENABLE+SPELL_ID_CEASE)
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
    lda data__board_sprite_move_x_count
    ora data__board_sprite_move_y_count
    and #$7F
    bne move_sprite_to_square
    // Select icon.
    lda #FLAG_ENABLE
    sta flag__icon_selected
    lda #$10 // Wait 10 interrupts before allowing icon destination square selection
    sta curr_debounce_count
    jsr select_or_move_icon
    lda main.temp.flag__icon_destination_valid
    bmi !next+
    lda flag__new_square_selected
    bpl move_sprite_to_square
    jsr display_message // Display message if selected icon is imprisoned
    jmp common.complete_interrupt
!next:
    sta main.interrupt.flag__enable
    sta flag__interrupt_response
    jmp common.complete_interrupt
    //
move_sprite_to_square:
    lda curr_player_offset
    eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
    tax
    // The icon select cursor can move diagonally. Icons cannot.
    lda curr_icon_total_moves
    beq check_joystick_left_right
    bmi check_joystick_left_right
    // Don't bother checking joystick position until we reach the previously selected square.
    lda data__board_sprite_move_x_count
    ora data__board_sprite_move_y_count
    and #$7F
    beq check_joystick_left_right
    jmp set_sprite_square_position
check_joystick_left_right:
    lda CIAPRA,x
    pha // Put joystick status on stack
    lda magic.curr_spell_cast_selection
    cmp #(FLAG_ENABLE+SPELL_ID_CEASE)
    beq check_joystick_up_down
    // Disable joystick left/right movement if sprite has not reached X direction final position.
    lda data__board_sprite_move_x_count
    and #$7F
    bne move_up_down
    pla
    pha
    and #$08 // Joystick right
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
    lda curr_icon_total_moves
    beq check_joystick_up_down
    bmi check_joystick_up_down
    lda flag__new_square_selected
    beq check_joystick_up_down
    bmi check_joystick_up_down
    pla
    jmp set_sprite_square_position
    // Disable joystick up/down movement if sprite has not reached Y direction final position.
check_joystick_up_down:
    lda data__board_sprite_move_y_count
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
    jsr display_message
set_sprite_square_position:
    ldx main.temp.data__curr_sprite_ptr // 01 if moving selection square, 00 if moving icon
    lda data__board_sprite_move_x_count // Number of pixels to move in x direction ($00-$7f for right, $80-ff for left)
    beq !next+
    bmi check_move_sprite_left
    // Move sprite right.
    inc common.sprite.curr_x_pos,x
    dec data__board_sprite_move_x_count
    inc flag__board_sprite_moved
    bpl !next+
check_move_sprite_left:
    and #$7F
    beq !next+
    // Move sprite left.
    dec common.sprite.curr_x_pos,x
    dec data__board_sprite_move_x_count
    inc flag__board_sprite_moved
!next:
    lda data__board_sprite_move_y_count // Number of pixels to move in y direction ($00-$7f for down, $80-ff for up)
    beq !next+
    bmi check_move_sprite_up
    // Move sprite down.
    inc common.sprite.curr_y_pos,x
    dec data__board_sprite_move_y_count
    inc flag__board_sprite_moved
    bpl !next+
check_move_sprite_up:
    and #$7F
    beq !next+
    // Move sprite up.
    dec common.sprite.curr_y_pos,x
    dec data__board_sprite_move_y_count
    inc flag__board_sprite_moved
!next:
    lda flag__board_sprite_moved
    bne !next+
    // Stop sound and reset current animation frame when movemement stopped.
    sta common.sprite.curr_animation_frame,x // A = 00
    cpx #$01 // X is 01 if moving square, 00 for moving icon
    beq render_selected_sprite
    sta common.sound.flag__enable_voice
    sta VCREG1
    sta common.sound.new_note_delay
    jmp render_selected_sprite
!next:
    lda magic.curr_spell_cast_selection
    bmi !next+
    jsr board.clear_last_text_row
!next:
    cpx #$01 // X is 01 if moving square, 00 for moving icon
    beq render_selected_sprite
    // Set animation frame for selected icon and increment frame after 4 pixels of movement.
    // The selected initial frame is dependent on the direction of movement.
    lda icon_dir_frame_offset
    sta common.sprite.init_animation_frame,x
    inc data__curr_frame_adv_count
    lda data__curr_frame_adv_count
    and #$03
    cmp #$03
    bne render_selected_sprite
    inc common.sprite.curr_animation_frame,x
    // Configure movement sound effect for selected piece.
    lda #FLAG_ENABLE
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
    sta data__board_sprite_move_x_count
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
    lda #$11 // Left facing icon
    sta icon_dir_frame_offset
    jsr verify_valid_move
    lda #$8C // Move 12 pixels to the left
    sta data__board_sprite_move_x_count
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
    sta data__board_sprite_move_y_count
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
    sta data__board_sprite_move_y_count
    inc main.temp.data__curr_board_row
    lda #$01
    sta flag__new_square_selected
!return:
    rts

// 86C8
// This method keeps track of movement and ensures an icon can only move a certain number of squares and reports
// errors if the icon cannot move, the square is occupied or the square requires a challenge.
// Little bit naughty here - many of the subroutines include 4 PLAs before the RTS if the square cannot be selected.
// The effect of this is to pull the return address for the subroutine and this subroutine from the stack and therefore
// the RTS will return from the calling subroutine. The calling subroutine calls this sub just before adding to the
// X or Y movement counters, so this stops the icon or square from moving.
// Prerequisites:
// - Selected square column must be stored in `main.temp.data__curr_column`
// - Selected square row must be stored in `main.temp.data__curr_row`
// - Current number of moves held in `curr_icon_move_count`
// - Total number of moves held in `curr_icon_total_moves`
// - Path of previous moves stored in `icon_move_col_buffer` and `icon_move_row_buffer`
verify_valid_move:
    lda curr_icon_total_moves
    beq !return+
    bmi check_move_limit // Can fly? Skip occupied square check on move.
    // Reduce move counter if piece moved back to same square as last move.
    ldy curr_icon_move_count
    beq check_occupied_on_move
    dey
    lda icon_move_col_buffer,y
    cmp main.temp.data__curr_column
    bne check_occupied_on_move
    lda icon_move_row_buffer,y
    cmp main.temp.data__curr_row
    bne check_occupied_on_move
    dec curr_icon_move_count
    rts
check_occupied_on_move:
    jsr warn_on_challenge
    jsr warn_on_move_limit_reached
    jsr warn_on_occupied_square
    // Store the move so that we can check the move path to calculate the total number of moves.
    inc curr_icon_move_count
    ldy curr_icon_move_count
    lda main.temp.data__curr_row
    sta icon_move_row_buffer,y
    lda main.temp.data__curr_column
    sta icon_move_col_buffer,y
    rts
check_move_limit:
    cmp #$8F // Skip move limit check (eg when a piece is transported)
    beq !return+
    jsr warn_on_diagonal_move_exceeded
!return:
    rts

// 870D
// Selects an icon on joystick fire button or moves a selected icon to the selected destination on joystick fire.
// This method also detects double fire on a spell caster and activates spell selection.
select_or_move_icon:
    lda #(FLAG_ENABLE/2) // Default to no action - used $40 here so can do quick asl to turn in to $80 (flag_enable)
    sta main.temp.flag__icon_destination_valid
    ldy main.temp.data__curr_board_row
    lda main.temp.data__curr_board_col
    jsr get_square_occupancy
    ldx magic.curr_spell_cast_selection // Magic caster selected
    beq !next+
    jmp magic.spell_select
!next:
    ldx curr_icon_total_moves // is 0 when char is first selected
    beq select_icon_to_move
check_icon_destination:
    cmp #BOARD_EMPTY_SQUARE
    // Note that square will be empty if drop of selected piece source square. We'll check for that later.
    beq select_icon_destination
    sta curr_challenge_icon_type
    tay
    lda board.icon.init_matrix,y
    eor state.flag__is_light_turn
    and #$08
    beq !return+ // Do nothing if click on occupied square of same color
    lda #FLAG_ENABLE // Valid action
    sta main.temp.flag__icon_destination_valid
    sta flag__is_challenge_required
    // Set flag if icon transports instead of moves. Used to determine if should show icon moving between squares or
    // keep the current square selection icon.
    lda curr_icon_total_moves
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
    bit curr_icon_total_moves
    bvc !return+ // Don't allow drop on selected piece source square if not a spell caster
    // If spell caster is selected, set spell cast mode if source square selected as destination
    lda #FLAG_ENABLE
    sta magic.curr_spell_cast_selection
    bmi add_icon_to_destination
set_icon_destination:
    lda curr_icon_total_moves
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
    // Ignore if no icon in selected source square
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
    ldx magic.curr_spell_cast_selection // Don't clear square if selected a magic caster as they teleport instead of moving
    bmi !return-
    sta (FREEZP),y // Clears current square as piece is now moving
    rts
!next:
    lda #(FLAG_ENABLE+STRING_ICON_IMPRISONED)
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

// 88Bf
// Challenge warning is only shown if try to move off a square occupied by the other player. The player must either
// challenge or move to the previous square they were in to continue moving.
warn_on_challenge:
    ldy main.temp.data__curr_board_row
    lda main.temp.data__curr_board_col
    jsr get_square_occupancy
    cmp #BOARD_EMPTY_SQUARE
    beq !return+
    tay
    lda board.icon.init_matrix,y
    eor state.flag__is_light_turn
    and #$08
    beq !return+
    lda #(FLAG_ENABLE+STRING_CHALLENGE_FOE)
    sta flag__new_square_selected
    pla // Abort move
    pla
    pla
    pla
!return:
    rts

// 88E1
// Detect if the destination square is already occupied by an icon for the same player. Abort the move it is is.
warn_on_occupied_square:
    ldy main.temp.data__curr_row
    lda main.temp.data__curr_column
    jsr get_square_occupancy
    cmp #BOARD_EMPTY_SQUARE
    beq !return+
    tay
    lda board.icon.init_matrix,y
    eor state.flag__is_light_turn
    and #$08
    bne !return+
    lda #(FLAG_ENABLE+STRING_SQUARE_OCCUPIED)
    sta flag__new_square_selected
    pla // Abort move
    pla
    pla
    pla
!return:
    rts

// 8903
// Calculate if diagonal move limit exceeded.
warn_on_diagonal_move_exceeded:
    lda main.temp.data__curr_column
    sec
    sbc main.temp.data__curr_icon_col
    bcs !next+
    eor #$FF
    adc #$01
!next:
    sta main.temp.data__math_store_1
    lda main.temp.data__curr_row
    sec
    sbc main.temp.data__curr_icon_row
    bcs !next+
    eor #$FF
    adc #$01
!next:
    sta main.temp.data__math_store_2
    //
    lda curr_icon_total_moves
    and #$3F
    cmp main.temp.data__math_store_1
    bcc show_limit_reached_message
    cmp main.temp.data__math_store_2
    bcs !return+
show_limit_reached_message:
    lda #(FLAG_ENABLE+STRING_LIMIT_MOVED)
    sta flag__new_square_selected
    pla // Abort move
    pla
    pla
    pla
!return:
    rts

// 893C
// Incremenet the move counter and display the limit reached warning if the player has no more moves left.
warn_on_move_limit_reached:
    ldy curr_icon_move_count
    iny
    cpy curr_icon_total_moves
    bcc !return-
    bne show_limit_reached_message
    rts

// 8953
// Displays an error message on piece selection. The message has $80 added to it and is stored in
// `flag__new_square_selected`. This method specifically preserves the X register.
display_message:
    jsr board.clear_last_text_row
    txa
    pha
    ldx #CHARS_PER_SCREEN_ROW
    lda message_id
    and #$7F
    jsr board.write_text
    pla
    tax
    rts

// 897B
// transport piece
transport_icon:
    ldx #$00
    stx main.temp.flag__alternating_state
    // Enable 2 sprites for animating transport from and to - the source sprite is slowly removed from the source
    // location and rebuilt at the destination location. This is done by removing one line from the source (every 3
    // interrupts) and adding it to the destination.
    lda #%0000_1111
    sta SPTMEM
    sta SPTMEM+1
    jsr common.clear_mem_sprite_24
    lda SPMC
    ora #%000_0011
    sta SPMC
    lda XXPAND
    and #%1111_1100
    sta XXPAND
    // Configure source icon.
    lda #(BYTERS_PER_STORED_SPRITE-1)
    sta data__temp_store_2
    lda main.temp.data__curr_icon_col
    ldy main.temp.data__curr_icon_row
    jsr board.convert_coord_sprite_pos
    ldy board.icon.type
    lda board.icon.init_matrix,y
    sta board.icon.offset
    jsr board.sprite_initialize
    //
    lda common.sprite.mem_ptr_00
    sta FREEZP+2
    lda common.sprite.mem_ptr_00+1
    sta FREEZP+3
    lda #BYTERS_PER_STORED_SPRITE
    sta board.sprite.copy_length
    lda common.sprite.init_animation_frame
    beq !next+
    lda #FLAG_ENABLE // Invert sprite
!next:
    sta main.temp.data__icon_set_sprite_frame
    jsr board.add_sprite_to_graphics
    //
    ldx #$01
    lda #$00
!loop:
    sta common.sprite.init_animation_frame,x
    sta common.sprite.curr_animation_frame,x
    dex
    bpl !loop-
    //
    tax
    jsr board.render_sprite
    jsr board.draw_board
    // Configure destination icon.
    ldx #$01
    lda main.temp.data__curr_board_col
    ldy main.temp.data__curr_board_row
    jsr board.convert_coord_sprite_pos
    jsr board.render_sprite
    // Configure transport sound effect.
    lda #FLAG_ENABLE
    sta common.sound.flag__enable_voice
    ldx #$00
    stx common.sound.new_note_delay
    //
    lda #<resource.sound.pattern_transport
    sta OLDTXT
    lda #>resource.sound.pattern_transport
    sta OLDTXT+1
    lda resource.sound.pattern_transport+5 // This note increases in patch as animation runs
    sta data__temp_note_store
    jsr board.play_icon_sound
    // Configure sprite source and destination pointers (for line by line copy)
    lda common.sprite.mem_ptr_00
    sta FREEZP
    lda common.sprite.mem_ptr_00+1
    sta FREEZP+1
    lda common.sprite.mem_ptr_24
    sta FREEZP+2
    lda common.sprite.mem_ptr_24+1
    sta FREEZP+3
    // Set interrupt handler for transport animation.
    sei
    lda #<transport_icon_interrupt
    sta main.interrupt.raster_fn_ptr
    lda #>transport_icon_interrupt
    sta main.interrupt.raster_fn_ptr+1
    cli
    // Wait for animation to completee.
    jsr wait_for_state_change
    lda #%0000_1111
    sta SPTMEM
    rts

// 8A37
// Performs an animation when transporting an icon from one location to another.
transport_icon_interrupt:
    jsr board.draw_magic_square
    lda main.interrupt.flag__enable
    bmi !return+
    // Animate every 4th interrupt.
    inc main.temp.flag__alternating_state
    lda main.temp.flag__alternating_state
    and #$03
    beq !next+
!return:
    jmp common.complete_interrupt
!next:
    // Play sound.
    lda #$00
    sta VCREG1
    lda data__temp_note_store
    clc
    adc #$02
    sta data__temp_note_store
    sta FREHI1
    lda #$11
    sta VCREG1
    // Copy 2 lines of the source sprite and move to destination sprite.
    ldy data__temp_store_2
    ldx #$03
!loop:
    lda (FREEZP),y    // copy line by line (one line per interrupt - transport effect)
    sta (FREEZP+2),y
    lda #$00
    sta (FREEZP),y
    dey
    bmi !return+ // Copy finished?
    dex
    bne !loop-
    sty data__temp_store_2
    jmp common.complete_interrupt
!return:
    lda flag__is_challenge_required
    bmi !next+
    jsr board.add_icon_to_matrix
!next:
    lda #FLAG_ENABLE
    sta main.interrupt.flag__enable
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace data {
    // 8B77
    // Index of magic squares within the square occupancy array
    magic_sqaure_occupancy_index:
        .byte $04, $24, $28, $2C, $4C

    // BEC0
    // Low byte memory offset of square occupancy data for each board row
    row_occupancy_lo_ptr:
        .fill BOARD_NUM_COLS, <(curr_square_occupancy+i*BOARD_NUM_COLS)

    // BEC9
    // High byte memory offset of square occupancy data for each board row
    row_occupancy_hi_ptr:
        .fill BOARD_NUM_COLS, >(curr_square_occupancy+i*BOARD_NUM_COLS)
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

// BCF3
delay_before_turn: .byte $00 // Delay before start of each turn can commence

// BCFC
flag__icon_selected: .byte $00 // An icon is currently selected for movemement

// BCFD
curr_icon_total_moves: .byte $00 // Selected icon total number moves (+$40 if can cast spells, +$80 if can fly)

// BCFF
flag__is_challenge_required: .byte $00 // Is enabled if the icon must challenge for the destination square

// BD00
curr_challenge_icon_type: .byte $00 // Type of selected icon to challenge for the destination square

// BD09
curr_icon_move_speed: .byte $00 // Delay between movement for selected icon. Is only delayed for Golem and Troll.

// BD0F
// Is $80 if the selected icon can cast spells. Used to determine if icon transports or moves.
flag__icon_can_cast: .byte $00

// BD11
curr_color_phase: .byte $00 // Current board color phase (colors phase between light and dark as time progresses)

// BD24
imprisoned_icon_id: .byte $00, $00 // Imprisoned icon ID for each player (offset 0 for light, 1 for dark)

// BD3D
flag__new_square_selected: // Is set to non-zero if a new board square was selected
message_id: // ID of selected spell used as an offset when calling spell logic
    .byte $00

// BD55
flag__interrupt_response: // Interrrupt response saved after interrupt was completed.
    .byte $00

// BD70
curr_stalemate_count: .byte $00 // Countdown of moves left until stalemate occurs (0 for disabled)

// BD7C
curr_square_occupancy: .fill BOARD_SIZE, $00 // Board square occupant data (#$80 for no occupant)

// BDFD
curr_icon_strength: .fill BOARD_TOTAL_NUM_ICONS, $00 // Current strength of each board icon

// BEA1
curr_icon_move_count: .byte $00 // Selected icon number of moves made in current turn

// BEA2
// Stores each column the icon enters as it is being moved. Used to calculate number of moves.
// Allows for a total of 5 moves (maximum move count) plus the starting column.
icon_move_col_buffer: .byte $00, $00, $00, $00, $00, $00

// BEA8
// Stores each row the icon enters as it is being moved. Used to calculate number of moves.
// Allows for a total of 5 moves (maximum move count) plus the starting row.
icon_move_row_buffer: .byte $00, $00, $00, $00, $00, $00

// BF32
// Dark remaining icon count.
data__dark_icon_count: .byte $00

// BF36
// Light remaining icon count.
data__light_icon_count: .byte $00

// BF32
// Sprite Y position movement counter.
data__board_sprite_move_y_count: .byte $00

// BF33
// Icon ID of last dark icon.
data__remaining_dark_icon_id: .byte $00

// BF37
// Icon ID of last light icon.
data__remaining_light_icon_id: .byte $00

// BF36
// Sprite X position movement counter.
data__board_sprite_move_x_count: .byte $00

// BD68
// Temporary storage for musical note being played.
data__temp_note_store: .byte $00

// BCEE
// Counter used to advance animation frame (every 4 pixels).
data__curr_frame_adv_count: .byte $00

// BCF2
// Current debounce counter (used when debouncing fire button presses).
curr_debounce_count: .byte $00

// BD0D
// Is non-zero if the board sprite was moved (in X or Y direction ) since last interrupt
flag__board_sprite_moved:.byte $00

// BD2D
// Temporary storage
data__temp_store_2: .byte $00
