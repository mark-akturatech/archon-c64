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
    lda main.temp.data__temp_store_1
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
    lda #POST_SPELL_HEAL_ID
    jsr select_icon_for_spell
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
get_selected_spell: // TODO
    rts

// 6CAA
spell_select_cease:
    lda #STRING_SPELL_DONE
    jmp cancel_spell_selection

// 6CAF
spell_abort: // TODO
    rts

// 6CDC
select_icon_for_spell: // TODO
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
// - `main.temp.data__temp_store_1`: Number of used spells.
// Preserves:
// - X
count_used_spells:
    txa
    pha
    lda #$00
    sta main.temp.data__temp_store_1
    ldx #$07
!loop:
    lda flag__light_used_spells,y
    cmp #SPELL_USED
    bne !next+
    inc main.temp.data__temp_store_1
!next:
    iny
    dex
    bne !loop-
    pla
    tax
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

// BEFA
// Flags used to keep track of spells used by light player.
// Spells are in order: teleport, heal, shift time, exchange, summon elemental, revive, imprison.
flag__light_used_spells: .byte $00, $00, $00, $00, $00, $00, $00

// BF01
// Flags used to keep track of spells used by dark player.
// Spells are in order: teleport, heal, shift time, exchange, summon elemental, revive, imprison.
flag__dark_used_spells: .byte $00, $00, $00, $00, $00, $00, $00
