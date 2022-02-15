.filenamespace magic
//---------------------------------------------------------------------------------------------------------------------
// Contains routines for selecting and casting spells within the game.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 67B4
select_spell:
    // Store current piece location to restore location if the spell is aborted.
    lda board.data__curr_icon_row
    sta temp_row_store
    lda board.data__curr_icon_col
    sta temp_column_store
    lda game.state.flag__ai_player_ctl
    cmp game.state.flag__is_light_turn
    bne select_spell_start
    jmp ai.magic_select_spell
select_spell_start:
    // Configure player.
    ldy #$00
    lda game.state.flag__is_light_turn
    bpl !next+
    iny
!next:
    sty game.curr_player_offset
    cpy #$00
    beq !next+
    ldy #$07
!next:
    // End spell selection if no spells left.
    jsr count_used_spells
    lda data__used_spell_count
    cmp #$07 // All spells used?
    bcc !next+
    lda #STRING_NO_SPELLS
    beq cancel_spell_selection
!next:
    jsr config_used_spell_ptr
    jsr board.clear_text_area
    lda #STRING_SELECT_SPELL
    ldx #$0A
    jsr board.write_text
    // Get spell selection.
    jsr get_selected_spell
    sty data__curr_spell_id
    jsr board.clear_text_area
    ldy data__curr_spell_id
    lda data.spell_string_id,y
    ldx #$0A
    jsr board.write_text
    ldy data__curr_spell_id
    cpy #SPELL_ID_CEASE
    beq !next+
    lda #SPELL_USED
    sta (CURLIN),y
!next:
    // Cast spell.
    tya
    asl
    tay
    lda data.spell_cast_fn_ptr,y
    sta prt__spell_fn
    lda data.spell_cast_fn_ptr+1,y
    sta prt__spell_fn+1
    jmp (prt__spell_fn)
    //
cancel_spell_selection:
    jsr end_spell_selection
    jsr board.clear_text_area
    pla // End turn
    pla
    jmp game.play_turn

// 6833
// Description:
// - Configures a pointer to the start of the used spell array for the current player.
// Prerequisites:
// - `game.curr_player_offset`: Current player (0 for light, 1 for dark).
// Sets:
// - `CURLIN`: Pointer to spell used array (one byte for each spell type). See `flag__light_used_spells` for order
//   of bytes.
// Preserves:
// - X
config_used_spell_ptr:
    lda game.curr_player_offset
    asl
    tay
    lda data.used_spell_ptr,y
    sta CURLIN
    lda data.used_spell_ptr+1,y
    sta CURLIN+1
    rts

// 6843
spell_select_teleport:
    lda #STRING_TELEPORT_WHICH
    sta game.message_id
    jsr game.display_message
    lda #$00 // Immediately return after selection (ie don't allow selected icon to be moved)
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_FREE_PLAYER_ICON
    jsr spell_select_destination
    //
    lda game.state.flag__ai_player_ctl
    cmp game.state.flag__is_light_turn
    bne !next+
    // 685D  AD 6E BE   lda WBE6E // TODO
    // 6860  8D 51 BD   sta WBD51
    // 6863  AD 5C BE   lda WBE5C
    // 6866  8D 50 BD   sta WBD50
    // 6869  20 A1 7A   jsr W7AA1
    jmp skip_teleport_message
!next:
    lda #STRING_TELEPORT_WHERE
    sta game.message_id
    jsr game.display_message
skip_teleport_message:
    ldy board.data__curr_board_row
    sty board.data__curr_icon_row
    lda board.data__curr_board_col
    sta board.data__curr_icon_col
    lda #(ICON_CAN_FLY+ICON_CAN_CAST+$0F) // Allow selected icon to move anywhere usin the teleport animation
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_SQUARE
    jsr spell_select_destination
    //
    ldx #BOARD_EMPTY_SQUARE
    ldy board.data__curr_icon_row
    lda board.data__curr_icon_col
    jsr set_occupied_square
    rts

// 6899
spell_select_heal:
    lda #STRING_HEAL_WHICH
    sta game.message_id
    jsr game.display_message
    lda #$00 // Immediately return after selection (ie don't allow selected icon to be moved)
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_PLAYER_ICON
    jsr spell_select_destination
    ldx common.icon.type
    ldy board.icon.init_matrix,x
    lda game.icon.init_strength,y
    sta game.curr_icon_strength,x
    lda #STRING_SPELL_DONE

// 68B9
end_spell_selection:
    sta game.message_id
    jsr game.display_message
    ldx #$80 // ~2 sec
    jsr common.wait_for_jiffy
    rts

// 68C5
spell_select_shift_time:
    lda game.flag__phase_direction_board
    eor #$FF
    sta game.flag__phase_direction_board
    lda #STRING_REVERED_TIME
    bpl end_spell_selection

// 68D1
spell_select_exchange:
    lda #STRING_TRANSPOSE_WHICH
    sta game.message_id
    jsr game.display_message
    lda #$FF // Clear selected icon
    sta common.icon.type
    lda #$00
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_ICON
    jsr spell_select_destination
    //
    lda board.data__curr_board_row
    sta board.data__curr_icon_row
    lda board.data__curr_board_col
    sta board.data__curr_icon_col
    lda common.icon.type
    sta temp_selected_icon_store // First selected icon
    lda #STRING_EXCHANGE_WHICH
    sta game.message_id
    jsr game.display_message
    lda #ACTION_SELECT_ICON
    jsr spell_select_destination
    //
    jsr board.clear_text_area
    // Swap icons.
    ldx #BOARD_EMPTY_SQUARE
    ldy board.data__curr_board_row
    lda board.data__curr_board_col
    jsr set_occupied_square
    lda board.data__curr_icon_col
    ldy board.data__curr_icon_row
    jsr set_occupied_square
    jsr board.draw_board
    ldx #$30 // ~0.75 seconds
    jsr common.wait_for_jiffy
    ldx common.icon.type
    ldy board.data__curr_icon_row
    lda board.data__curr_icon_col
    jsr set_occupied_square
    ldx temp_selected_icon_store
    ldy board.data__curr_board_row
    lda board.data__curr_board_col
    jsr set_occupied_square
    rts

// 6AFE
spell_select_elemental:
    // Check if there are any enemy icons located on non-magic squares. If not, the spell will be wasted and an alert
    // shown. The check is a bit rough - it starts at occupancy location 80 ($50) which is the last square on the board
    // (0 offset) and works backwards. An array of magic square locations is stored in
    // `game.data.magic_sqaure_occupancy_index`. If the counter is decremented to the magic square location, the next
    // magic square is stored and the occupancy check is skipped. This repeats until all squares have been checked.
    // The loop exits as soon as an enemy piece is detected. If we check all squares (with magic sqaures skipped) and
    // no enemey piece is found, then we show a spell wasted message.
    ldx #(BOARD_SIZE-1)
    ldy #$04 // Number magic sqaures (0 offset)
    lda game.data.magic_sqaure_occupancy_index+4
    sta temp__data_store
!loop:
    cpx temp__data_store // Up to next magic square?
    bne !next+
    dey
    bmi check_next_square // No more magic squares
    // Store next magic square location.
    lda game.data.magic_sqaure_occupancy_index,y
    sta temp__data_store
    jmp check_next_square
!next:
    // Check if square has opposing player icon
    lda board.curr_square_occupancy,x
    bmi check_next_square // No icon
    cmp #MANTICORE // First dark player icon id
    php
    lda game.state.flag__is_light_turn
    bpl !next+
    plp
    bcc allow_summon_elemental
    bcs check_next_square
!next:
    plp
    bcs allow_summon_elemental
check_next_square:
    dex
    bpl !loop-
    // All opposing icons on charmed squares. Spell wasted. Display warning message.
    lda #STRING_CHARMED_PROOF
    ldx #CHARS_PER_SCREEN_ROW
    jsr board.write_text
    jmp spell_complete
    //
allow_summon_elemental:
    // Set elemental starting position.
    lda #$FE // 2 columns to the left of board for light player
    ldx game.curr_player_offset
    beq !next+
    lda #$0A // Or 2 columns to the right of board for dark player
!next:
    sta board.data__curr_board_col
    lda #$04 // Middle row
    sta board.data__curr_board_row
!loop:
    // Create random elemental type.
    lda RANDOM
    and #$03 // 0-3 random number (choose one of 4 elementals)
    cmp data__used_elemental_id // Ensures both players generate a different elemental
    beq !loop-
    sta data__used_elemental_id
    pha
    clc
    adc #AIR_ELEMENTAL // Elemental ID
    tax
    stx common.icon.type
    ldy board.icon.init_matrix,x
    sty common.icon.offset
    lda game.icon.init_strength,y
    sta game.curr_icon_strength,x
    // Display elemental type.
    jsr board.clear_text_area
    pla
    clc
    adc #STRING_AIR
    ldx #$00
    stx SP1Y
    jsr board.write_text
    lda #STRING_ELEMENT_APPEARS
    jsr board.write_text
    // Configure sprite and sound.
    ldx #$00
    stx game.flag__selected_sprite
    jsr board.get_sound_for_icon
    lda board.data__curr_board_col
    ldy board.data__curr_board_row
    jsr board.convert_coord_sprite_pos
    jsr common.sprite_initialize
    lda #BYTERS_PER_STORED_SPRITE
    sta common.sprite.copy_length
    jsr common.add_sprite_set_to_graphics
    lda game.curr_player_offset
    beq !next+
    lda #$11 // Left facing icon
!next:
    sta common.sprite.init_animation_frame
    jsr board.render_sprite
    //
    lda game.state.flag__ai_player_ctl
    cmp game.state.flag__is_light_turn
    beq !next+
    lda #STRING_SEND_WHERE
    sta game.message_id
    sta temp_message_id_store
    jsr game.display_message
!next:
    lda common.icon.offset
    cmp #EARTH_ELEMENTAL_OFFSET
    bne !next+
    lda #$40 // Slow down animation speed for earth elemental
    sta game.curr_icon_move_speed
!next:
    lda #(ICON_CAN_FLY+$0F)
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_CHALLENGE_ICON
    jsr spell_select_destination
    rts

// 693F
spell_select_revive:
    jsr game.check_empty_non_magic_surrounding_square
    lda game.flag__is_valid_square
    bmi !next+
    // No empty non-magical squares surrounding the spell caster.
    lda #STRING_NO_CHARMED
revive_error:
    ldx #$00
    jsr board.write_text
    jmp spell_complete
!next:
    ldx #$00
    stx data__number_dead_icons
    cpx game.curr_player_offset
    beq !next+
    ldx #BOARD_NUM_PLAYER_ICONS // Set offset for player icon strength and type (0=light, 18=dark)
!next:
    // Clear dead icon list.
    ldy #$07 // Maximum 8 (zero offset) icon types
    lda #DEAD_ICON_SLOT_UNUSED
!loop:
    sta curr_dead_icon_offsets,y
    dey
    bpl !loop-
    // Populate dead icon list.
    lda #BOARD_NUM_PLAYER_ICONS
    sta temp__data_store
!loop:
    lda game.curr_icon_strength,x
    bne !next+
    lda board.icon.init_matrix,x
    // Check if icon type is already in the list (eg 2 of the same type may have been killed).
    ldy data__number_dead_icons
check_dead_type_loop:
    cmp curr_dead_icon_offsets,y
    beq !next+
    dey
    bpl check_dead_type_loop
    // Store the dead icon in the list.
    ldy data__number_dead_icons
    sta curr_dead_icon_offsets,y
    txa
    sta curr_dead_icon_types,y
    iny
    sty data__number_dead_icons
    cpy #$08 // Dead icon list full?
    beq !next++
!next:
    inx
    dec temp__data_store
    bne !loop-
!next:
    lda data__number_dead_icons
    bne !next+
    // Display error if no icons have been killed.
    lda #STRING_ICONS_ALL_ALIVE
    jmp revive_error
    //
!next:
    // Set screen and color memory pointers for displaying the dead icon list.
    lda #(CHARS_PER_SCREEN_ROW*3)
    ldy game.state.flag__is_light_turn
    bpl !next+
    lda #(CHARS_PER_SCREEN_ROW*3+CHARS_PER_SCREEN_ROW-4)
!next:
    sta FREEZP+2 // Screen memory pointer
    sta VARPNT // Color memory pointer
    sta dead_icon_screen_offset
    lda #>SCNMEM
    sta FREEZP+3
    lda #>COLRAM
    sta VARPNT+1
    // Display the dead icons.
    lda #$00
    sta data__dead_icon_index
!loop:
    ldy data__dead_icon_index
    lda curr_dead_icon_offsets,y
    pha
    asl
    asl
    sta temp__data_store
    pla
    asl
    clc
    adc temp__data_store
    sta temp__data_store
    jsr display_dead_icon
    inc data__dead_icon_index
    lda data__dead_icon_index
    cmp data__number_dead_icons
    bcc !loop-
    // Calculate starting position and display the selection square.
    lda #$FE // 2 columns to the left of board for light player
    ldx game.curr_player_offset
    beq !next+
    lda #$0A // Or 2 columns to the right of board for dark player
!next:
    sta board.data__curr_board_col
    ldy #$08
    sty board.data__curr_board_row
    ldx #$04
    jsr board.convert_coord_sprite_pos
    sec
    sbc #$02
    sta common.sprite.curr_x_pos+1
    tya
    sec
    sbc #$01
    sta common.sprite.curr_y_pos+1
    jsr board.render_sprite
    // Allow user to select a dead icon.
    lda #STRING_REVIVE_WHICH
    sta game.message_id
    jsr game.display_message
    lda #$00
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_REVIVE_ICON
    jsr spell_select_destination
    // Display selected icon sprite and allow user to select the destination.
    lda board.data__curr_board_col
    ldy board.data__curr_board_row
    ldx #$00
    jsr board.convert_coord_sprite_pos
    ldy board.data__curr_board_row
    lda curr_dead_icon_offsets,y
    sta common.icon.offset
    lda curr_dead_icon_types,y
    sta common.icon.type
    tax
    lda #STRING_CHARMED_WHERE
    sta game.message_id
    sta temp_message_id_store
    jsr game.display_message
    ldy common.icon.offset
    lda game.icon.init_strength,y
    sta game.curr_icon_strength,x // Restore icon health
    ldx #$00
    stx game.flag__selected_sprite
    jsr board.get_sound_for_icon
    jsr common.sprite_initialize
    jsr common.add_sprite_set_to_graphics
    jsr board.render_sprite
    jsr clear_dead_icons_from_screen
    lda #(ICON_CAN_FLY+$0F)
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_CHARMED_SQUARE
    jsr spell_select_destination
    rts

// 6A67
// Draw an icon piece on the screen uisng character dot data. A pice is 3 characters wide and 2 characters high.
display_dead_icon:
    lda #$02 // 2 rows high
    sta data__curr_count
!loop:
    ldy #$00
    ldx #$03 // 3 characters wide
!loop:
    lda temp__data_store
    sta (FREEZP+2),y
    lda (VARPNT),y
    ora #$08 // Derive color
    sta (VARPNT),y
    iny
    inc temp__data_store
    dex
    bne !loop-
    lda FREEZP+2
    clc
    adc #CHARS_PER_SCREEN_ROW
    sta FREEZP+2
    sta VARPNT
    bcc !next+
    inc FREEZP+3
    inc VARPNT+1
!next:
    dec data__curr_count
    bne !loop--
    rts

// 6A97
// Remove dead characters from the screen.
clear_dead_icons_from_screen:
    lda dead_icon_screen_offset
    sta FREEZP+2
    lda #>SCNMEM
    sta FREEZP+3
    ldx #$10 // 16 rows of character data (up to 8 icons)
!loop:
    ldy #$02 // 3 characters per row (zero offset)
!loop:
    lda #$00
    sta (FREEZP+2),y
    dey
    bpl !loop-
    lda FREEZP+2
    clc
    adc #CHARS_PER_SCREEN_ROW
    sta FREEZP+2
    bcc !next+
    inc FREEZP+3
!next:
    dex
    bne !loop--
    rts

// 6ABA
spell_select_imprison:
    // Check if color is strongest opposing color. If so, the icon will be immidiately released from prison and
    // therefore the spell will be wasted.
    ldy #PHASE_CYCLE_LENGTH
    lda game.state.flag__is_light_turn
    bmi !next+
    ldy #$00
!next:
    sty temp__data_store
    lda game.data__phase_cycle_board
    cmp temp__data_store
    beq display_spell_wasted
    //
    lda #STRING_IMPRISON_WHICH
    sta game.message_id
    jsr game.display_message
    lda #$00 // Immediately return after selection (ie don't allow selected icon to be moved)
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_OPPOSING_ICON
    jsr spell_select_destination
    ldx #$00
    lda common.icon.type
    cmp #MANTICORE // First dark player
    bcc !next+
    inx
!next:
    sta game.imprisoned_data__icon_id_list,x
    lda #STRING_SPELL_DONE
    jmp end_spell_selection
display_spell_wasted:
    lda #STRING_SPELL_WASTED
    sta game.message_id
    jsr game.display_message
    jmp spell_complete

// 6BD4
// Description:
// - Select spell from list of spells.
// Sets:
// - Y: Spell ID
get_selected_spell:
    lda #$00
    sta temp__data_store // Selected spell
    sta data__hold_delay_count
    jsr set_selected_spell
    lda game.curr_player_offset
    eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
    tax
    // Wait for fire button to be released.
!loop:
    lda CIAPRA,x
    and #%0001_0000 // Fire button
    beq !loop-
spell_selection_loop:
    lda game.curr_player_offset
    eor #$01
    tax
    lda CIAPRA,x
    and #%0001_0000 // Fire button
    bne !next+
    // Select spell.
    sta data__hold_delay_count
    ldy temp__data_store
    rts
!next:
    lda CIAPRA,x
    lsr
    pha
    bcs !next+ // Not up direction?
    jsr select_previous_spell
!next:
    pla
    lsr
    bcs !next+ // Not down direction?
    jsr select_next_spell
!next:
    // Wait between allowing new spell selection. select next/previous will ignore the direction input for 15 counts.
    // Therefore, 15 * 0.016667 jiffies = approximately 0.25s between displaying next/previous spell.
    lda TIME+2
!loop:
    cmp TIME+2
    beq !loop-
    bne spell_selection_loop
    //
select_previous_spell:
    dec data__hold_delay_count
    lda data__hold_delay_count
    and #$0F
    bne !return+
get_previous_spell:
    lda temp__data_store
    sec
    sbc #$01
    bpl !next+
    lda #$07 // Wrap back to last spell
!next:
    sta temp__data_store
    tay
    cpy #SPELL_ID_CEASE
    beq display_spell // Don't check if spell is used if cease casting option selected
    lda (CURLIN),y
    cmp #SPELL_USED
    beq get_previous_spell
    bne display_spell
!return:
    rts
select_next_spell:
    inc data__hold_delay_count
    lda data__hold_delay_count
    and #$0F
    cmp #$0F
    bne !return-
get_next_spell:
    lda temp__data_store
    clc
    adc #$01
set_selected_spell:
    cmp #$08
    bcc !next+
    lda #$00 // Wrap back to first spell
!next:
    sta temp__data_store
    tay
    cpy #SPELL_ID_CEASE // Cease casting?
    beq display_spell // Don't check if spell is used if cease casting option selected
    lda (CURLIN),y
    cmp #SPELL_USED
    beq get_next_spell
display_spell:
    // Clear spell display row.
    lda #$00
    ldx #CHARS_PER_SCREEN_ROW
!loop:
    sta (SCNMEM+23*CHARS_PER_SCREEN_ROW),x
    inx
    cpx #(CHARS_PER_SCREEN_ROW+CHARS_PER_SCREEN_ROW)
    bcc !loop-
    // Display the name of the spell.
    ldx #(CHARS_PER_SCREEN_ROW+10)
    ldy temp__data_store
    lda data.spell_string_id,y
    jsr board.write_text
    rts

// 6CAA
spell_select_cease:
    lda #STRING_SPELL_DONE
    jmp cancel_spell_selection

// 6CAF
// Abort current spell and return back to spell selection.
spell_complete:
    ldx #$60 // ~1.5 sec
    jsr common.wait_for_jiffy
    jsr config_used_spell_ptr
    ldy data__curr_spell_id
    lda #SPELL_UNUSED // Re-enable spell
    sta (CURLIN),y
    jsr board.clear_text_area
    ldx #$00
    lda #STRING_SPELL_CANCELED
    jsr board.write_text
    lda temp_row_store
    sta board.data__curr_icon_row
    lda temp_column_store
    sta board.data__curr_icon_col
    ldx #$40 // ~1 sec
    jsr common.wait_for_jiffy
    jmp select_spell_start

// 6CDC
// Allows user to select a destination for the cast spell. Each spell has a different action, eg a spell may select
// a current player icon to heal, or two icons to swap or an opposing player icon to imprison. The action is placed
// in the A register (see ACTION_SELECT_ constants).
spell_select_destination:
    sta curr_spell_cast_selection
!loop:
    lda #$00
    sta game.flag__interrupt_response
    jsr game.wait_for_state_change
    lda game.flag__interrupt_response
    bmi !return+
    lda game.state.flag__ai_player_ctl
    cmp game.state.flag__is_light_turn
    beq !return+
    ldy data__curr_spell_id
    cpy #SPELL_ID_SUMMON_ELEMENTAL
    bcc complete_destination_selection
    cpy #SPELL_ID_IMPRISON
    bcs complete_destination_selection
    // Summon elemental or revive spell
    ldx #$40 // ~1 sec
    jsr common.wait_for_jiffy
    lda temp_message_id_store
    sta game.message_id
    jsr game.display_message
    jmp !loop-
complete_destination_selection:
    pla
    pla
    jmp spell_complete
!return:
    rts

// 6D16
// Description:
// - Set square occupancy.
// Prerequisites:
// - A: Column offset of board square.
// - Y: Row offset of board square.
// - X: Icon ID.
// Sets:
// - `board.curr_square_occupancy`: Sets appropriate byte within the occupancy array.
set_occupied_square:
    pha
    lda board.data.row_occupancy_lo_ptr,y
    sta OLDLIN
    lda board.data.row_occupancy_hi_ptr,y
    sta OLDLIN+1
    pla
    tay
    txa
    sta (OLDLIN),y
    rts

// 7205
// Description:
// - Count number of used spells for the current player.
// Prerequisites:
// - Y: is 0 for light player and 7 for dark player.
// Sets:
// - `data__used_spell_count`: Number of used spells.
// Preserves:
// - X
count_used_spells:
    txa
    pha
    lda #$00
    sta data__used_spell_count
    ldx #$07
!loop:
    lda flag__light_used_spells,y
    cmp #SPELL_USED
    bne !next+
    inc data__used_spell_count
!next:
    iny
    dex
    bne !loop-
    pla
    tax
    rts

// 87BC
// Allows the player to select a square or icon to cast the spell on to. Some spells (eg transport) require multiple
// selections. Others require selection of current player icon (eg heal), opposing player icon (eg imprison) or
// any icon (eg exchange) or location (eg transport destination).
// After the action is completed, the selected icon type will be added to the stack or $80 if empty square selected.
spell_select:
    pha
    txa
    and #$0F // Remove $80 flag
    // Set spell action dynamic function.
    asl
    tax
    lda data.spell_action_fn_ptr,x
    sta prt__spell_fn
    lda data.spell_action_fn_ptr+1,x
    sta prt__spell_fn+1
    pla
    pha
    bpl check_valid_square
    lda game.curr_icon_total_moves
    beq !next+
    // Move icon to destination after selection completed.
    // `game.curr_icon_total_moves` will contain either a:
    // - 00: means return immediately after selection (eg heal spell)
    // - 8F: means icon can be placed anwwhere on the board and will be moved in to that location (eg exchange spell).
    //       This will use the fly action (eg $80 means fly and $0F means move up to 15 squares).
    // - CF: means icon can be placed anwwhere on the board and will be transported to that location (eg transport
    //       spell). This will use the transport animation (eg $80 means fly, $40 means transport and $0f means move up
    //       to 15 squares).
check_valid_square:
    lda board.data__curr_board_row
    sta board.data__curr_row
    lda board.data__curr_board_col
    sta board.data__curr_column
    jsr board.test_magic_square_selected
    lda game.flag__icon_destination_valid
    bmi spell_abort_magic_square
!next:
    jmp (prt__spell_fn)
spell_abort_magic_square:
    pla
    lsr game.flag__icon_destination_valid // Invalid selection
    lda #(FLAG_ENABLE+STRING_CHARMED_PROOF)
    bmi spell_end_turn

// 87F6
// Allow player to select any non-imprisoned icon piece on the board.
// Action command: `ACTION_SELECT_ICON` ($80)
spell_select_icon:
    pla
    bmi !return+ // Unoccupied square selected
    cmp common.icon.type
    beq !return+
    sta common.icon.type
spell_check_icon_is_free:
    cmp game.imprisoned_data__icon_id_list
    beq !next+
    cmp game.imprisoned_data__icon_id_list+1
    beq !next+
    asl game.flag__icon_destination_valid
!return:
    rts
!next:
    // Show icon imprisoned message and restart turn
    lda #(FLAG_ENABLE+STRING_ICON_IMPRISONED)
spell_end_turn:
    sta game.flag__new_square_selected
    lda #FLAG_ENABLE
    sta common.flag__enable_next_state
    rts

// 881A
// Allow player to select any square on the board.
// Action command: `ACTION_SELECT_SQUARE` ($81)
spell_select_square:
    pla
    jmp game.check_icon_destination

// 881E
// Allow player to select any of the current player icons.
// Action command: `ACTION_SELECT_PLAYER_ICON` ($82)
spell_select_player_icon:
    pla
    bmi !return- // Unoccupied square selected
    sta common.icon.type
    tay
    lda board.icon.init_matrix,y
    eor game.state.flag__is_light_turn
    and #$08
    bne !return- // Not current player icon
    asl game.flag__icon_destination_valid
    rts

// 8833
// Allow player to select any opposing player and initiate a challenge.
// Action command: `ACTION_SELECT_CHALLENGE_ICON` ($83)
spell_select_challenge_icon:
    pla
    bmi !return- // Unoccupied square selected
    jmp game.check_icon_destination

// 8839
// Allow player to select a square surrounding the spell caster (charmed sqaure).
// Action command: `ACTION_SELECT_CHARMED_SQUARE` ($84)
spell_select_charmed_square:
    pla
    bpl !return- // Occupied square selected
    // Check if selected square is immediately above or below the spell caster.
    ldy board.data__curr_board_row
    cpy board.data__curr_icon_row
    beq !next+
    dey
    cpy board.data__curr_icon_row
    beq !next+
    iny
    iny
    cpy board.data__curr_icon_row
    bne !return+
!next:
    // Check if selected square is immediately to the left or right of the spell caster.
    ldy board.data__curr_board_col
    cpy board.data__curr_icon_col
    beq !next+
    dey
    cpy board.data__curr_icon_col
    beq !next+
    iny
    iny
    cpy board.data__curr_icon_col
    bne !return+
!next:
    jsr board.add_icon_to_matrix
    asl game.flag__icon_destination_valid
!return:
    rts

// 886D
// Allow player to select an opposing icon. Turn ends after selection (non challenge).
// Action command: `ACTION_SELECT_OPPOSING_ICON` ($85)
spell_select_opposing_icon:
    pla
    bmi !return- // Unoccupied square selected
    sta common.icon.type
    tay
    lda board.icon.init_matrix,y
    eor game.state.flag__is_light_turn
    and #$08
    beq !return- // Not opposing player icon
    asl game.flag__icon_destination_valid
!return:
    rts

// 8882
// Allows player to select any current player icons that are not imprisoned.
// Action command: `ACTION_SELECT_FREE_PLAYER_ICON` ($86)
spell_select_free_player_icon:
    pla
    bmi !return- // Unoccupied square selected
    sta common.icon.type
    tay
    lda board.icon.init_matrix,y
    eor game.state.flag__is_light_turn
    and #$08
    bne !return- // Not current player icon
    lda common.icon.type
    jmp spell_check_icon_is_free

// 8899
// Allows player to select an icon from a list of dead icon to revive.
// Action command: `ACTION_SELECT_REVIVE_ICON` ($87)
spell_select_revive_icon:
    pla
    ldy board.data__curr_board_row
    cpy #$08 // Max 8 icons in dead icon list
    bcs !return-
    lda curr_dead_icon_offsets,y
    cmp #DEAD_ICON_SLOT_UNUSED
    beq !return-
    sta common.icon.type
    asl game.flag__icon_destination_valid
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace data {
    // 67A0
    // Location of used spell arrays for each player
    used_spell_ptr:
        .word flag__light_used_spells, flag__dark_used_spells

    // 67A4
    // Spell cast function pointers.
    spell_cast_fn_ptr:
        .word spell_select_teleport, spell_select_heal, spell_select_shift_time, spell_select_exchange
        .word spell_select_elemental, spell_select_revive, spell_select_imprison, spell_select_cease

    // 87AC
    // Spell action function pointers. Actions are used to allow the player to select board squares or icons.
    spell_action_fn_ptr:
        .word spell_select_icon, spell_select_square, spell_select_player_icon, spell_select_challenge_icon
        .word spell_select_charmed_square, spell_select_opposing_icon, spell_select_free_player_icon
        .word spell_select_revive_icon

    // 8B8C
    // Spell name message string IDs.
    spell_string_id:
        .byte STRING_TELEPORT, STRING_HEAL, STRING_SHIFT_TIME, STRING_EXCHANGE, STRING_SUMMON_ELEMENTAL
        .byte STRING_REVIVE, STRING_IMPRISON, STRING_CEASE
}

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// 6AFD
// ID of used elemental. Used to ensure opposing player will generate a unique elemental.
data__used_elemental_id: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCFE
// Is set if the selected square is a magic square.
flag__sqaure_is_magic: .byte $00

// BD0E
// Is 0 for spell caster not selected, $80 for selected and +$80 for selected spell.
curr_spell_cast_selection: .byte $00

// BD3A
// Current selected spell ID.
data__curr_spell_id: .byte $00

// BD53
// Temporary current row storage.
temp_row_store: .byte $00

// BD54
// Temporary current column row storage.
temp_column_store: .byte $00

// BD66
// Pointer to function to execute selected spell logic.
prt__spell_fn: .word $0000

// BD71
// Temporary message ID storage.
temp_message_id_store: .byte $00

// BD7B
// Temporary counter storage.
data__curr_count: .byte $00

// BE7F
// List of unique dead icon offsets.
curr_dead_icon_offsets: .byte $00, $00, $00, $00, $00, $00, $00, $00

// BE87
// List of unique dead icon types.
curr_dead_icon_types: .byte $00, $00, $00, $00, $00, $00, $00, $00

// BEFA
// Flags used to keep track of spells used by light player.
// Spells are in order: teleport, heal, shift time, exchange, summon elemental, revive, imprison.
flag__light_used_spells: .byte $00, $00, $00, $00, $00, $00, $00

// BF01
// Flags used to keep track of spells used by dark player.
// Spells are in order: teleport, heal, shift time, exchange, summon elemental, revive, imprison.
flag__dark_used_spells: .byte $00, $00, $00, $00, $00, $00, $00

// BF1A
// Generic temporary data storage area
temp__data_store: .byte $00

// BF23
// Count of number of used spells for a specific player.
data__used_spell_count: .byte $00

// BF23
// Index used to acces an item within the dead icon array.
data__dead_icon_index: .byte $00

// BF24
// Number of dead icons in the dead icon list.
data__number_dead_icons: .byte $00

// BF2E
// Temporary storage for selected icon.
temp_selected_icon_store: .byte $00

// BF32
// Counter used to delay selection of next/previous spell. Must be helf for a count of #$0F before selection is
// changed.
data__hold_delay_count: .byte $00

// BF43
// Screen offset for start of graphical memory for dead icon list display.
dead_icon_screen_offset: .byte $00 
