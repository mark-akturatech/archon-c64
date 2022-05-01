.filenamespace ai
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used for AI in board and challenge game play.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 6D3C
// Determine the piece, action and destination for the current turn.
calculate_move:
	lda #(FLAG_ENABLE/2)
	sta private.flag__is_piece_selected
	//
	// Determine if AI should cast a spell.
	// Y=current player (0 or 1)
	// X=Player piece (wizard or sourceress)
	ldy #$00
	ldx #WIZARD
	lda game.data__ai_player_ctl
	bpl !next+
	iny
	ldx #SORCERESS
!next:
	sty game.data__player_offset
	// Ignore caster if dead or imprisoned.
	lda game.data__piece_strength_list,x
	beq !skip_caster+
	txa
	cmp game.data__imprisoned_icon_list,y
	beq !skip_caster+
	// Configure spell list pointer for current player and opposing player.
	tya
	asl
	tay
	lda magic.ptr__player_used_spell_list,y
	sta VARPNT
	lda magic.ptr__player_used_spell_list+1,y
	sta VARPNT+1 // Current player spell list
	tya
	eor #%0000_0011 // Change #2 to #0 and vice versa (swap player offset)
	tay
	lda magic.ptr__player_used_spell_list,y
	sta OLDLIN
	lda magic.ptr__player_used_spell_list+1,y
	sta OLDLIN+1 // Opposing player spell list
	txa
	jsr private.get_piece_position
	sta private.idx__selected_piece_board_row
	sty private.idx__selected_piece_board_col
	lda private.idx__square_offset
	sta private.idx__selected_piece_square_offset
	//
	ldx #(NUM_SPELLS-1) // 0 offset
	stx private.idx__selected_spell
!spell_loop:
	ldy private.data__spell_check_priority_list,x // Spell check order preference
	lda (VARPNT),y
	cmp #SPELL_USED
	beq !next_spell+
	jsr private.check_cast_spell
	lda private.flag__is_piece_selected
	bpl !next_spell+
	// Spell selected. Store the selected piece and location.
	asl private.flag__is_piece_selected
	lda #WIZARD_OFFSET
	ldy game.data__ai_player_ctl
	bpl !next+
	lda #SORCERESS_OFFSET
!next:
	// Store selected move.
	sta common.param__icon_offset_list
	lda private.idx__selected_piece_board_row
	sta private.idx__piece_destination_board_row
	ldy private.idx__selected_piece_board_col
	sty private.idx__piece_destination_board_col
	jmp complete_turn
!next_spell:
	dec private.idx__selected_spell
	ldx private.idx__selected_spell
	bpl !spell_loop-
!skip_caster:
	//
// ...
// 6FB0
complete_turn: // TODO
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
    // 7512
    // Calls the spell check function for the specified spell.
    // Requires:
    // - X: Contains the spell priority index (see `data__spell_check_priority_list`)
    // Sets:
    // - flag__is_piece_selected: Set > $80 if spell selected
    check_cast_spell:
        txa
        asl
        tay
        lda ptr__spell_check_fn_list,y
        sta ptr__check_ai_move
        lda ptr__spell_check_fn_list+1,y
        sta ptr__check_ai_move+1
        jmp (ptr__check_ai_move)

    // 7524
    // Determine if the AI should cast the imprison spell.
    check_cast_imprison:
        rts

    // 76D6
    // Determine if the AI should cast the shift time spell.
    check_cast_shift_time:
        rts // TODO

    // 7752
    // Determine if the AI should cast the summon elemental spell.
    check_cast_summon_elemental:
        rts // TODO

    // 7796
    // Determine if the AI should cast the teleport spell.
    check_cast_teleport:
        rts // TODO

    // 7905
    // Determine if the AI should cast the exchange spell.
    // Hint: never :)
    check_cast_exchange:
        rts

    // 7906
    // Determine if the AI should cast the revive spell.
    check_cast_revive:
        rts // TODO

    // 799E
    // Determine if the AI should cast the heal spell.
    check_cast_heal:
        rts // TODO

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
    ptr__spell_check_fn_list:
        .word check_cast_heal, check_cast_revive, check_cast_exchange, check_cast_teleport
        .word check_cast_summon_elemental, check_cast_shift_time, check_cast_imprison

    // 721F
    // List of occupancy score preferences for each square on the board. The higher the number, the more desirable the
    // location.
    data__square_occupancy_preference_list:
        .const PREF = $28
        .byte PREF+0, PREF+0, PREF+0, PREF+1, PREF+5, PREF+1, PREF+0, PREF+0, PREF+0
        .byte PREF-1, PREF+0, PREF+0, PREF+1, PREF+2, PREF+1, PREF+0, PREF+0, PREF-1
        .byte PREF+0, PREF+0, PREF+0, PREF+1, PREF+2, PREF+1, PREF+0, PREF+0, PREF+0
        .byte PREF+0, PREF+0, PREF+1, PREF+1, PREF+2, PREF+1, PREF+1, PREF+0, PREF+0
        .byte PREF+6, PREF+0, PREF+0, PREF+1, PREF+5, PREF+1, PREF+0, PREF+0, PREF+6
        .byte PREF+0, PREF+0, PREF+1, PREF+1, PREF+2, PREF+1, PREF+1, PREF+0, PREF+0
        .byte PREF+0, PREF+0, PREF+0, PREF+1, PREF+2, PREF+1, PREF+0, PREF+0, PREF+0
        .byte PREF-1, PREF+0, PREF+0, PREF+1, PREF+2, PREF+1, PREF+0, PREF+0, PREF-1
        .byte PREF+0, PREF+0, PREF+0, PREF+1, PREF+5, PREF+1, PREF+0, PREF+0, PREF+0        
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BF16
// AI aggression adjustment used to adjust the challenge move strategy.
data__challenge_aggression_score: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BD28
    // Board row of piece selected by AI.
    idx__selected_piece_board_row: .byte $00

    // BD29
    // Board column of piece selected by AI.
    idx__selected_piece_board_col: .byte $00

    // BD30
    // Pointer to the routine for testing the current move for selection by the AI.
	ptr__check_ai_move: .word $0000

    // BD37
    // Board square offset of piece selected by AI.
    idx__selected_piece_square_offset: .byte $00

    // BD3A
    // Index of selected spell within data__spell_check_priority_list to check for casting.
    idx__selected_spell: .byte $00

    // BD64
    // Flag is set TRUE if the AI prefers to move to a magic square. This will be the case if either player occupies
    // all bar the last magic square.
    flag__prefer_magic_square_destination: .byte $00

    // BD65
    // Is TRUE if the game if the end of game strategy should be used. This strategy is activated when one or both of
    //  the playes has 5 or less pieces.
    flag__end_of_game_strategy: .byte $00

    // BE5B
    // Destination board row of piece selected by AI. TODO: this could be wrong.
    idx__piece_destination_board_row: .byte $00

    // BE6D
    // Destination board column of piece selected by AI. TODO: this could be wrong.
    idx__piece_destination_board_col: .byte $00

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

    // BF32
    // Dark remaining icon count.
    cnt__dark_icons: .byte $00

    // BF36
    // Light remaining icon count.
    cnt__light_icons: .byte $00
}
