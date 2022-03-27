.filenamespace magic
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used to select and cast spells.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 62FF
// Detects if the selected square is a magic square.
// Requires:
// - `cnt__board_row`: row of the square to test.
// - `cnt__board_col`: column of the square to test.
// Sets:
// - `flag__is_destination_valid`: is $80 if selected square is a magic square.
// Preserves:
// - X, Y
test_magic_square_selected:
    tya
    pha
    lda #(FLAG_ENABLE/2) // Default to no action - used $40 here so can do quick asl to turn in to $80 (flag_enable)
    sta game.flag__is_destination_valid
    ldy #(BOARD_NUM_MAGIC_SQUARES-1) // 0 offset
!loop:
    lda board.data__magic_square_col_list,y
    cmp cnt__board_row
    bne !next+
    lda board.data__magic_square_row_list,y
    cmp cnt__board_col
    beq !selected+
!next:
    dey
    bpl !loop-
    bmi !not_selected+
!selected:
    asl game.flag__is_destination_valid
!not_selected:
    pla
    tay
    rts

// 67B4
select_spell:
    // Store current piece location to restore location if the spell is aborted.
    lda board.data__curr_icon_row
    sta private.data__curr_board_row
    lda board.data__curr_icon_col
    sta private.data__curr_board_col
    lda game.data__ai_player_ctl
    cmp game.flag__is_light_turn
    bne select_spell_from_list
    jmp ai.magic_select_spell

// 67CB
select_spell_from_list:
    // Configure player.
    ldy #$00
    lda game.flag__is_light_turn
    bpl !next+
    iny
!next:
    sty game.data__player_offset
    cpy #$00
    beq !next+
    ldy #NUM_SPELLS
!next:
    // End spell selection if no spells left.
    jsr count_used_spells
    lda data__used_spell_count
    cmp #NUM_SPELLS // All spells used?
    bcc !next+
    lda #STRING_NO_SPELLS
    beq cancel_spell_selection
!next:
    jsr private.config_used_spell_ptr
    jsr board.clear_text_area
    lda #STRING_SELECT_SPELL
    ldx #$0A
    jsr board.write_text
    // Get spell selection.
    jsr private.get_selected_spell
    sty private.data__curr_spell_id
    jsr board.clear_text_area
    ldy private.data__curr_spell_id
    lda private.ptr__spell_string_id_list,y
    ldx #$0A
    jsr board.write_text
    ldy private.data__curr_spell_id
    cpy #SPELL_ID_CEASE
    beq !next+
    lda #SPELL_USED
    sta (CURLIN),y
!next:
    // Cast spell.
    tya
    asl
    tay
    lda private.ptr__spell_cast_fn_list,y
    sta private.prt__spell_fn
    lda private.ptr__spell_cast_fn_list+1,y
    sta private.prt__spell_fn+1
    jmp (private.prt__spell_fn)
    //
// 6828
cancel_spell_selection:
    jsr private.end_spell_selection
    jsr board.clear_text_area
    pla // End turn
    pla
    jmp game.play_turn

// 7205
// Count number of used spells for the current player.
// Requires:
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
    ldx #NUM_SPELLS
!loop:
    lda data__light_used_spells_list,y
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
    lda private.ptr__spell_action_fn_list,x
    sta private.prt__spell_fn
    lda private.ptr__spell_action_fn_list+1,x
    sta private.prt__spell_fn+1
    pla
    pha
    bpl !check_valid+
    lda game.data__icon_moves
    beq !next+
    // Move icon to destination after selection completed.
    // `game.data__icon_moves` will contain either a:
    // - 00: means return immediately after selection (eg heal spell)
    // - 8F: means icon can be placed anwwhere on the board and will be moved in to that location (eg exchange spell).
    //       This will use the fly action (eg $80 means fly and $0F means move up to 15 squares).
    // - CF: means icon can be placed anwwhere on the board and will be transported to that location (eg transport
    //       spell). This will use the transport animation (eg $80 means fly, $40 means transport and $0f means move up
    //       to 15 squares).
!check_valid:
    lda board.data__curr_board_row
    sta cnt__board_row
    lda board.data__curr_board_col
    sta cnt__board_col
    jsr test_magic_square_selected
    lda game.flag__is_destination_valid
    bmi !abort+
!next:
    jmp (private.prt__spell_fn)
!abort:
    pla
    lsr game.flag__is_destination_valid // Invalid selection
    lda #(FLAG_ENABLE+STRING_CHARMED_PROOF)
    jmp private.spell_end_turn // Source has BMI but we need JMP here as function is relocated too far away

//---------------------------------------------------------------------------------------------------------------------
// Private functions.
.namespace private {
    // 6833
    // Configures a pointer to the start of the used spell array for the current player.
    // Requires:
    // - `game.data__player_offset`: Current player (0 for light, 1 for dark).
    // Sets:
    // - `CURLIN`: Pointer to spell used array (one byte for each spell type). See `data__light_used_spells_list` for order
    //   of bytes.
    // Preserves:
    // - X
    config_used_spell_ptr:
        lda game.data__player_offset
        asl
        tay
        lda private.ptr__player_used_spell_list,y
        sta CURLIN
        lda private.ptr__player_used_spell_list+1,y
        sta CURLIN+1
        rts

    // 6843
    spell_select_teleport:
        lda #STRING_TELEPORT_WHICH
        sta game.flag__is_new_square_selected
        jsr game.display_message
        lda #$00 // Immediately return after selection (ie don't allow selected icon to be moved)
        sta game.data__icon_moves
        lda #ACTION_SELECT_FREE_PLAYER_ICON
        jsr spell_select_destination
        //
        lda game.data__ai_player_ctl
        cmp game.flag__is_light_turn
        bne !next+
        // 685D  AD 6E BE   lda WBE6E // TODO
        // 6860  8D 51 BD   sta WBD51
        // 6863  AD 5C BE   lda WBE5C
        // 6866  8D 50 BD   sta WBD50
        // 6869  20 A1 7A   jsr W7AA1
        jmp !skip+
    !next:
        lda #STRING_TELEPORT_WHERE
        sta game.flag__is_new_square_selected
        jsr game.display_message
    !skip:
        ldy board.data__curr_board_row
        sty board.data__curr_icon_row
        lda board.data__curr_board_col
        sta board.data__curr_icon_col
        lda #(ICON_CAN_FLY+ICON_CAN_CAST+$0F) // Allow selected icon to move anywhere usin the teleport animation
        sta game.data__icon_moves
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
        sta game.flag__is_new_square_selected
        jsr game.display_message
        lda #$00 // Immediately return after selection (ie don't allow selected icon to be moved)
        sta game.data__icon_moves
        lda #ACTION_SELECT_PLAYER_ICON
        jsr spell_select_destination
        ldx common.param__icon_type_list
        ldy board.data__piece_icon_offset_list,x
        lda game.data__icon_strength_list,y
        sta game.data__piece_strength_list,x
        lda #STRING_SPELL_DONE

    // 68B9
    end_spell_selection:
        sta game.flag__is_new_square_selected
        jsr game.display_message
        ldx #(2*JIFFIES_PER_SECOND)
        jsr common.wait_for_jiffy
        rts

    // 68C5
    spell_select_shift_time:
        lda game.flag__is_phase_towards_dark
        eor #$FF
        sta game.flag__is_phase_towards_dark
        lda #STRING_REVERED_TIME
        bpl end_spell_selection

    // 68D1
    spell_select_exchange:
        lda #STRING_TRANSPOSE_WHICH
        sta game.flag__is_new_square_selected
        jsr game.display_message
        lda #FLAG_ENABLE_FF // Clear selected icon
        sta common.param__icon_type_list
        lda #$00
        sta game.data__icon_moves
        lda #ACTION_SELECT_ICON
        jsr spell_select_destination
        //
        lda board.data__curr_board_row
        sta board.data__curr_icon_row
        lda board.data__curr_board_col
        sta board.data__curr_icon_col
        lda common.param__icon_type_list
        sta data__exchange_source_icon // First selected icon
        lda #STRING_EXCHANGE_WHICH
        sta game.flag__is_new_square_selected
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
        ldx #(0.75*JIFFIES_PER_SECOND)
        jsr common.wait_for_jiffy
        ldx common.param__icon_type_list
        ldy board.data__curr_icon_row
        lda board.data__curr_icon_col
        jsr set_occupied_square
        ldx data__exchange_source_icon
        ldy board.data__curr_board_row
        lda board.data__curr_board_col
        jsr set_occupied_square
        rts

    // 6AFE
    spell_select_elemental:
        // Check if there are any enemy icons located on non-magic squares. If not, the spell will be wasted and an alert
        // shown. The check is a bit rough - it starts at occupancy location 80 ($50) which is the last square on the board
        // (0 offset) and works backwards. An array of magic square locations is stored in
        // `game.data__magic_square_offset_list`. If the counter is decremented to the magic square location, the next
        // magic square is stored and the occupancy check is skipped. This repeats until all squares have been checked.
        // The loop exits as soon as an enemy piece is detected. If we check all squares (with magic squares skipped) and
        // no enemey piece is found, then we show a spell wasted message.
        ldx #(BOARD_SIZE-1) // 0 offset
        ldy #(BOARD_NUM_MAGIC_SQUARES-1) // 0 offset
        lda game.data__magic_square_offset_list+4
        sta data__temp_storage
    !loop:
        cpx data__temp_storage // Up to next magic square?
        bne !next+
        dey
        bmi !check_next+ // No more magic squares
        // Store next magic square location.
        lda game.data__magic_square_offset_list,y
        sta data__temp_storage
        jmp !check_next+
    !next:
        // Check if square has opposing player icon
        lda board.data__square_occupancy_list,x
        bmi !check_next+ // No icon
        cmp #MANTICORE // First dark player icon id
        php
        lda game.flag__is_light_turn
        bpl !next+
        plp
        bcc !allow+
        bcs !check_next+
    !next:
        plp
        bcs !allow+
    !check_next:
        dex
        bpl !loop-
        // All opposing icons on charmed squares. Spell wasted. Display warning message.
        lda #STRING_CHARMED_PROOF
        ldx #NUM_SCREEN_COLUMNS
        jsr board.write_text
        jmp spell_complete
        //
    !allow:
        // Set elemental starting position.
        lda #$FE // 2 columns to the left of board for light player
        ldx game.data__player_offset
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
        cmp private.data__used_elemental_id // Ensures both players generate a different elemental
        beq !loop-
        sta private.data__used_elemental_id
        pha
        clc
        adc #AIR_ELEMENTAL // Elemental ID
        tax
        stx common.param__icon_type_list
        ldy board.data__piece_icon_offset_list,x
        sty common.param__icon_offset_list
        lda game.data__icon_strength_list,y
        sta game.data__piece_strength_list,x
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
        stx game.flag__is_moving_icon
        jsr board.get_sound_for_icon
        lda board.data__curr_board_col
        ldy board.data__curr_board_row
        jsr board.convert_coord_sprite_pos
        jsr common.initialize_sprite
        lda #BYTERS_PER_ICON_SPRITE
        sta common.param__sprite_source_len
        jsr common.add_sprite_set_to_graphics
        lda game.data__player_offset
        beq !next+
        lda #LEFT_FACING_ICON_FRAME
    !next:
        sta common.param__icon_sprite_source_frame_list
        jsr board.set_icon_sprite_location
        //
        lda game.data__ai_player_ctl
        cmp game.flag__is_light_turn
        beq !next+
        lda #STRING_SEND_WHERE
        sta game.flag__is_new_square_selected
        sta flag__is_new_square_selected
        jsr game.display_message
    !next:
        lda common.param__icon_offset_list
        cmp #EARTH_ELEMENTAL_OFFSET
        bne !next+
        lda #ICON_SLOW_SPEED
        sta game.data__icon_speed
    !next:
        lda #(ICON_CAN_FLY+$0F)
        sta game.data__icon_moves
        lda #ACTION_SELECT_CHALLENGE_ICON
        jsr spell_select_destination
        rts

    // 693F
    spell_select_revive:
        jsr check_empty_non_magic_surrounding_square
        lda flag__is_valid_square
        bmi !next+
        // No empty non-magical squares surrounding the spell caster.
        lda #STRING_NO_CHARMED
    !return:
        ldx #$00
        jsr board.write_text
        jmp spell_complete
    !next:
        ldx #$00
        stx data__dead_icon_count
        cpx game.data__player_offset
        beq !next+
        ldx #BOARD_NUM_PLAYER_PIECES // Set offset for player icon strength and type (0=light, 18=dark)
    !next:
        // Clear dead icon list.
        .const MAX_NUM_DEAD_ICONS = $08
        ldy #(MAX_NUM_DEAD_ICONS-1) // 0 offset
        lda #DEAD_ICON_SLOT_UNUSED
    !loop:
        sta data__dead_icon_offset_list,y
        dey
        bpl !loop-
        // Populate dead icon list.
        lda #BOARD_NUM_PLAYER_PIECES
        sta data__temp_storage
    !loop:
        lda game.data__piece_strength_list,x
        bne !next+
        lda board.data__piece_icon_offset_list,x
        // Check if icon type is already in the list (eg 2 of the same type may have been killed).
        ldy data__dead_icon_count
    !dead_check_loop:
        cmp data__dead_icon_offset_list,y
        beq !next+
        dey
        bpl !dead_check_loop-
        // Store the dead icon in the list.
        ldy data__dead_icon_count
        sta data__dead_icon_offset_list,y
        txa
        sta data__dead_icon_type_list,y
        iny
        sty data__dead_icon_count
        cpy #$08 // Dead icon list full?
        beq !next++
    !next:
        inx
        dec data__temp_storage
        bne !loop-
    !next:
        lda data__dead_icon_count
        bne !next+
        // Display error if no icons have been killed.
        lda #STRING_ICONS_ALL_ALIVE
        jmp !return-
        //
    !next:
        // Set screen and color memory pointers for displaying the dead icon list.
        lda #(NUM_SCREEN_COLUMNS*3)
        ldy game.flag__is_light_turn
        bpl !next+
        lda #<(SCNMEM+(NUM_SCREEN_COLUMNS*3+NUM_SCREEN_COLUMNS-4))
    !next:
        sta FREEZP+2 // Screen memory pointer
        sta VARPNT // Color memory pointer
        sta data__screen_mem_offset
        lda #>SCNMEM
        sta FREEZP+3
        lda #>COLRAM
        sta VARPNT+1
        // Display the dead icons.
        lda #$00
        sta idx__dead_icon
    !loop:
        ldy idx__dead_icon
        lda data__dead_icon_offset_list,y
        pha
        asl
        asl
        sta data__temp_storage
        pla
        asl
        clc
        adc data__temp_storage
        sta data__temp_storage
        jsr display_dead_icon
        inc idx__dead_icon
        lda idx__dead_icon
        cmp data__dead_icon_count
        bcc !loop-
        // Calculate starting position and display the selection square.
        lda #$FE // 2 columns to the left of board for light player
        ldx game.data__player_offset
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
        sta board.data__sprite_curr_x_pos_list+1
        tya
        sec
        sbc #$01
        sta board.data__sprite_curr_y_pos_list+1
        jsr board.set_icon_sprite_location
        // Allow user to select a dead icon.
        lda #STRING_REVIVE_WHICH
        sta game.flag__is_new_square_selected
        jsr game.display_message
        lda #$00
        sta game.data__icon_moves
        lda #ACTION_SELECT_REVIVE_ICON
        jsr spell_select_destination
        // Display selected icon sprite and allow user to select the destination.
        lda board.data__curr_board_col
        ldy board.data__curr_board_row
        ldx #$00
        jsr board.convert_coord_sprite_pos
        ldy board.data__curr_board_row
        lda data__dead_icon_offset_list,y
        sta common.param__icon_offset_list
        lda data__dead_icon_type_list,y
        sta common.param__icon_type_list
        tax
        lda #STRING_CHARMED_WHERE
        sta game.flag__is_new_square_selected
        sta flag__is_new_square_selected
        jsr game.display_message
        ldy common.param__icon_offset_list
        lda game.data__icon_strength_list,y
        sta game.data__piece_strength_list,x // Restore icon health
        ldx #$00
        stx game.flag__is_moving_icon
        jsr board.get_sound_for_icon
        jsr common.initialize_sprite
        jsr common.add_sprite_set_to_graphics
        jsr board.set_icon_sprite_location
        jsr clear_dead_icons_from_screen
        lda #(ICON_CAN_FLY+$0F)
        sta game.data__icon_moves
        lda #ACTION_SELECT_CHARMED_SQUARE
        jsr spell_select_destination
        rts

    // 6A67
    // Draw an icon piece on the screen uisng character dot data. A pice is 3 characters wide and 2 characters high.
    display_dead_icon:
        lda #$02 // 2 rows high
        sta cnt__screen_row
    !icon_loop:
        ldy #$00
        ldx #$03 // 3 characters wide
    !loop:
        lda data__temp_storage
        sta (FREEZP+2),y
        lda (VARPNT),y
        ora #$08 // Derive color
        sta (VARPNT),y
        iny
        inc data__temp_storage
        dex
        bne !loop-
        lda FREEZP+2
        clc
        adc #NUM_SCREEN_COLUMNS
        sta FREEZP+2
        sta VARPNT
        bcc !next+
        inc FREEZP+3
        inc VARPNT+1
    !next:
        dec cnt__screen_row
        bne !icon_loop-
        rts

    // 6A97
    // Remove dead characters from the screen.
    clear_dead_icons_from_screen:
        lda data__screen_mem_offset
        sta FREEZP+2
        lda #>SCNMEM
        sta FREEZP+3
        ldx #$10 // 16 rows of character data (up to 8 icons)
    !icon_loop:
        ldy #$02 // 3 characters per row (0 offset)
    !loop:
        lda #$00
        sta (FREEZP+2),y
        dey
        bpl !loop-
        lda FREEZP+2
        clc
        adc #NUM_SCREEN_COLUMNS
        sta FREEZP+2
        bcc !next+
        inc FREEZP+3
    !next:
        dex
        bne !icon_loop-
        rts

    // 6ABA
    spell_select_imprison:
        // Check if color is strongest opposing color. If so, the icon will be immidiately released from prison and
        // therefore the spell will be wasted.
        ldy #PHASE_CYCLE_LENGTH
        lda game.flag__is_light_turn
        bmi !next+
        ldy #$00
    !next:
        sty data__temp_storage
        lda game.data__phase_cycle_board
        cmp data__temp_storage
        beq !abort+
        //
        lda #STRING_IMPRISON_WHICH
        sta game.flag__is_new_square_selected
        jsr game.display_message
        lda #$00 // Immediately return after selection (ie don't allow selected icon to be moved)
        sta game.data__icon_moves
        lda #ACTION_SELECT_OPPOSING_ICON
        jsr spell_select_destination
        ldx #$00
        lda common.param__icon_type_list
        cmp #MANTICORE // First dark player
        bcc !next+
        inx
    !next:
        sta game.data__imprisoned_icon_list,x
        lda #STRING_SPELL_DONE
        jmp end_spell_selection
    !abort:
        lda #STRING_SPELL_WASTED
        sta game.flag__is_new_square_selected
        jsr game.display_message
        jmp spell_complete

    // 6BD4
    // - Select spell from list of spells.
    // Sets:
    // - Y: Spell ID
    get_selected_spell:
        lda #$00
        sta data__temp_storage // Selected spell
        sta cnt__select_next_delay
        jsr set_selected_spell
        lda game.data__player_offset
        eor #$01 // Swap so is 2 for player 1 and 1 for player 2. Required as Joystick 1 is on CIA port 2 and vice versa.
        tax
        // Wait for fire button to be released.
    !loop:
        lda CIAPRA,x
        and #%0001_0000 // Fire button
        beq !loop-
    !select_loop:
        lda game.data__player_offset
        eor #$01
        tax
        lda CIAPRA,x
        and #%0001_0000 // Fire button
        bne !next+
        // Select spell.
        sta cnt__select_next_delay
        ldy data__temp_storage
        rts
    !next:
        lda CIAPRA,x
        lsr
        pha
        bcs !next+ // Not up direction?
        jsr !prev_spell+
    !next:
        pla
        lsr
        bcs !next+ // Not down direction?
        jsr !next_spell+
    !next:
        // Wait between allowing new spell selection. select next/previous will ignore the direction input for 15 counts.
        // Therefore, 15 * 0.016667 jiffies = approximately 0.25s between displaying next/previous spell.
        lda TIME+2
    !loop:
        cmp TIME+2
        beq !loop-
        bne !select_loop-
        //
    !prev_spell:
        dec cnt__select_next_delay
        lda cnt__select_next_delay
        and #$0F
        bne !return+
    !get_prev:
        lda data__temp_storage
        sec
        sbc #$01
        bpl !next+
        lda #NUM_SPELLS // Wrap back to last spell
    !next:
        sta data__temp_storage
        tay
        cpy #SPELL_ID_CEASE
        beq !show_spell+ // Don't check if spell is used if cease casting option selected
        lda (CURLIN),y
        cmp #SPELL_USED
        beq !get_prev-
        bne !show_spell+
    !return:
        rts
    !next_spell:
        inc cnt__select_next_delay
        lda cnt__select_next_delay
        and #$0F
        cmp #$0F
        bne !return-
    !get_next:
        lda data__temp_storage
        clc
        adc #$01
        //
    // 6C50
    set_selected_spell:
        cmp #$08
        bcc !next+
        lda #$00 // Wrap back to first spell
    !next:
        sta data__temp_storage
        tay
        cpy #SPELL_ID_CEASE // Cease casting?
        beq !show_spell+ // Don't check if spell is used if cease casting option selected
        lda (CURLIN),y
        cmp #SPELL_USED
        beq !get_next-
    !show_spell:
        // Clear spell display row.
        lda #$00
        ldx #NUM_SCREEN_COLUMNS
    !loop:
        sta (SCNMEM+(NUM_SCREEN_ROWS-2)*NUM_SCREEN_COLUMNS),x
        inx
        cpx #(NUM_SCREEN_COLUMNS+NUM_SCREEN_COLUMNS)
        bcc !loop-
        // Display the name of the spell.
        ldx #(NUM_SCREEN_COLUMNS+10)
        ldy data__temp_storage
        lda private.ptr__spell_string_id_list,y
        jsr board.write_text
        rts

    // 6CAA
    spell_select_cease:
        lda #STRING_SPELL_DONE
        jmp cancel_spell_selection

    // 6CAF
    // Abort current spell and return back to spell selection.
    spell_complete:
        ldx #(1.5*JIFFIES_PER_SECOND)
        jsr common.wait_for_jiffy
        jsr config_used_spell_ptr
        ldy data__curr_spell_id
        lda #SPELL_UNUSED // Re-enable spell
        sta (CURLIN),y
        jsr board.clear_text_area
        ldx #$00
        lda #STRING_SPELL_CANCELED
        jsr board.write_text
        lda private.data__curr_board_row
        sta board.data__curr_icon_row
        lda private.data__curr_board_col
        sta board.data__curr_icon_col
        ldx #(1*JIFFIES_PER_SECOND)
        jsr common.wait_for_jiffy
        jmp select_spell_from_list

    // 6CDC
    // Allows user to select a destination for the cast spell. Each spell has a different action, eg a spell may select
    // a current player icon to heal, or two icons to swap or an opposing player icon to imprison. The action is placed
    // in the A register (see ACTION_SELECT_ constants).
    spell_select_destination:
        sta idx__selected_spell
    !loop:
        lda #$00
        sta game.data__last_interrupt_response_flag
        jsr game.wait_for_state_change
        lda game.data__last_interrupt_response_flag
        bmi !return+
        lda game.data__ai_player_ctl
        cmp game.flag__is_light_turn
        beq !return+
        ldy data__curr_spell_id
        cpy #SPELL_ID_SUMMON_ELEMENTAL
        bcc !done+
        cpy #SPELL_ID_IMPRISON
        bcs !done+
        // Summon elemental or revive spell
        ldx #(1*JIFFIES_PER_SECOND)
        jsr common.wait_for_jiffy
        lda flag__is_new_square_selected
        sta game.flag__is_new_square_selected
        jsr game.display_message
        jmp !loop-
    !done:
        pla
        pla
        jmp spell_complete
    !return:
        rts

    // 6D16
    // Set square occupancy.
    // Requires:
    // - A: Column offset of board square.
    // - Y: Row offset of board square.
    // - X: Icon ID.
    // Sets:
    // - `board.data__square_occupancy_list`: Sets appropriate byte within the occupancy array.
    set_occupied_square:
        pha
        lda board.ptr__board_row_occupancy_lo,y
        sta OLDLIN
        lda board.ptr__board_row_occupancy_hi,y
        sta OLDLIN+1
        pla
        tay
        txa
        sta (OLDLIN),y
        rts

    // 7912
    // Description:
    // Checks if any of the squares surrounding the current square is empty and non-magical.
    // Requires:
    // - `board.data__curr_icon_row`: row of source square
    // - `board.data__curr_icon_col`: column of source square
    // Sets:
    // - `flag__is_valid_square`: #$80 if one or more surrounding squares are empty and non-magical
    // - `data__surrounding_square_row_list`: Contains an array of rows for all 9 squares (including source)
    // - `data__surrounding_square_col_list`: Contains an array of columns for all 9 squares (including source)
    check_empty_non_magic_surrounding_square:
        lda #(FLAG_ENABLE/2) // Default to no action - used $40 here so can do quick asl to turn in to $80 (flag_enable)
        sta flag__is_valid_square
        jsr board.surrounding_squares_coords
        ldx #$08 // Number of surrounding squares (and current square)
    !loop:
        // Test if surrounding square is occupied or is a magic square. If so, test the next square. Set ENABLE flag and
        // exit as soon as an empty/non-magic square is found.
        lda board.data__surrounding_square_row_list,x
        bmi !next+
        cmp #$09 // Only test columns 0-8
        bcs !next+
        tay
        sty cnt__board_row
        lda board.data__surrounding_square_col_list,x
        bmi !next+
        cmp #$09 // Only test rows 0-8
        bcs !next+
        sta cnt__board_col
        jsr game.get_square_occupancy
        bpl !next+
        jsr test_magic_square_selected
        lda game.flag__is_destination_valid
        bmi !next+
        // Empty non-magical square found.
        lda game.flag__is_light_turn
        cmp game.data__ai_player_ctl
        // 7948  F0 04      beq W794E // TODO: AI
        asl flag__is_valid_square
        rts
    !next:
        dex
        bpl !loop-
        rts

    // 87F6
    // Allow player to select any non-imprisoned icon piece on the board.
    // Action command: `ACTION_SELECT_ICON` ($80)
    spell_select_icon:
        pla
        bmi !return+ // Unoccupied square selected
        cmp common.param__icon_type_list
        beq !return+
        sta common.param__icon_type_list
    spell_check_icon_is_free:
        cmp game.data__imprisoned_icon_list
        beq !next+
        cmp game.data__imprisoned_icon_list+1
        beq !next+
        asl game.flag__is_destination_valid
    !return:
        rts
    !next:
        // Show icon imprisoned message and restart turn
        lda #(FLAG_ENABLE+STRING_ICON_IMPRISONED)
        //
    // 8811
    spell_end_turn:
        sta game.flag__is_new_square_selected
        lda #FLAG_ENABLE
        sta common.flag__cancel_interrupt_state
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
        sta common.param__icon_type_list
        tay
        lda board.data__piece_icon_offset_list,y
        eor game.flag__is_light_turn
        and #$08
        bne !return- // Not current player icon
        asl game.flag__is_destination_valid
        rts

    // 8833
    // Allow player to select any opposing player and initiate a challenge.
    // Action command: `ACTION_SELECT_CHALLENGE_ICON` ($83)
    spell_select_challenge_icon:
        pla
        bmi !return- // Unoccupied square selected
        jmp game.check_icon_destination

    // 8839
    // Allow player to select a square surrounding the spell caster (charmed square).
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
        asl game.flag__is_destination_valid
    !return:
        rts

    // 886D
    // Allow player to select an opposing icon. Turn ends after selection (non challenge).
    // Action command: `ACTION_SELECT_OPPOSING_ICON` ($85)
    spell_select_opposing_icon:
        pla
        bmi !return- // Unoccupied square selected
        sta common.param__icon_type_list
        tay
        lda board.data__piece_icon_offset_list,y
        eor game.flag__is_light_turn
        and #$08
        beq !return- // Not opposing player icon
        asl game.flag__is_destination_valid
    !return:
        rts

    // 8882
    // Allows player to select any current player icons that are not imprisoned.
    // Action command: `ACTION_SELECT_FREE_PLAYER_ICON` ($86)
    spell_select_free_player_icon:
        pla
        bmi !return- // Unoccupied square selected
        sta common.param__icon_type_list
        tay
        lda board.data__piece_icon_offset_list,y
        eor game.flag__is_light_turn
        and #$08
        bne !return- // Not current player icon
        lda common.param__icon_type_list
        jmp spell_check_icon_is_free

    // 8899
    // Allows player to select an icon from a list of dead icon to revive.
    // Action command: `ACTION_SELECT_REVIVE_ICON` ($87)
    spell_select_revive_icon:
        pla
        ldy board.data__curr_board_row
        cpy #$08 // Max 8 icons in dead icon list
        bcs !return-
        lda data__dead_icon_offset_list,y
        cmp #DEAD_ICON_SLOT_UNUSED
        beq !return-
        sta common.param__icon_type_list
        asl game.flag__is_destination_valid
        rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 67A0
    // Location of used spell arrays for each player
    ptr__player_used_spell_list:
        .word data__light_used_spells_list, data__dark_used_spell_list

    // 67A4
    // Spell cast function pointers.
    ptr__spell_cast_fn_list:
        .word spell_select_teleport, spell_select_heal, spell_select_shift_time, spell_select_exchange
        .word spell_select_elemental, spell_select_revive, spell_select_imprison, spell_select_cease

    // 87AC
    // Spell action function pointers. Actions are used to allow the player to select board squares or icons.
    ptr__spell_action_fn_list:
        .word spell_select_icon, spell_select_square, spell_select_player_icon, spell_select_challenge_icon
        .word spell_select_charmed_square, spell_select_opposing_icon, spell_select_free_player_icon
        .word spell_select_revive_icon

    // 8B8C
    // Spell name message string IDs.
    ptr__spell_string_id_list:
        .byte STRING_TELEPORT, STRING_HEAL, STRING_SHIFT_TIME, STRING_EXCHANGE, STRING_SUMMON_ELEMENTAL
        .byte STRING_REVIVE, STRING_IMPRISON, STRING_CEASE
}

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

//---------------------------------------------------------------------------------------------------------------------
// Private data.
.namespace private {
    // 6AFD
    // ID of used elemental. Used to ensure opposing player will generate a unique elemental.
    data__used_elemental_id: .byte $00
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BD0E
// Is 0 for spell caster not selected, $80 for selected and +$80 for selected spell.
idx__selected_spell: .byte $00

// BEFA
// Flags used to keep track of spells used by each player.
// Spells are in order: teleport, heal, shift time, exchange, summon elemental, revive, imprison.
data__light_used_spells_list: .byte $00, $00, $00, $00, $00, $00, $00
data__dark_used_spell_list: .byte $00, $00, $00, $00, $00, $00, $00

// BF23
// Count of number of used spells for a specific player.
data__used_spell_count: .byte $00

// BF30
// Current board row.
cnt__board_row: .byte $00

// BF31
// Current board column.
cnt__board_col: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BD3A
    // Current selected spell ID.
    data__curr_spell_id: .byte $00

    // BD53
    // Temporary current row storage.
    data__curr_board_row: .byte $00

    // BD54
    // Temporary current column row storage.
    data__curr_board_col: .byte $00

    // BD66
    // Pointer to function to execute selected spell logic.
    prt__spell_fn: .word $0000

    // BD71
    // Temporary message ID storage.
    flag__is_new_square_selected: .byte $00

    // BD7B
    // Creen row counter used to keep track of the row while drawing the dead icon list.
    cnt__screen_row: .byte $00

    // BE7F
    // List of unique dead icon offsets.
    data__dead_icon_offset_list: .byte $00, $00, $00, $00, $00, $00, $00, $00

    // BE87
    // List of unique dead icon types.
    data__dead_icon_type_list: .byte $00, $00, $00, $00, $00, $00, $00, $00

    // BF1A
    // Generic temporary data storage area.
    data__temp_storage: .byte $00

    // BF22
    // Is TRUE if a surrounding square is valid for movement or magical spell.
    flag__is_valid_square: .byte $00

    // BF23
    // Index used to acces an item within the dead icon array.
    idx__dead_icon: .byte $00

    // BF24
    // Number of dead icons in the dead icon list.
    data__dead_icon_count: .byte $00

    // BF2E
    // First selected icon to exchange.
    data__exchange_source_icon: .byte $00

    // BF32
    // Counter used to delay selection of next/previous spell. Must be held for a count of #$0F before selection is
    // changed.
    cnt__select_next_delay: .byte $00

    // BF43
    // Screen offset for start of graphical memory for dead icon list display.
    data__screen_mem_offset: .byte $00
}
