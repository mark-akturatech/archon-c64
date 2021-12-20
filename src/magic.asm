.filenamespace magic

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for selecting and casting spells within the game.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Game

// 67B4
select_spell:
    // Store current piece location to restore location if the spell is aborted.
    lda main.temp.data__curr_icon_row
    sta temp_row_store
    lda main.temp.data__curr_icon_col
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
    lda main.temp.data__used_spell_count
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
    sty main.temp.data__curr_spell_id
    jsr board.clear_text_area
    ldy main.temp.data__curr_spell_id
    lda data.spell_string_id,y
    ldx #$0A
    jsr board.write_text
    ldy main.temp.data__curr_spell_id
    cpy #SPELL_END
    beq !next+
    lda #SPELL_USED
    sta (CURLIN),y
!next:
    // Cast spell.
    tya
    asl
    tay
    lda data.spell_cast_fn_ptr,y
    sta main.temp.dynamic_fn_ptr
    lda data.spell_cast_fn_ptr+1,y
    sta main.temp.dynamic_fn_ptr+1
    jmp (main.temp.dynamic_fn_ptr)
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
spell_select_teleport: // TODO
    rts

// 6899
spell_select_heal:
    lda #STRING_HEAL_WHICH
    sta game.message_id
    jsr game.display_message
    lda #$00
    sta game.curr_icon_total_moves
    lda #ACTION_SELECT_PLAYER_ICON
    jsr initiate_spell_action
    ldx board.icon.type
    ldy board.icon.init_matrix,x
    lda board.icon.init_strength,y
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
    lda main.state.curr_phase
    eor #$FF
    sta main.state.curr_phase
    lda #STRING_REVERED_TIME
    bpl end_spell_selection

// 68D1
spell_select_exchange: // TODO
    rts

// 6AFE
spell_select_elemental: // TODO
    rts

// 693F
spell_select_revive: // TODO
    rts

// 6ABA
spell_select_imprison: // TODO
    rts


// 6BD4
// Description:
// - Select spell from list of spells.
// Sets:
// - Y: Spell ID
get_selected_spell:
    lda #$00
    sta main.temp.data__temp_store // Selected spell
    sta main.temp.data__hold_delay_count // Delay before repeat while holding down up/down
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
    sta main.temp.data__hold_delay_count
    ldy main.temp.data__temp_store
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
    dec main.temp.data__hold_delay_count
    lda main.temp.data__hold_delay_count
    and #$0F
    bne !return+
get_previous_spell:
    lda main.temp.data__temp_store
    sec
    sbc #$01
    bpl !next+
    lda #$07 // Wrap back to last spell
!next:
    sta main.temp.data__temp_store
    tay
    cpy #SPELL_END
    beq display_spell // Don't check if spell is used if cease casting option selected
    lda (CURLIN),y
    cmp #SPELL_USED
    beq get_previous_spell
    bne display_spell
!return:
    rts
select_next_spell:
    inc main.temp.data__hold_delay_count
    lda main.temp.data__hold_delay_count
    and #$0F
    cmp #$0F
    bne !return-
get_next_spell:
    lda main.temp.data__temp_store
    clc
    adc #$01
set_selected_spell:
    cmp #$08
    bcc !next+
    lda #$00 // Wrap back to first spell
!next:
    sta main.temp.data__temp_store
    tay
    cpy #SPELL_END // Cease casting?
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
    cpx #(CHARS_PER_SCREEN_ROW + CHARS_PER_SCREEN_ROW)
    bcc !loop-
    // Display the name of the spell.
    ldx #(CHARS_PER_SCREEN_ROW + 10)
    ldy main.temp.data__temp_store
    lda data.spell_string_id,y
    jsr board.write_text
    rts

// 6CAA
spell_select_cease:
    lda #STRING_SPELL_DONE
    jmp cancel_spell_selection

// 6CAF
// Abort current spell and return back to spell selection.
spell_abort:
    ldx #$60 // ~1.5 sec
    jsr common.wait_for_jiffy
    jsr config_used_spell_ptr
    ldy main.temp.data__curr_spell_id
    lda #SPELL_UNUSED // Re-enable spell
    sta (CURLIN),y
    jsr board.clear_text_area
    ldx #$00
    lda #STRING_SPELL_CANCELED
    jsr board.write_text
    lda temp_row_store
    sta main.temp.data__curr_icon_row
    lda temp_column_store
    sta main.temp.data__curr_icon_col
    ldx #$40 // ~1 sec
    jsr common.wait_for_jiffy
    jmp select_spell_start

// 6CDC
initiate_spell_action: // TODO
    rts

// 6D16
// Description:
// - Set cell occupancy.
// Prerequisites:
// - A: Column offset of board matrix cell.
// - Y: Row offset of board matrix cell.
// - X: Icon ID.
// Sets:
// - `game.curr_square_occupancy`: Sets appropriate byte within the occupancy array.
set_occupied_cell:
    pha
    lda game.data.row_occupancy_lo_ptr,y
    sta OLDLIN
    lda game.data.row_occupancy_hi_ptr,y
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
// - `main.temp.data__used_spell_count`: Number of used spells.
// Preserves:
// - X
count_used_spells:
    txa
    pha
    lda #$00
    sta main.temp.data__used_spell_count
    ldx #$07
!loop:
    lda flag__light_used_spells,y
    cmp #SPELL_USED
    bne !next+
    inc main.temp.data__used_spell_count
!next:
    iny
    dex
    bne !loop-
    pla
    tax
    rts

// 87BC
// Allows the player to select a cell or icon to cast the spell on to. Some spells (eg transport) require multiple
// selections. Others require selection of current player icon (eg heal), opposing player icon (eg imprison) or
// any icon (eg exchange) or location (eg transport destination). 
// After the action is completed, the selected icon type will be added to the stack or $80 if empty cell selected.
select_spell_destination:
    pha
    txa
    and #$0F // Remove $80 flag
    // Set spell action dynamic function.
    asl
    tax
    lda data.spell_action_fn_ptr,x
    sta main.temp.dynamic_fn_ptr
    lda data.spell_action_fn_ptr+1,x
    sta main.temp.dynamic_fn_ptr+1
    pla
    pha
    bpl check_valid_square
    lda game.curr_icon_total_moves
    beq !next+
check_valid_square:
    lda main.temp.data__curr_board_row
    sta main.temp.data__curr_row
    lda main.temp.data__curr_board_col
    sta main.temp.data__curr_column
    jsr board.test_magic_square_selected
    lda main.temp.flag__icon_destination_valid
    bmi spell_abort_magic_square
!next:
    jmp (main.temp.dynamic_fn_ptr)
spell_abort_magic_square:
    pla
    lsr main.temp.flag__icon_destination_valid // Invalid selection
    lda #(FLAG_ENABLE + STRING_CHARMED_PROOF)
    bmi spell_end_turn

// 87F6
// Allow player to select any non-imprisoned icon piece on the board.
// Action command: `ACTION_SELECT_ICON` ($80)
spell_select_icon:
    pla
    bmi !return+ // Unoccupied cell selected
    cmp board.icon.type
    beq !return+
    sta board.icon.type
spell_check_icon_is_free:
    cmp game.imprisoned_icon_id
    beq !next+
    cmp game.imprisoned_icon_id+1
    beq !next+
    asl main.temp.flag__icon_destination_valid
!return:
    rts
!next:
    // Show icon imprisoned message and restart turn
    lda #(FLAG_ENABLE + STRING_ICON_IMPRISONED)
spell_end_turn:
    sta game.flag__new_square_selected
    lda #FLAG_ENABLE
    sta main.interrupt.flag__enable
    rts

// 881A
// Allow player to select any cell on the board.
// Action command: `ACTION_SELECT_CELL` ($81)
spell_select_cell:
    pla
    jmp game.check_icon_destination

// 881E
// Allow player to select any of the current player icons.
// Action command: `ACTION_SELECT_PLAYER_ICON` ($82)
spell_select_player_icon:
    pla
    bmi !return- // Unoccupied cell selected
    sta board.icon.type
    tay
    lda board.icon.init_matrix,y
    eor game.state.flag__is_light_turn
    and #$08
    bne !return- // Not current player icon
    asl main.temp.flag__icon_destination_valid
    rts

// 8833
// Allow player to select any opposing player and initiate a challenge.
// Action command: `ACTION_SELECT_CHALLENGE_ICON` ($83)
spell_select_challenge_icon:
    pla
    bmi !return- // Unoccupied cell selected
    jmp game.check_icon_destination

// 8839
// Allow player to select a square surrounding the spell caster (charmed sqaure).
// Action command: `ACTION_SELECT_CHARMED_CELL` ($84)
spell_select_charmed_cell:
    pla
    bpl !return- // Occupied cell selected
    // Check if selected square is immediately above or below the spell caster.
    ldy main.temp.data__curr_board_row
    cpy main.temp.data__curr_icon_row
    beq !next+
    dey
    cpy main.temp.data__curr_icon_row
    beq !next+
    iny
    iny
    cpy main.temp.data__curr_icon_row
    bne !return+
!next:
    // Check if selected square is immediately to the left or right of the spell caster.
    ldy main.temp.data__curr_board_col
    cpy main.temp.data__curr_icon_col
    beq !next+
    dey
    cpy main.temp.data__curr_icon_col
    beq !next+
    iny
    iny
    cpy main.temp.data__curr_icon_col
    bne !return+
!next:
    jsr board.add_icon_to_matrix
    asl main.temp.flag__icon_destination_valid
!return:
    rts

// 886D
// Allow player to select an opposing icon. Turn ends after selection (non challenge).
// Action command: `ACTION_SELECT_OPPOSING_ICON` ($85)
spell_select_opposing_icon:
    pla
    bmi !return- // Unoccupied cell selected
    sta board.icon.type
    tay
    lda board.icon.init_matrix,y
    eor game.state.flag__is_light_turn
    and #$08
    beq !return- // Not opposing player icon
    asl main.temp.flag__icon_destination_valid
!return:
    rts

// 8882
// Allows player to select any current player icons that are not imprisoned.
// Action command: `ACTION_SELECT_FREE_PLAYER_ICON` ($86)
spell_select_free_player_icon:
    pla
    bmi !return- // Unoccupied cell selected
    sta board.icon.type
    tay
    lda board.icon.init_matrix,y
    eor game.state.flag__is_light_turn
    and #$08
    bne !return- // Not current player icon
    lda board.icon.type
    jmp spell_check_icon_is_free

// 8899
// Allows player to select an icon from a list of dead icon to revive.
// Action command: `ACTION_SELECT_REVIVE_ICON` ($87)
spell_select_revive_icon:
    pla
    ldy main.temp.data__curr_board_row
    cpy #$08 // Max 8 icons in dead icon list
    bcs !return-
    lda curr_dead_icons,y
    cmp #DEAD_ICON_SLOT_UNUSED
    beq !return-
    sta board.icon.type
    asl main.temp.flag__icon_destination_valid
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
    // Spell action function pointers. Actions are used to allow the player to select board cells or icons.
    spell_action_fn_ptr:
        .word spell_select_icon, spell_select_cell, spell_select_player_icon, spell_select_challenge_icon
        .word spell_select_charmed_cell, spell_select_opposing_icon, spell_select_free_player_icon
        .word spell_select_revive_icon

    // 8B8C
    // Spell name message string IDs.
    spell_string_id:
        .byte STRING_TELEPORT, STRING_HEAL, STRING_SHIFT_TIME, STRING_EXCHANGE, STRING_SUMMON_ELEMENTAL
        .byte STRING_REVIVE, STRING_IMPRISON, STRING_CEASE
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
//
.segment DynamicData
// BD0E
curr_spell_cast_selection: .byte $00 // Is 0 for spell caster not selected, $80 for selected and +$80 for selected spell

// BD53
temp_row_store: .byte $00 // Temporary current row storage

// BD54
temp_column_store: .byte $00 // Temporary current column row storage

// BE7F
curr_dead_icons: .byte $00, $00, $00, $00, $00, $00, $00, $00 // List of unique dead icon types.

// BEFA
// Flags used to keep track of spells used by light player.
// Spells are in order: teleport, heal, shift time, exchange, summon elemental, revive, imprison.
flag__light_used_spells: .byte $00, $00, $00, $00, $00, $00, $00

// BF01
// Flags used to keep track of spells used by dark player.
// Spells are in order: teleport, heal, shift time, exchange, summon elemental, revive, imprison.
flag__dark_used_spells: .byte $00, $00, $00, $00, $00, $00, $00
