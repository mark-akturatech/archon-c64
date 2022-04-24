.filenamespace ai
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used for AI in board and challenge game play.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 6D3C
calculate_move: // TODO
    rts

// 7A1D
cast_magic_spell: // TODO
    rts

// 7AA1
select_teleport_destination:
    rts

// 7D8E
configure_challenge: // TODO
    rts

// 82E5
// This logic is inline in the original source. We split it out here so that the logic can be included in the AI
// file.
select_piece:
    rts

// 8560
board_cursor_to_icon: // TODO
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Private routines.
.namespace private {
    // 79D9
    // Find row and column of a specified icon.
    // Requires:
    // - A: icon ID of peice to find the position for
    // Sets:
    // - X, idx__square_offset: square index of found icon
    // - Y, idx__board_row: board row of found icon
    // - A, idx__board_col: board column of found icon
    get_piece_position:
        sta data__selected_icon_id
        // Find the square occupied by the spell caster.
        ldx #(BOARD_SIZE-1) // 0 offset
    !loop:
        cmp board.data__square_occupancy_list,x
        beq !next+
        dex
        bpl !loop-
    !next:
        txa
        sta idx__square_offset
        // Find board row and column.
        // This is done by adding subtracting 9 (number of board columns) from the index until the index is less than 0.
        // Each time we subtract we increment the row counter. The column is then determined by adding 9 again to the
        // total. eg if say 15, we subtract 9 (row 0) and then subtract 9 again (row 1 and  result is -3). Row is 1 as we 
        // add 9 back, so column is 6.
        ldy #$00
    !loop:
        sec
        sbc #BOARD_NUM_COLS
        bcc !next+
        iny
        bcs !loop-
    !next:
        adc #BOARD_NUM_COLS
        sta idx__board_col
        sty idx__board_row
        rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
    .namespace private {
        
    // 6D27
    // Spell check priority list (reverse order).
    data__spell_check_priority_list:
        .byte SPELL_ID_HEAL, SPELL_ID_REVIVE, SPELL_ID_EXCHANGE, SPELL_ID_TELEPORT
        .byte SPELL_ID_SUMMON_ELEMENTAL, SPELL_ID_SHIFT_TIME, SPELL_ID_IMPRISON

    // 6D2E
    // Spell check subroutine index.
    // ptr__spell_check_fn_list:
    //     .byte #<check_cast_heal, #>check_cast_heal, #<check_cast_revive, #>check_cast_revive
    //     .byte #<check_cast_exchange, #>check_cast_exchange, #<check_cast_teleport, #>check_cast_teleport
    //     .byte #<check_cast_summon_elemental, #>check_cast_summon_elemental
    //     .byte #<check_cast_shift_time, #>check_cast_shift_time
    //     .byte #<check_cast_imprison, #>check_cast_imprison
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BD28
    // Board row of piece selected by AI.
    idx__selected_piece_board_row: .byte $00

    // BD29
    // Board column of piece selected by AI.
    idx__selected_piece_board_col: .byte $00

    // BD37
    // Board square offset of piece selected by AI.
    idx__selected_piece_square_offset: .byte $00

    // BE87
    // ID of icon currently being processed by the AI algorithms.
    data__selected_icon_id: .byte $00
    
    // BF1A
    // Square offset of current icon.
    idx__square_offset: .byte $00

    // BF22
    // Flag is set if the AI routine has selected a piece for movement or spell to cast.
    flag__is_piece_selected: .byte $00

    // BF30
    // Current board row.
    idx__board_row: .byte $00

    // BF31
    // Current board column.
    idx__board_col: .byte $00
}
