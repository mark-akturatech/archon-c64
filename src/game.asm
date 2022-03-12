.filenamespace game
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used during main game play.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 8019
entry:
    jsr common.clear_sprites
    jsr board.clear_text_area
    jsr common.stop_sound
    lda #FLAG_DISABLE
    sta board.param__render_square_ctl
    jsr board.draw_board
    // Swap player because the main game as alternates the player, so it will swaps it back to the correct player.
    lda flag__is_light_turn
    eor #$FF
    sta flag__is_light_turn
    ldy board.cnt__countdown_timer
    bpl !next+
    sta data__ai_player_ctl // AI set to both players on options timeout (demo mode)
!next:
    // Get player and convert to 0 for light, 1 for dark.
    lda flag__is_light_turn
    and #$01
    eor #$01
    tay
    lda common.data__player_icon_color_list,y
    sta SP1COL // Set logo color
    sta SP2COL
    sta SP3COL // Set selection square color
    jsr private.create_title
    jsr board.set_player_color
    jsr board.draw_border
    lda SPMC
    and #%0111_0001 // Set sprites 1, 2, 3 to single color
    sta SPMC
    lda #BLACK
    sta SPMC0
    jsr private.create_selection_square
    lda #%1111_1110 // Expand sprites 1, 2 and 3 horizontally
    sta XXPAND
    lda #%0000_0000
    sta YXPAND
    // Set position of icon selection sprite.
    ldx #$04 // Sprite 4
    lda #$FE // 2 columns to the left of board for light player
    bit flag__is_light_turn
    bpl !next+
    lda #$0A // Or 2 columns to the right of board for dark player
!next:
    sta board.data__curr_board_col
    ldy #$04 // row
    sty board.data__curr_board_row
    jsr board.convert_coord_sprite_pos
    sec
    sbc #$02
    sta board.data__sprite_curr_x_pos_list+1
    tya
    sec
    sbc #$01
    sta board.data__sprite_curr_y_pos_list+1
    lda #%1000_1111
    sta SPENA
    // Clear sprite render variables.
    ldy #$03
    lda #$00
!loop:
    sta common.param__icon_sprite_source_frame_list,y
    sta board.cnt__sprite_frame_list,y
    dey
    bne !loop-
    //
    ldx #$01
    jsr board.set_icon_sprite_location
    jsr board.create_magic_square_sprite
    // Set interrupt handler to set intro loop state.
    sei
    lda #<main.play_game
    sta main.ptr__raster_interrupt_fn
    lda #>main.play_game
    sta main.ptr__raster_interrupt_fn+1
    cli
    // Check and see if the same player is occupying all of the magic squares. If so, the game is ended and that player
    // wins.
    lda #$00
    sta private.flag__remaining_player_pieces
    ldx #(BOARD_NUM_MAGIC_SQUARES-1) // 0 offset
!loop:
    ldy board.data__magic_square_col_list,x
    lda board.ptr__board_row_occupancy_lo,y
    sta FREEZP
    lda board.ptr__board_row_occupancy_hi,y
    sta FREEZP+1
    ldy board.data__magic_square_row_list,x
    lda (FREEZP),y // Get ID of icon on magic square
    bmi !check_win_next+ // Square unoccupied
    // This is clever - continually OR $40 for light or $80 for dark. If all squares are occupied by the same player
    // then the result should be $40 or $80. If squares are occupied by multiple players, the result will be $C0
    // (ie $80 OR $40) and therefore no winner.
    ldy #$40
    cmp #BOARD_NUM_PLAYER_PIECES
    bcc !next+ // Player 1 icon?
    ldy #$80
!next:
    tya
    ora private.flag__remaining_player_pieces
    sta private.flag__remaining_player_pieces
    dex
    bpl !loop-
    lda private.flag__remaining_player_pieces
    cmp #$C0 // All icons the same?
    beq !check_win_next+
    jmp private.game_over
    // Checks if any of the players have no icons left. This is done similar to the magic square occupancy above.
    // If any icons has strength left, a $40 (player 1) or $80 (player 2) is ORed with a total. If both players
    // have icons, the result will be $C0. Otherwise player 1 ($40) or player 2 ($80) is the winner.
!check_win_next:
    lda #$00
    sta private.cnt__dark_icons
    sta private.cnt__light_icons
    sta private.flag__remaining_player_pieces
    ldx #(BOARD_TOTAL_NUM_PIECES-1)
!loop:
    lda data__piece_strength_list,x
    beq !check_next+
    ldy #$40
    cpx #BOARD_NUM_PLAYER_PIECES
    bcc !next+
    inc private.cnt__dark_icons
    stx private.data__last_dark_icon
    ldy #$80
    bmi !next++
!next:
    inc private.cnt__light_icons
    stx private.data__last_light_icon_id
!next:
    tya
    ora private.flag__remaining_player_pieces
    sta private.flag__remaining_player_pieces
!check_next:
    dex
    bpl !loop-
    lda private.flag__remaining_player_pieces
    bne !next+
    jmp private.game_over // No icons left on any side. Not sure how this is possible.
!next:
    cmp #$C0
    beq !check_win_next+
    jmp private.game_over
!check_win_next:
    lda private.flag__is_round_complete
    eor #$FF
    sta private.flag__is_round_complete
    bmi !round_complete+
    jmp !check_win_next+
!round_complete:
    // Counter is loaded with $FC when both sides first have 3 players or less left. The counter is decremented
    // after each side has moved. The coutner is reset though when a challenge occurs. If the counter reaches ($F0)
    // then the game is a stalemate. It is loaded with $FC instead of $12 so we can differentiate beteew a 0 (ie
    // not set) and $F0 (ie stalemate).
    lda cnt__stalemate_moves
    beq !new_phase+
    and #$0F
    bne !next+
    lda #$01 // Stalemate
    sta private.flag__remaining_player_pieces
    jmp private.game_over
!next:
    dec cnt__stalemate_moves
!new_phase:
    ldy #$03 // Board phase state
    jsr private.cycle_phase_counters
    jsr board.draw_board
    lda data__phase_cycle_board
    bne !check_light+
    // Board is black
    lda #FLAG_ENABLE_FF
    sta data__imprisoned_icon_list+1 // Remove imprisoned dark icon
    ldx #$23 // Dark player icon offset
    jsr private.regenerate_hitpoints
    jmp !next+
!check_light:
    cmp #PHASE_CYCLE_LENGTH
    bne !next+
    // Board is white
    lda #FLAG_ENABLE_FF
    sta data__imprisoned_icon_list // Remove imprisoned light icon
    ldx #$11 // Light player icon offset
    jsr private.regenerate_hitpoints
!next:
    // Increase strength of all icons on magic squares.
    ldx #(BOARD_NUM_MAGIC_SQUARES-1) // 0 offset
!loop:
    ldy board.data__magic_square_col_list,x
    lda board.ptr__board_row_occupancy_lo,y
    sta FREEZP
    lda board.ptr__board_row_occupancy_hi,y
    sta FREEZP+1
    ldy board.data__magic_square_col_list,x
    txa
    pha
    lda (FREEZP),y
    bmi !next+ // Unoccupied
    tax
    lda data__piece_strength_list,x
    ldy board.data__piece_icon_offset_list,x
    cmp data__icon_strength_list,y
    bcs !next+
    inc data__piece_strength_list,x
!next:
    pla
    tax
    dex
    bpl !loop-
!check_win_next:
    // End the game if player has only one icon and that icon is imprisoned.
    lda flag__is_light_turn
    bpl !next+
    // Check if dark icon is imprisoned.
    ldy private.cnt__dark_icons
    cpy #$02
    bcs !check_state+
    ldy private.data__last_dark_icon
    cpy data__imprisoned_icon_list+1
    bne !check_state+
    jmp private.game_over__imprisoned
!next:
    // Check if light icon is imprisoned.
    ldy private.cnt__light_icons
    cpy #$02
    bcs !check_state+
    ldy private.data__last_light_icon_id
    cpy data__imprisoned_icon_list
    bne !check_state+
    jmp private.game_over__imprisoned
    //
!check_state:
    lda common.flag__game_loop_state
    beq play_turn // In game?
    // Play game with 0 players if option timer expires.
    lda TIME+1
    cmp data__curr_time
    beq !next+
    sta data__curr_time
    dec board.cnt__countdown_timer
    bpl !next+
    // Start
    lda #FLAG_DISABLE
    sta common.flag__game_loop_state
    jmp main.game_state_loop
!next:
    jsr board.display_options
    jmp !check_state-
    //
play_turn:
    lda #$01 // Each turn can have up to 2 icons enabled - 00=icon sprite, and 01=square selection sprite
    sta flag__is_moving_icon
    lda #$00
    sta data__icon_speed
    sta private.flag__is_turn_started
    sta private.flag__is_challenge_required
    sta data__icon_moves
    sta magic.idx__selected_spell
    sta private.flag__can_icon_cast
    ldx #((1/12)*JIFFIES_PER_SECOND) // Short delay before start of turn
    // Check AI turn.
    lda data__ai_player_ctl
    cmp flag__is_light_turn
    bne !next+
    jsr ai.board_calculate_move
    ldx #(1.5*JIFFIES_PER_SECOND) // Normal AI start delay
    lda board.cnt__countdown_timer // Will be FF is option timer expired
    bmi !next+
    ldx #(1*JIFFIES_PER_SECOND) // Short AI start delay if AI vs AI
!next:
    stx private.cnt__turn_delay
    jsr wait_for_state_change
    //
    // Get selected icon. The above method only returns after an icon was selected or moved to a destination.
    ldy common.param__icon_type_list
    lda board.data__piece_icon_offset_list,y
    sta common.param__icon_offset_list
    // Display icon name and number of moves.
    tax
    lda board.ptr__icon_name_string_id_list,x
    ldx #$0A
    jsr board.write_text
    // Configure icon initial location.
    lda board.data__curr_board_col
    sta board.data__curr_icon_col
    sta private.data__move_col_list
    ldy board.data__curr_board_row
    sty board.data__curr_icon_row
    sty private.data__move_row_list
    // Copy sprite animation set for selected icon in to graphical memory.
    ldx #$00
    jsr board.convert_coord_sprite_pos
    jsr common.initialize_sprite
    lda #BYTERS_PER_ICON_SPRITE
    sta common.param__sprite_source_len
    jsr common.add_sprite_set_to_graphics
    // detect if piece can move?
    ldx common.param__icon_offset_list
    lda private.data__icon_num_moves_list,x
    sta data__icon_moves
    bmi !select_icon+ // Selected icon can fly - don't need to check surrounding squares
    // Check if piece is surrounded by the same player icons and cannot move.
    jsr board.surrounding_squares_coords
    ldx #$07 // Starting at 7 and reducing by 2 means we do not check the diagonal our selected icon squares
!loop:
    // Check if adjacent square is occupied by an icon of the same color or is off board.
    lda board.data__surrounding_square_row_list,x
    bmi !next+
    cmp #$09
    bcs !next+
    tay
    lda board.data__surrounding_square_col_list,x
    bmi !next+
    cmp #$09
    bcs !next+
    jsr get_square_occupancy
    bmi !select_icon+ // Empty adjacent square found
    tay
    lda board.data__piece_icon_offset_list,y
    eor flag__is_light_turn
    and #$08
    bne !select_icon+ // Adjacent enemy piece found
!next:
    dex
    dex
    bpl !loop-
    // Show cannot move warning.
    ldx #NUM_SCREEN_COLUMNS
    lda #STRING_CANNOT_MOVE
    jsr board.write_text
    jsr board.add_icon_to_matrix
    ldx #(1.5*JIFFIES_PER_SECOND)
    jsr common.wait_for_jiffy
    jsr board.clear_text_area
    jmp play_turn
!select_icon:
    bit data__icon_moves
    bvs !set_speed+ // Don't remove piece from board if selected icon can teleport
    jsr board.draw_board
    lda #$00 // 00 for moving select icon (01 for moving selection square)
    sta flag__is_moving_icon
    // Configure and enable selected icon sprite.
    lda SPMC
    ora #%0000_0001
    sta SPMC
    lda XXPAND
    and #%1111_1110
    sta XXPAND
    lda SPENA
    ora #%0000_0001
    sta SPENA
!set_speed:
    lda #$00
    sta data__icon_speed
    lda common.param__icon_offset_list
    and #$07
    cmp #$03 // Golem or Troll?
    bne !next+
    inc data__icon_speed // Slow down movement of golem and troll
!next:
    lda data__ai_player_ctl
    cmp flag__is_light_turn
    bne !config_icon+
    // The original source code has the select_piece logic inline at this location (82E5). We departure here from the
    // source (very rare) so we include the logic within the AI file.
    jsr ai.select_piece
    //
!config_icon:
    ldx #$00
    stx private.cnt__moves
    jsr board.get_sound_for_icon
    jsr wait_for_state_change
    //
    // Icon destination selected.
    lda magic.idx__selected_spell
    beq !next+
    jsr magic.select_spell
!next:
    lda private.flag__can_icon_cast
    bpl !end_turn+
    // Transport piece (selected from trasport spell or when moving spell caster)
    ldx common.param__icon_type_list
    lda board.data__piece_icon_offset_list,x
    sta common.param__icon_offset_list
    jsr private.transport_icon
!end_turn:
    lda private.flag__is_challenge_required
    bmi !next+
    jmp entry
!next:
    jmp challenge.entry

// 8377
interrupt_handler:
    jsr board.draw_magic_square
    lda common.flag__cancel_interrupt_state
    bpl !next+
    jmp common.complete_interrupt
!next:
    lda private.flag__is_turn_started
    bmi !set_sound+
    // Initialize turn.
    lda #FLAG_ENABLE
    sta private.flag__is_turn_started
    lda #$00
    sta private.cnt__dark_icons
    sta private.cnt__light_icons
    sta private.flag__is_icon_selected
    sta private.cnt__joystick_debounce
    // Configure new player turn sound.
    tax
    ldy flag__is_light_turn
    bpl !next+
    inx
!next:
    lda #$81
    sta common.flag__is_player_sound_enabled
    lda #$00
    sta common.data__voice_note_delay
    txa
    asl
    tay
    lda private.ptr__sound_game_effect_list+4,y
    sta OLDTXT
    lda private.ptr__sound_game_effect_list+5,y
    sta OLDTXT+1
!set_sound:
    jsr board.play_icon_sound
    // Wait before turn can begin.
    lda private.cnt__turn_delay
    beq !next+
    dec private.cnt__turn_delay
    jmp common.complete_interrupt
!next:
    lda data__icon_speed
    beq !next+
    eor #$FF
    sta data__icon_speed
    bmi !next+
    jmp common.complete_interrupt
!next:
    lda #FLAG_DISABLE
    sta flag__is_new_square_selected
    sta private.flag__was_sprite_moved
    // Set player offset.
    tay
    lda flag__is_light_turn
    bpl !next+
    iny
!next:
    sty data__player_offset
    tya
    eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
    tax
    lda flag__is_light_turn
    cmp data__ai_player_ctl
    bne !next+
    jmp ai.board_cursor_to_icon
    //
!next:
    // Get joystick command. x=0 for joystick 2 and 1 for joystick 1.
    lda CIAPRA,x
    and #%0001_0000 // Fire button
    beq !select_icon+
    // Fire button debounce delay countdown to stop accidental selection of piece while moving directly after selecting
    // a piece.
    lda private.cnt__joystick_debounce
    beq !next+
    dec private.cnt__joystick_debounce
    jmp !move_sprite+
!next:
    sta private.flag__is_icon_selected
    beq !move_sprite+
!select_icon:
    lda magic.idx__selected_spell
    cmp #(FLAG_ENABLE+SPELL_ID_CEASE)
    beq !next+
    // Ensure selected column is within bounds.
    lda board.data__curr_board_col
    bmi !move_sprite+
    cmp #$09
    bcs !move_sprite+
!next:
    lda private.flag__is_icon_selected
    bmi !move_sprite+
    // Don't select icon if selection square is still moving (ie not directly over an icon).
    lda private.cnt__sprite_x
    ora private.cnt__sprite_y
    and #$7F
    bne !move_sprite+
    // Select icon.
    lda #FLAG_ENABLE
    sta private.flag__is_icon_selected
    lda #$10 // Wait 10 interrupts before allowing icon destination square selection
    sta private.cnt__joystick_debounce
    jsr select_or_move_icon
    lda flag__is_destination_valid
    bmi !next+
    lda flag__is_new_square_selected
    bpl !move_sprite+
    jsr display_message // Display message if selected icon is imprisoned
    jmp common.complete_interrupt
!next:
    sta common.flag__cancel_interrupt_state
    sta data__last_interrupt_response_flag
    jmp common.complete_interrupt
    //
!move_sprite:
    lda data__player_offset
    eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
    tax
    // The icon select cursor can move diagonally. Icons cannot.
    lda data__icon_moves
    beq !check_horizontal+
    bmi !check_horizontal+
    // Don't bother checking joystick position until we reach the previously selected square.
    lda private.cnt__sprite_x
    ora private.cnt__sprite_y
    and #$7F
    beq !check_horizontal+
    jmp !set_square+
!check_horizontal:
    lda CIAPRA,x
    pha // Put joystick status on stack
    lda magic.idx__selected_spell
    cmp #(FLAG_ENABLE+SPELL_ID_CEASE)
    beq !check_vertical+
    // Disable joystick left/right movement if sprite has not reached X direction final position.
    lda private.cnt__sprite_x
    and #$7F
    bne !move_vertical+
    pla
    pha
    and #$08 // Joystick right
    bne !next+
    jsr private.set_square_right
    jmp !move_vertical+
!next:
    pla
    pha
    and #$04 // Joystick left
    bne !move_vertical+
    jsr private.set_square_left
!move_vertical:
    lda data__icon_moves
    beq !check_vertical+
    bmi !check_vertical+
    lda flag__is_new_square_selected
    beq !check_vertical+
    bmi !check_vertical+
    pla
    jmp !set_square+
    // Disable joystick up/down movement if sprite has not reached Y direction final position.
!check_vertical:
    lda private.cnt__sprite_y
    and #$7F
    beq !next+
    pla
    jmp !set_square+
!next:
    pla
    lsr // Joystick up (bit 1 set)
    pha
    bcs !next+
    jsr private.set_square_up
!next:
    pla
    lsr // Joystick down (bit 2 set)
    bcs !next+
    jsr private.set_square_down
!next:
    lda flag__is_new_square_selected
    bpl !set_square+
    jsr display_message
!set_square:
    ldx flag__is_moving_icon // 01 if moving selection square, 00 if moving icon
    lda private.cnt__sprite_x // Number of pixels to move in x direction ($00-$7f for right, $80-ff for left)
    beq !next+
    bmi !move_left+
    // Move sprite right.
    inc board.data__sprite_curr_x_pos_list,x
    dec private.cnt__sprite_x
    inc private.flag__was_sprite_moved
    bpl !next+
!move_left:
    and #$7F
    beq !next+
    // Move sprite left.
    dec board.data__sprite_curr_x_pos_list,x
    dec private.cnt__sprite_x
    inc private.flag__was_sprite_moved
!next:
    lda private.cnt__sprite_y // Number of pixels to move in y direction ($00-$7f for down, $80-ff for up)
    beq !next+
    bmi !move_up+
    // Move sprite down.
    inc board.data__sprite_curr_y_pos_list,x
    dec private.cnt__sprite_y
    inc private.flag__was_sprite_moved
    bpl !next+
!move_up:
    and #$7F
    beq !next+
    // Move sprite up.
    dec board.data__sprite_curr_y_pos_list,x
    dec private.cnt__sprite_y
    inc private.flag__was_sprite_moved
!next:
    lda private.flag__was_sprite_moved
    bne !next+
    // Stop sound and reset current animation frame when movemement stopped.
    sta board.cnt__sprite_frame_list,x // A = 00
    cpx #$01 // X is 01 if moving square, 00 for moving icon
    beq !set_icon_sprite_location+
    sta common.flag__is_player_sound_enabled
    sta VCREG1
    sta common.data__voice_note_delay
    jmp !set_icon_sprite_location+
!next:
    lda magic.idx__selected_spell
    bmi !next+
    jsr private.clear_last_text_row
!next:
    cpx #$01 // X is 01 if moving square, 00 for moving icon
    beq !set_icon_sprite_location+
    // Set animation frame for selected icon and increment frame after 4 pixels of movement.
    // The selected initial frame is dependent on the direction of movement.
    lda private.idx__start_icon_frame
    sta common.param__icon_sprite_source_frame_list,x
    inc private.idx__icon_frame
    lda private.idx__icon_frame
    and #$03
    cmp #$03
    bne !set_icon_sprite_location+
    inc board.cnt__sprite_frame_list,x
    // Configure movement sound effect for selected piece.
    lda #FLAG_ENABLE
    cmp common.flag__is_player_sound_enabled
    beq !set_icon_sprite_location+
    sta common.flag__is_player_sound_enabled
    lda #$00
    sta common.data__voice_note_delay
    lda board.ptr__player_sound_pattern_lo_list
    sta OLDTXT
    lda board.ptr__player_sound_pattern_hi_list
    sta OLDTXT+1
!set_icon_sprite_location:
    jsr board.set_icon_sprite_location
    jmp common.complete_interrupt

// 8367
// wait for interrupt or 'Q' kepress
wait_for_state_change:
    lda #FLAG_DISABLE
    sta common.flag__cancel_interrupt_state
!loop:
    jsr common.check_stop_keypess
    lda common.flag__cancel_interrupt_state
    beq !loop-
    jmp common.stop_sound


// 870D
// Selects an icon on joystick fire button or moves a selected icon to the selected destination on joystick fire.
// This method also detects double fire on a spell caster and activates spell selection.
select_or_move_icon:
    lda #(FLAG_ENABLE/2) // Default to no action - used $40 here so can do quick asl to turn in to $80 (flag_enable)
    sta flag__is_destination_valid
    ldy board.data__curr_board_row
    lda board.data__curr_board_col
    jsr get_square_occupancy
    ldx magic.idx__selected_spell // Magic caster selected
    beq !next+
    jmp magic.spell_select
!next:
    ldx data__icon_moves // is 0 when char is first selected
    beq !select_icon+
check_icon_destination:
    cmp #BOARD_EMPTY_SQUARE
    // Note that square will be empty if drop of selected piece source square. We'll check for that later.
    beq !get_destination+
    sta data__challenge_icon
    tay
    lda board.data__piece_icon_offset_list,y
    eor flag__is_light_turn
    and #$08
    beq !return+ // Do nothing if click on occupied square of same color
    lda #FLAG_ENABLE // Valid action
    sta flag__is_destination_valid
    sta private.flag__is_challenge_required
    // Set flag if icon transports instead of moves. Used to determine if should show icon moving between squares or
    // keep the current square selection icon.
    lda data__icon_moves
    and #ICON_CAN_CAST
    asl
    sta private.flag__can_icon_cast
!return:
    rts
!get_destination:
    lda board.data__curr_board_col
    cmp board.data__curr_icon_col
    bne !set_destination+
    lda board.data__curr_board_row
    cmp board.data__curr_icon_row
    bne !set_destination+
    bit data__icon_moves
    bvc !return+ // Don't allow drop on selected piece source square if not a spell caster
    // If spell caster is selected, set spell cast mode if source square selected as destination
    lda #FLAG_ENABLE
    sta magic.idx__selected_spell
    bmi !skip+
!set_destination:
    lda data__icon_moves
    and #ICON_CAN_CAST
    asl
    sta private.flag__can_icon_cast
    bmi !next+
!skip:
    // Add piece to the destination square.
    lda common.param__icon_type_list
    sta (FREEZP),y
!next:
    asl flag__is_destination_valid // Set valid move
!return:
    rts
    //
!select_icon:
    // Ignore if no icon in selected source square
    cmp #BOARD_EMPTY_SQUARE
    beq !return-
    sta common.param__icon_type_list
    // Ignore if selected other player piece.
    tax
    lda board.data__piece_icon_offset_list,x
    eor flag__is_light_turn
    and #$08
    bne !return-
    // Ignore and set error message if selected icon is imprisoned.
    ldx data__player_offset
    lda data__imprisoned_icon_list,x
    cmp common.param__icon_type_list
    beq !next+
    // Accept destination.
    lda #FLAG_ENABLE
    sta flag__is_destination_valid
    ldx magic.idx__selected_spell // Don't clear square if selected a magic caster as they teleport instead of moving
    bmi !return-
    sta (FREEZP),y // Clears current square as piece is now moving
    rts
!next:
    lda #(FLAG_ENABLE+STRING_ICON_IMPRISONED)
    sta flag__is_new_square_selected
    rts

// 88AF
// Returns the icon type (in A) at board row (in Y) and column (in A).
get_square_occupancy:
    pha
    lda board.ptr__board_row_occupancy_lo,y
    sta FREEZP
    lda board.ptr__board_row_occupancy_hi,y
    sta FREEZP+1
    pla
    tay
    lda (FREEZP),y
    rts

// 8953
// Displays an error message on piece selection. The message has $80 added to it and is stored in
// `flag__is_new_square_selected`. This method specifically preserves the X register.
display_message:
    jsr private.clear_last_text_row
    txa
    pha
    ldx #NUM_SCREEN_COLUMNS
    lda flag__is_new_square_selected
    and #$7F
    jsr board.write_text
    pla
    tax
    rts

//---------------------------------------------------------------------------------------------------------------------
// Private functions.
.namespace private {
    // 64EB
    // Regenerate hitpoints for all icons of the current player.
    // - X register is $23 (dark) or $11 (light)
    // Loops through all players icons (backwards) and increases all icon's hitpoints up to the initial hitpoints.
    // This operation is performed when the board color is strongest for the player (ie white for light and black for
    // dark).
    regenerate_hitpoints:
        txa
        sec
        sbc #BOARD_NUM_PLAYER_PIECES
        sta cnt__curr_icon // First player icon (offset by 1)
    !loop:
        lda data__piece_strength_list,x
        beq !next+ // Icon is dead
        ldy board.data__piece_icon_offset_list,x
        cmp data__icon_strength_list,y
        bcs !next+ // Icon is fully healed
        inc data__piece_strength_list,x
    !next:
        dex
        cpx cnt__curr_icon
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
        lda flag__phase_direction_list,y
        bmi !reverse+
        lda data__phase_cycle,y
        cmp #PHASE_CYCLE_LENGTH
        bne !step_count+
        lda #$00 // Reset cycle
        beq !next+
    !step_count:
        clc
        adc #$02
        cpy #$03
        bcc !next+
        cmp #$04
        beq !skip+
        cmp #$0A
        bne !next+
    !skip:
        // Skip 04 and 0A cycle. I suspect the original game had extra board colors as the logic allows red and yellow
        // colors to be used for these cycles.
        clc
        adc #$02
    !next:
        sta data__phase_cycle,y
        cmp #PHASE_CYCLE_LENGTH
        bcc !set_phase+
        lda #FLAG_ENABLE_FF // Reverse phase
        sta flag__phase_direction_list,y
    !set_phase:
        cpy #$03
        bcc !return+
        // Set board color.
        lda data__phase_cycle_board
        lsr
        tay
        lda data__phase_color_list,y
        sta data__phase_color
    !return:
        rts
    !reverse:
        lda data__phase_cycle,y
        bne !step_count+
        lda #PHASE_CYCLE_LENGTH
        bpl !next+
    !step_count:
        sec
        sbc #$02
        cpy #$03
        bcc !next+
        cmp #$04
        beq !skip+
        cmp #$0A
        bne !next+
    !skip:
        // Skip 04 and 0A cycle. I suspect the original game had extra board colors as the logic allows red and yellow
        // colors to be used for these cycles.
        sec
        sbc #$02
    !next:
        sta data__phase_cycle,y
        cmp #$00
        bne !set_phase-
        sta flag__phase_direction_list,y // Reverse phase.
        jmp !set_phase-

    // 66E9
    // Display game over message if last icon is imprisoned.
    // NOTE do not relocate this without jumping to `game_over` method.
    game_over__imprisoned:
        lda #STRING_ICON_IMPRISONED
        ldx #$00
        jsr board.write_text
        // Set winner (opposite to current player as current player has the imprisoned icon).
        lda flag__is_light_turn
        eor #$FF
        sta flag__remaining_player_pieces

    // 66F8
    // Print game over message, play outro music and reset
    // Requires:
    // - `private.flag__remaining_player_pieces` contains the winning side:
    //      $40: light player
    //      $80: dark player
    //      $C0: tie
    //      $01: stalemate
    game_over:
        jsr clear_last_text_row
        lda #STRING_GAME_ENDED
        ldx #NUM_SCREEN_COLUMNS
        jsr board.write_text
        lda private.flag__remaining_player_pieces
        cmp #$01 // Stalemate?
        bne !next+
        lda #STRING_STALEMATE
        jmp !show_winner+
    !next:
        // Determine the winner. This is a little bit counter intuitive. We start with $86 (so high bit is set). The
        // BIT check then increments to $87 if the high bit is set in `private.flag__remaining_player_pieces` (ie winner is dark or tie).
        // The value is incremented again if the value > $80 (tie).
        // The result is then set as the string ID - but the string ID only goes up to $46 (70). This is OK as the
        // write method multiples the ID by 2 (ignoreing overflow), so we get offset 12 (for 86) or 14 or 16 which is
        // string 6 (light wins) and 7 (dark wins) or 8 (tie). Makes sense eventually.
        ldy #$86 // Light wins
        bit private.flag__remaining_player_pieces
        bvs !next+
        iny // Dark wins
        lda private.flag__remaining_player_pieces
        bmi !next+
        iny // Tie
    !next:
        tya
    !show_winner:
        jsr board.write_text
        // Play outro music.
        lda #FLAG_ENABLE
        sta common.param__is_play_outro
        .const index_state__end_intro = $04
        lda #index_state__end_intro
        sta intro.idx__substate_fn_ptr
        sei
        lda #<outro_interrupt_handler
        sta main.ptr__raster_interrupt_fn
        lda #>outro_interrupt_handler
        sta main.ptr__raster_interrupt_fn+1
        lda #<outro_interrupt_handler__play_music
        sta ptr__play_music_fn
        lda #>outro_interrupt_handler__play_music
        sta ptr__play_music_fn+1
        cli
        jsr common.initialize_music
        // Wait for about 30 seconds before restarting the game
        jsr common.wait_for_key_or_task_completion
        lda TIME+1
        sta data__curr_time
        lda board.cnt__countdown_timer
        beq !loop+
        lda #$07 // Approx 30s (each tick is ~4s)
        sta board.cnt__countdown_timer
        lda #FLAG_ENABLE // Intro
        sta common.flag__game_loop_state
    !loop:
        jsr common.check_option_keypress
        lda common.flag__game_loop_state
        beq !next+
        lda TIME+1
        cmp data__curr_time
        beq !next+
        sta data__curr_time
        dec board.cnt__countdown_timer
        bpl !next+
        lda #FLAG_DISABLE
        sta common.flag__game_loop_state
        jmp main.game_state_loop
    !next:
        jmp !loop-

    // 861E
    set_square_right:
        lda board.data__curr_board_col
        bmi !next+
        cmp #$08 // Already on last column?
        bcs !return+
        tay
        iny
        sty cnt__board_col
        lda board.data__curr_board_row
        sta cnt__board_row
        lda #$00 // Stating animation frame 0
        sta private.idx__start_icon_frame
        jsr verify_valid_move
    !next:
        lda #$0C // Move 12 pixels to the right
        sta private.cnt__sprite_x
        inc board.data__curr_board_col
        inc flag__is_new_square_selected
    !return:
        rts

    // 8646
    set_square_left:
        lda board.data__curr_board_col
        bmi !return+
        beq !return+ // Already on first column?
        tay
        dey
        sty cnt__board_col
        lda board.data__curr_board_row
        sta cnt__board_row
        lda #$11 // Left facing icon
        sta private.idx__start_icon_frame
        jsr verify_valid_move
        lda #$8C // Move 12 pixels to the left
        sta private.cnt__sprite_x
        dec board.data__curr_board_col
        inc flag__is_new_square_selected
    !return:
        rts

    // 866C
    set_square_up:
        lda board.data__curr_board_row
        beq !return+ // Already on first row?
        tay
        dey
        sty cnt__board_row
        lda board.data__curr_board_col
        sta cnt__board_col
        lda flag__is_new_square_selected
        cmp #$01
        beq !next+ // Pefer left/right facing when moving diagonally
        lda #$08  // Stating animation frame 8
        sta private.idx__start_icon_frame
    !next:
        jsr verify_valid_move
        lda #$90 // Move 16 pixels up
        sta private.cnt__sprite_y
        dec board.data__curr_board_row
        lda #$01
        sta flag__is_new_square_selected
    !return:
        rts

    // 8699
    set_square_down:
        lda board.data__curr_board_row
        cmp #$08 // Already on last row?
        bcs !return+
        tay
        iny
        sty cnt__board_row
        lda board.data__curr_board_col
        sta cnt__board_col
        lda flag__is_new_square_selected
        cmp #$01
        beq !next+ // Pefer left/right facing when moving diagonally
        lda #$04 // Start animation frame 4
        sta private.idx__start_icon_frame
    !next:
        jsr verify_valid_move
        lda #$10 // Move down 16 pixels
        sta private.cnt__sprite_y
        inc board.data__curr_board_row
        lda #$01
        sta flag__is_new_square_selected
    !return:
        rts

    // 86C8
    // This method keeps track of movement and ensures an icon can only move a certain number of squares and reports
    // errors if the icon cannot move, the square is occupied or the square requires a challenge.
    // Little bit naughty here - many of the subroutines include 4 PLAs before the RTS if the square cannot be
    // selected. The effect of this is to pull the return address for the subroutine and this subroutine from the stack
    // and therefore the RTS will return from the calling subroutine. The calling subroutine calls this sub just before
    // adding to the X or Y movement counters, so this stops the icon or square from moving.
    // Requires:
    // - Selected square column must be stored in `cnt__board_col`
    // - Selected square row must be stored in `cnt__board_row`
    // - Current number of moves held in `private.cnt__moves`
    // - Total number of moves held in `data__icon_moves`
    // - Path of previous moves stored in `private.data__move_col_list` and `private.data__move_row_list`
    verify_valid_move:
        lda data__icon_moves
        beq !return+
        bmi !check_limit+ // Can fly? Skip occupied square check on move.
        // Reduce move counter if piece moved back to same square as last move.
        ldy private.cnt__moves
        beq !next+
        dey
        lda private.data__move_col_list,y
        cmp cnt__board_col
        bne !next+
        lda private.data__move_row_list,y
        cmp cnt__board_row
        bne !next+
        dec private.cnt__moves
        rts
    !next:
        jsr warn_on_challenge
        jsr warn_on_move_limit_reached
        jsr warn_on_occupied_square
        // Store the move so that we can check the move path to calculate the total number of moves.
        inc private.cnt__moves
        ldy private.cnt__moves
        lda cnt__board_row
        sta private.data__move_row_list,y
        lda cnt__board_col
        sta private.data__move_col_list,y
        rts
    !check_limit:
        cmp #$8F // Skip move limit check (eg when a piece is transported)
        beq !return+
        jsr warn_on_diagonal_move_exceeded
    !return:
        rts

    // 88Bf
    // Challenge warning is only shown if try to move off a square occupied by the other player. The player must either
    // challenge or move to the previous square they were in to continue moving.
    warn_on_challenge:
        ldy board.data__curr_board_row
        lda board.data__curr_board_col
        jsr get_square_occupancy
        cmp #BOARD_EMPTY_SQUARE
        beq !return+
        tay
        lda board.data__piece_icon_offset_list,y
        eor flag__is_light_turn
        and #$08
        beq !return+
        lda #(FLAG_ENABLE+STRING_CHALLENGE_FOE)
        sta flag__is_new_square_selected
        pla // Abort move
        pla
        pla
        pla
    !return:
        rts

    // 88E1
    // Detect if the destination square is already occupied by an icon for the same player. Abort the move it is is.
    warn_on_occupied_square:
        ldy cnt__board_row
        lda cnt__board_col
        jsr get_square_occupancy
        cmp #BOARD_EMPTY_SQUARE
        beq !return+
        tay
        lda board.data__piece_icon_offset_list,y
        eor flag__is_light_turn
        and #$08
        bne !return+
        lda #(FLAG_ENABLE+STRING_SQUARE_OCCUPIED)
        sta flag__is_new_square_selected
        pla // Abort move
        pla
        pla
        pla
    !return:
        rts

    // 8903
    // Calculate if diagonal move limit exceeded.
    warn_on_diagonal_move_exceeded:
        lda cnt__board_col
        sec
        sbc board.data__curr_icon_col
        bcs !next+
        eor #$FF
        adc #$01
    !next:
        sta data__curr_board_col
        lda cnt__board_row
        sec
        sbc board.data__curr_icon_row
        bcs !next+
        eor #$FF
        adc #$01
    !next:
        sta data__curr_board_row
        //
        lda data__icon_moves
        and #$3F
        cmp data__curr_board_col
        bcc show_limit_reached_message
        cmp data__curr_board_row
        bcs !return+
    show_limit_reached_message:
        lda #(FLAG_ENABLE+STRING_LIMIT_MOVED)
        sta flag__is_new_square_selected
        pla // Abort move
        pla
        pla
        pla
    !return:
        rts

    // 893C
    // Incremenet the move counter and display the limit reached warning if the player has no more moves left.
    warn_on_move_limit_reached:
        ldy private.cnt__moves
        iny
        cpy data__icon_moves
        bcc !return-
        bne show_limit_reached_message
        rts

    // 8948
    // Clear the last text row under the board. Leave's the first text row untouched.
    // Sets:
    // - Clears graphical character memory for row 24 (0 offset).
    // Notes:
    // - Does not clear color memory.
    clear_last_text_row:
        ldy #(NUM_SCREEN_COLUMNS-1) // 0 offset
        lda #$00
    !loop:
        sta SCNMEM+(NUM_SCREEN_ROWS-1)*NUM_SCREEN_COLUMNS,y
        dey
        bpl !loop-
        rts

    // 897B
    // transport piece
    transport_icon:
        ldx #$00
        stx cnt__interrupts
        // Enable 2 sprites for animating transport from and to - the source sprite is slowly removed from the source
        // location and rebuilt at the destination location. This is done by removing one line from the source (every 3
        // interrupts) and adding it to the destination.
        lda #EMPTY_SPRITE_BLOCK
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
        lda #(BYTERS_PER_ICON_SPRITE-1) // 0 offset
        sta idx__sprite_shape_source_row
        lda board.data__curr_icon_col
        ldy board.data__curr_icon_row
        jsr board.convert_coord_sprite_pos
        ldy common.param__icon_type_list
        lda board.data__piece_icon_offset_list,y
        sta common.param__icon_offset_list
        jsr common.initialize_sprite
        //
        lda common.ptr__sprite_00_mem
        sta FREEZP+2
        lda common.ptr__sprite_00_mem+1
        sta FREEZP+3
        lda #BYTERS_PER_ICON_SPRITE
        sta common.param__sprite_source_len
        lda common.param__icon_sprite_source_frame_list
        beq !next+
        lda #FLAG_ENABLE // Invert sprite
    !next:
        sta common.param__icon_sprite_curr_frame
        jsr common.add_sprite_to_graphics
        //
        ldx #$01
        lda #$00
    !loop:
        sta common.param__icon_sprite_source_frame_list,x
        sta board.cnt__sprite_frame_list,x
        dex
        bpl !loop-
        //
        tax
        jsr board.set_icon_sprite_location
        jsr board.draw_board
        // Configure destination icon.
        ldx #$01
        lda board.data__curr_board_col
        ldy board.data__curr_board_row
        jsr board.convert_coord_sprite_pos
        jsr board.set_icon_sprite_location
        // Configure transport sound effect.
        lda #FLAG_ENABLE
        sta common.flag__is_player_sound_enabled
        ldx #$00
        stx common.data__voice_note_delay
        //
        lda #<resources.snd__effect_transport
        sta OLDTXT
        lda #>resources.snd__effect_transport
        sta OLDTXT+1
        lda resources.snd__effect_transport+5 // This note increases in patch as animation runs
        sta data__transport_effect_pitch
        jsr board.play_icon_sound
        // Configure sprite source and destination pointers (for line by line copy)
        lda common.ptr__sprite_00_mem
        sta FREEZP
        lda common.ptr__sprite_00_mem+1
        sta FREEZP+1
        lda common.ptr__sprite_24_mem
        sta FREEZP+2
        lda common.ptr__sprite_24_mem+1
        sta FREEZP+3
        // Set interrupt handler for transport animation.
        sei
        lda #<transport_icon_interrupt
        sta main.ptr__raster_interrupt_fn
        lda #>transport_icon_interrupt
        sta main.ptr__raster_interrupt_fn+1
        cli
        // Wait for animation to completee.
        jsr wait_for_state_change
        lda #EMPTY_SPRITE_BLOCK
        sta SPTMEM
        rts

    // 8A37
    // Performs an animation when transporting an icon from one location to another.
    transport_icon_interrupt:
        jsr board.draw_magic_square
        lda common.flag__cancel_interrupt_state
        bmi !return+
        // Animate every 4th
        inc cnt__interrupts
        lda cnt__interrupts
        and #$03
        beq !next+
    !return:
        jmp common.complete_interrupt
    !next:
        // Play sound.
        lda #$00
        sta VCREG1
        lda data__transport_effect_pitch
        clc
        adc #$02
        sta data__transport_effect_pitch
        sta FREHI1
        lda #$11
        sta VCREG1
        // Copy 2 lines of the source sprite and move to destination sprite.
        ldy idx__sprite_shape_source_row
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
        sty idx__sprite_shape_source_row
        jmp common.complete_interrupt
    !return:
        lda private.flag__is_challenge_required
        bmi !next+
        jsr board.add_icon_to_matrix
    !next:
        lda #FLAG_ENABLE
        sta common.flag__cancel_interrupt_state
        jmp common.complete_interrupt

    // 91FB
    // Creates sprites in 56 and 57 from character dot data (creates "ARCHON"), position the sprites above the board,
    // set the sprite color to current player color and enable as sprite 2 and 3.
    create_title:
        lda common.ptr__sprite_56_mem
        sta FREEZP+2 // Sprite location
        sta data__temp_storage
        sta data__temp_storage+1
        lda common.ptr__sprite_56_mem+1
        sta FREEZP+3
        lda #$03 // Number of letters per sprite
        sta data__temp_storage+2
        ldx #$00
    !char_loop:
        lda txt__game_name,x // Get title letter
        // Convert character to dot data offset.
        and #$3F
        asl
        asl
        asl
        sta FREEZP // Character dot data offset
        .const UPPERCASE_OFFSET = $600
        lda #>(CHRMEM2+UPPERCASE_OFFSET)
        adc #$00
        sta FREEZP+1
        ldy #$00
    !loop:
        lda (FREEZP),y
        sta (FREEZP+2),y
        iny
        inc FREEZP+2
        inc FREEZP+2
        cpy #$08
        bcc !loop-
        // Set next letter.
        inc data__temp_storage
        lda data__temp_storage
        sta FREEZP+2
        dec data__temp_storage+2
        bne !next+
        // Sprite full - Move to next sprite.
        lda #$03
        sta data__temp_storage+2
        lda data__temp_storage+1
        clc
        adc #BYTES_PER_SPRITE
        sta FREEZP+2
        sta data__temp_storage
        bne !next+
        inc FREEZP+3
    !next:
        inx
        cpx #$06 // Title has 6 letters (ARCHON)
        bcc !char_loop-
        // Configure and enable sprites.
        lda #$38 // Place above board (positions hard coded)
        sta SP2Y
        sta SP3Y
        lda #$84
        sta SP2X
        lda #$B4
        sta SP3X
        lda #((VICGOFF/BYTES_PER_SPRITE)+56) // Should use common.ptr__sprite_56_offset but source doesn't :(
        sta SPTMEM+2
        lda #((VICGOFF/BYTES_PER_SPRITE)+57)
        sta SPTMEM+3
        rts

    // 92EB
    create_selection_square:
        lda common.ptr__sprite_24_mem
        sta FREEZP+2 // Sprite location
        lda common.ptr__sprite_24_mem+1
        sta FREEZP+3
        ldy #$00
        jsr selection_square__vert_line
        // Draw sides.
        ldx #$10 // 16 pixels high
    !loop:
        lda #$C0 // Hard coded sprite dot data
        sta (FREEZP+2),y
        iny
        lda #$18 // Hard coded sprite dot data
        sta (FREEZP+2),y
        iny
        iny
        dex
        bne !loop-
        jsr selection_square__vert_line
        rts

    // 930E
    // Draw top/bottom.
    selection_square__vert_line:
        ldx #$02
    !loop:
        lda #$FF // Hard coded sprite dot data
        sta (FREEZP+2),y
        iny
        lda #$F8 // Hard coded sprite dot data
        sta (FREEZP+2),y
        iny
        iny
        dex
        bne !loop-
        rts

    // AE12
    outro_interrupt_handler:
        jsr board.draw_magic_square
        lda common.flag__cancel_interrupt_state
        bmi !return+
        jmp (ptr__play_music_fn)
    outro_interrupt_handler__play_music:
        jsr common.play_music
    !return:
        jmp common.complete_interrupt
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// 8AB3
// Initial strength of each icon type. Uses icon offset as index. Eg Knight has an offset of 7 and therefore the
// initial strength of a knight is $05.
data__icon_strength_list:
    //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
    .byte 09, 10, 05, 15, 08, 15, 12, 05, 06, 10, 08, 14, 10, 17, 08, 05, 12, 10, 17, 14

// 8B77
// Index of magic squares within the square occupancy array.
data__magic_square_offset_list: .byte $04, $24, $28, $2C, $4C

// 8BD2
// Colors used for each board game phase.
data__phase_color_list: .byte BLACK, BLUE, RED, PURPLE, GREEN, YELLOW, CYAN, WHITE

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 8AC7
    // Number of moves of each icon type. Uses icon offset as index. Add +$40 if icon can cast spells. Add +$80 if
    // icon can fly.
    data__icon_num_moves_list:
        //    UC, WZ,                            AR, GM, VK,              DJ,              PH,              KN
        .byte 04, 03+ICON_CAN_FLY+ICON_CAN_CAST, 03, 03, 03+ICON_CAN_FLY, 04+ICON_CAN_FLY, 05+ICON_CAN_FLY, 03
        //    BK, SR,                            MC, TL, SS,              DG,              BS,              GB
        .byte 03, 03+ICON_CAN_FLY+ICON_CAN_CAST, 03, 03, 05+ICON_CAN_FLY, 04+ICON_CAN_FLY, 03+ICON_CAN_FLY, 03

    // 9274
    // Logo string that is converted to a sprite using character set dot data as sprite source data.
    txt__game_name: .text "ARCHON"

    // 95f4
    // Provised pointers to the sounds that may be made during game play.
    ptr__sound_game_effect_list:
        .word resources.snd__effect_hit_player_light   // 00
        .word resources.snd__effect_hit_player_dark    // 02
        .word resources.snd__effect_player_light_turn  // 04
        .word resources.snd__effect_player_dark_turn   // 06
}

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC0
// Is positive (55) for AI light, negative (AA) for AI dark, (00) for neither, (FF) or both.
data__ai_player_ctl: .byte $00

// BCC2
// Is positive (55) for light, negative (AA) for dark.
data__curr_player_color: .byte $00

// BCC6
// Is positive for light, negative for dark.
flag__is_light_turn: .byte $00

// BCC7
// Represents the direction of specific phases within the
flag__phase_direction_list:
    .byte $00
    .byte $00
    .byte $00
// Color phase direction (<$80: light to dark; >=$80: dark to light).
flag__is_phase_towards_dark:
    .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Private data.
.namespace private {
    // BCD2
    // Is positive if player turn has just started.
    flag__is_turn_started: .byte $00
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCDE
// Is 0 for player 1 and 1 for player 2. Used mostly as a memory offset index.
data__player_offset: .byte $00

// BCFD
// Selected icon total number moves (+$40 if can cast spells, +$80 if can fly).
data__icon_moves: .byte $00

// BD00
// Type of selected icon to challenge for the destination square.
data__challenge_icon: .byte $00

// BD09
// Delay between movement for selected icon. Is only delayed for Golem and Troll.
data__icon_speed: .byte $00, $00

// BD11
// Current board color phase (colors phase between light and dark as time progresses).
data__phase_color: .byte $00

// BD24
// Imprisoned icon ID for each player (offset 0 for light, 1 for dark).
data__imprisoned_icon_list: .byte $00, $00

// BD3D
// Is set to non-zero if a new board square was selected.
flag__is_new_square_selected: .byte $00

// BD55
// Interrrupt response saved after interrupt was completed.
data__last_interrupt_response_flag: .byte $00

// BD70
// Countdown of moves left until stalemate occurs (0 for disabled).
cnt__stalemate_moves: .byte $00

// BDFD
// Current strength of each board icon.
data__piece_strength_list: .fill BOARD_TOTAL_NUM_PIECES, $00

// BCFE
// Is set if the selected square is a valid selection.
flag__is_destination_valid: .byte $00

// BD26
// Sprite selection flag. Is used to determine if moving selection square ($01) or selected icon ($00).
flag__is_moving_icon: .byte $00

// BD27
// Last recorded major jiffy clock counter (256 jiffy counter).
data__curr_time: .byte $00

// BF3D
// State cycle counters (counts up and down using numbers 0, 2, 6, 8, C and E).
data__phase_cycle:
    .byte $00
    .byte $00
    .byte $00
// Color phase direction (<$80: light to dark; >=$80: dark to light).
data__phase_cycle_board:
    .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BCEB
    // Icon direction initial sprite frame offset.
    idx__start_icon_frame: .byte $00

    // BCED
    // Toggles after each play so is high after both players had completed thier turn.
    flag__is_round_complete: .byte $00

    // BCF3
    // Delay before start of each turn can commence. This stops accidental movement or piece selection at the immediate
    // start of the turn.
    cnt__turn_delay: .byte $00

    // BCFC
    // An icon is currently selected for movemement.
    flag__is_icon_selected: .byte $00

    // BCFF
    // Is enabled if the icon must challenge for the destination square.
    flag__is_challenge_required: .byte $00

    // BD0F
    // Is $80 if the selected icon can cast spells. Used to determine if icon transports or moves.
    flag__can_icon_cast: .byte $00

    // BD30
    // Points to the music playing function for playing the outro music during an interrupt.
    ptr__play_music_fn: .word $0000

    // BCEE
    // Counter used to advance animation frame (every 4 pixels).
    idx__icon_frame: .byte $00

    // BCEE
    // Count number of interrupts. Used to perform actions on the nth interrupt.
    cnt__interrupts: .byte $00

    // BCF2
    // Current debounce counter (used when debouncing fire button presses).
    cnt__joystick_debounce: .byte $00

    // BCFE
    // Holds a value indicating which player pieces are on the board. Is $40 if only light pieces, $80 if only dark
    // pieces and $C0 if both light and dark pieces remain.
    flag__remaining_player_pieces: .byte $00

    // BD0D
    // Is non-zero if the board sprite was moved (in X or Y direction ) since last interrupt
    flag__was_sprite_moved: .byte $00

    // BD2D
    // Sprite byte counter used to copy sprite line by line when transporting an icon
    idx__sprite_shape_source_row: .byte $00

    // BD68
    // Temporary storage for musical note being played.
    data__transport_effect_pitch: .byte $00

    // BEA1
    // Selected icon number of moves made in current turn.
    cnt__moves: .byte $00

    // BEA2
    // Stores each column the icon enters as it is being moved. Used to calculate number of moves.
    // Allows for a total of 5 moves (maximum move count) plus the starting column.
    data__move_col_list: .byte $00, $00, $00, $00, $00, $00

    // BEA8
    // Stores each row the icon enters as it is being moved. Used to calculate number of moves.
    // Allows for a total of 5 moves (maximum move count) plus the starting row.
    data__move_row_list: .byte $00, $00, $00, $00, $00, $00

    // BF1A
    // Icon loop counter.
    cnt__curr_icon: .byte $00

    // BF1A
    // Temporary data storage area used for creating the icon logo sprite.
    data__temp_storage: .byte $00, $00, $00

    // BF20
    // Temporary storage used to store calculated column for diagonal move exceeded determination.
    data__curr_board_col: .byte $00

    // BF21
    // Temporary storage used to store calculated row for diagonal move exceeded determination.
    data__curr_board_row: .byte $00

    // BF30
    // Current board row.
    cnt__board_row: .byte $00

    // BF31
    // Current board column.
    cnt__board_col: .byte $00

    // BF32
    // Dark remaining icon count.
    cnt__dark_icons: .byte $00

    // BF32
    // Sprite Y position movement counter.
    cnt__sprite_y: .byte $00

    // BF33
    // Icon ID of last dark icon.
    data__last_dark_icon: .byte $00

    // BF36
    // Light remaining icon count.
    cnt__light_icons: .byte $00

    // BF36
    // Sprite X position movement counter.
    cnt__sprite_x: .byte $00

    // BF37
    // Icon ID of last light icon.
    data__last_light_icon_id: .byte $00
}
