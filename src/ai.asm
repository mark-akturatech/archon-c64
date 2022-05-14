.filenamespace ai
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used for AI in board and challenge game play.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 6D3C
// Determine the piece, action and destination for the current turn.
calculate_move:
	lda #(FLAG_ENABLE/2)
	sta private.flag__selected_move
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
	sta private.idx__selected_piece_source_row
	sty private.idx__selected_piece_source_col
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
	lda private.flag__selected_move
	bpl !next_spell+
	// Spell selected. Store the selected piece and location.
	asl private.flag__selected_move
	lda #WIZARD_OFFSET
	ldy game.data__ai_player_ctl
	bpl !next+
	lda #SORCERESS_OFFSET
!next:
	// Store selected move.
	sta common.param__icon_offset_list
	lda private.idx__selected_piece_source_row
	sta private.data__player_destination_row_list
	ldy private.idx__selected_piece_source_col
	sty private.data__player_destination_col_list
	jmp complete_turn
!next_spell:
	dec private.idx__selected_spell
	ldx private.idx__selected_spell
	bpl !spell_loop-
!skip_caster:
    //
	// 6DC2
	// Calculate player move.
    // This is done as follows:
    // - First we count the number of players each side. If the game is in end game (ie 5 or less pieces) we
    //   increase challenge agression based on the additional number of players the AI has. We also look at whether
    //   each side occupies 4 of the 5 magic squares and if so, we set a flag to prefer a challenge on a magic square.
    // - We then calculate the defend score. This score is based off the current square color, whether the square is
    //   magic, whether we are defending a spell caster home square and whether the square has strategic value.
    // - Finally we adjust the defend score up by adding an offensive score to it. The offensive score is determined
    //   by testing if attacking an opponent will likely result in a win or a piece move will occupy a square of
    //   greater strategic value.
    // Each piece will have a resulting score for a single movement (from source to destination). The pieces with the
    // highest score (there may be 1 to many) are aggregated and one piece is selected from random from the resulting
    // list. This is the piece we move.
    // Note this is quite complex as each piece can move to multiple squares. Therefore each peice will test movement
    // to each square with only the movement resulting in the highest score for that piece kept. Movement is also
    // complex for each piece as we might not be able to move to specific squares if other pieces are in the way.
    // Therefore, be warned - there is a fair bit code required to determine the best score.
	lda #FLAG_DISABLE
	sta data__challenge_aggression_score
	sta private.data__curr_highest_move_score
	sta private.cnt__active_ai_pieces
	sta private.cnt__light_icons
	sta private.cnt__dark_icons
	sta private.flag__end_of_game_strategy
	// Count number of alive player pieces on each side.
	ldx #(BOARD_SIZE-1) // 0 offset
!loop:
	lda board.data__square_occupancy_list,x
	bmi !next+
	cmp #MANTICORE // First dark icon
	bcs !found_dark_icon+
	inc private.cnt__light_icons
	bpl !next+
!found_dark_icon:
	inc private.cnt__dark_icons
!next:
	dex
	bpl !loop-
	// Set end of game strategy flag. This flag is set if either player has 5 or less pieces.
    .const END_GAME_PIECE_COUNT = 5
	lda private.cnt__dark_icons
	cmp #END_GAME_PIECE_COUNT
	bcc !low_num_pieces+
	lda private.cnt__light_icons
	cmp #END_GAME_PIECE_COUNT
	bcs !check_magic_square_occupancy+
!low_num_pieces:
	stx private.flag__end_of_game_strategy // Sets flag used to adjust strategy for end of game
	// Set challenge agression score used to adjust the aggression strategy.
	// The agression is based on the difference between the AI and opposing player piece count. The agression is
	// higher depending on how many more pieces the AI has. The value becomes negative if the opposing player has
	// more pieces reducing the aggression.
	lda game.data__ai_player_ctl
	bpl !ai_is_light+
	lda private.cnt__dark_icons
	sec
	sbc private.cnt__light_icons
	sta data__challenge_aggression_score
	jmp !check_stalemate_condition+
!ai_is_light:
	lda private.cnt__light_icons
	sec
	sbc private.cnt__dark_icons
	sta data__challenge_aggression_score
	//
	// Set stalemate counter if not already set. The counter is set if both players have 3 or less players and will 
	// count down after each turn. It will expire if 12 turns complete without a challenge occurring. The counter
	// is reset after a challenge has completed.
!check_stalemate_condition:
	lda game.cnt__stalemate_moves
	bne !check_magic_square_occupancy+
	lda private.cnt__light_icons
    .const STALEMATE_PIECE_COUNT = 3
	cmp #STALEMATE_PIECE_COUNT
	bcs !check_magic_square_occupancy+
	lda private.cnt__dark_icons
	cmp #STALEMATE_PIECE_COUNT
	bcs !check_magic_square_occupancy+
	// Count down from $FC to $F0. We can AND with $0F to check if expired. We use +$F0 so we can tell the difference
	// between an expired counter and a counter that hasn't been set (ie is set to $00).
    .const STALEMATE_MOVE_COUNT = 12
	lda #($F0 + STALEMATE_MOVE_COUNT)
	sta game.cnt__stalemate_moves
	//
	// Count number of dark and light icons occupying the magic squares. The game is won if all squares are occupied
	// so this will be used by the selection strategy and challenge aggression.
!check_magic_square_occupancy:
	lda #FLAG_DISABLE
	sta private.cnt__light_icons
	sta private.cnt__dark_icons
	sta private.flag__prefer_magic_square_destination
	ldx #(BOARD_NUM_MAGIC_SQUARES-1) // 0 offset
!loop:
	ldy game.data__magic_square_offset_list,x
	lda board.data__square_occupancy_list,y
	bpl !found_icon+
	jmp !next+
!found_icon:
	cmp #MANTICORE // First dark icon
	bcc !found_light_icon+
	inc private.cnt__dark_icons
	bpl !next+
!found_light_icon:
	inc private.cnt__light_icons
!next:
	dex
	bpl !loop-
	// Set game startegy flag to occupy a magic square to win or prevent loss of the game.
	lda private.cnt__dark_icons
	cmp #(BOARD_NUM_MAGIC_SQUARES-1)
	bne !check_light+
	beq !prefer_magic_square+
!check_light:
	lda private.cnt__light_icons
	cmp #(BOARD_NUM_MAGIC_SQUARES-1)
	bne !get_player_score+
!prefer_magic_square:
	lda #FLAG_ENABLE_FF
	sta private.flag__prefer_magic_square_destination
	//
	// Find location of each AI player and calculate defending score of player based on the square color and whether
	// the square is magic.
!get_player_score:
	ldx #(BOARD_SIZE-1) // 0 offset
!square_loop:
	ldy board.data__square_occupancy_list,x
	bmi !next_square+
	// Test if square is occupied by current AI player. Clever little check - the piece icon offset ($0-7 light and
	// $8-F dark) exclusive ored with AI control ($55 for light and $aa for dark) and anded with 8 will result in 0
	// only if the icon offset is for a light piece and the AI player is light or the offset is a dark piece and the AI
	// player is dark. 
	lda board.data__piece_icon_offset_list,y
	eor game.data__ai_player_ctl
	and #0000_1000
	bne !next_square+
	// AI player piece found. Ensure is not imprisoned.
	tya
	ldy game.data__player_offset
	cmp game.data__imprisoned_icon_list,y
	beq !next_square+
	// Store player locations.
	ldy private.cnt__active_ai_pieces
	sta private.data__player_piece_list,y
	txa
	sta private.data__player_square_idx_list,y
	// Set player color score
	jsr private.set_score__square_color
	// Adjust player score if player on defending caster magic square. The score is adjusted based on the number of
	// spells cast as the square is depleted after each spell cast.
	lda #$00
	sta magic.data__used_spell_count
	lda game.flag__is_light_turn
	bmi !check_dark+
	cpx #BOARD_WIZARD_MAGIC_SQUARE_IDX
	bne !next+
	ldy #$00 // Count light player spells
	beq !count_spells+
!check_dark:
	cpx #BOARD_SOURCERESS_MAGIC_SQUARE_IDX
	bne !next+
	ldy #$07 // Count dark player spells
!count_spells:
	jsr magic.count_used_spells
	lsr magic.data__used_spell_count // Score is half of number of uncast spells
!next:
	// Adjust score if the player resides on a magic square.
	jsr private.set_score__magic_square
	// Adjust score based on strategic importance of the square.
	ldy private.cnt__active_ai_pieces
	lda private.data__square_occupancy_preference_list,x
	sec
    // This magic number ensures that defending a strategic square has less score than challenging for a
    // strategic square. Setting the value lower will result in an AI that rarely challenges. Setting higher
    // will result in a more aggressive AI.
    .const STATEGY_SQUARE_DEFEND_REDUCTION = $1E
	sbc #STATEGY_SQUARE_DEFEND_REDUCTION
	// Adjust for defending caster magic square
	sbc magic.data__used_spell_count
	clc
	adc private.data__derived_score_adj
	// Store the resulting defending score for each player piece.
	sta private.data__player_score_list,y
	inc private.cnt__active_ai_pieces
!next_square:
	dex
	bpl !square_loop-
    //
	// Calculate movement scores. Previous score only contains a score calculated on whether the piece should defend
	// the square they are currently on. Here we determine if the piece should move or challenge to obtain a strategic
	// advantage.
	ldx private.cnt__active_ai_pieces
	dex
	stx private.data__temp_curr_count // Current active piece index
!piece_loop:
	lda #$00
	sta private.data__derived_player_score
	lda private.data__player_square_idx_list,x
	// Find board row and column of square index for the current piece.
	// This is done by adding subtracting 9 (number of board columns) from the index until the index is less than 0.
	// Each time we subtract we increment the row counter. The column is then determined by adding 9 again to the
	// total. eg if say 15, we subtract 9 (row 0) and then subtract 9 again (row 1 and result is -3). Row is 1 as we 
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
	sta private.idx__selected_piece_source_row
	sty private.idx__selected_piece_source_col
	// Configure paramaters for the score calculation routine.
	ldy private.data__player_piece_list,x
	lda game.data__piece_strength_list,y
	sta private.data__temp_store_1
	lda board.data__piece_icon_offset_list,y
	tay
	lda game.data__icon_strength_list,y
	sta private.param__piece_initial_strength
	sec
	sbc private.data__temp_store_1
	sta private.param__piece_lost_strength
	// Calculate score. The score is calculate based ona movement square around the piece. The square is treated
	// differently if the piece can fly, hence the call a different subroutine that initially sets up the movement
	// square before calculating the score.
	lda game.data__icon_num_moves_list,y
	bmi !check_for_fly+
	jsr private.get_score_walking_piece
	jmp !next+
!check_for_fly:
	jsr private.get_score_flying_piece
!next:
	// Update player score.
	ldx private.data__temp_curr_count
	lda private.data__derived_player_score 
	sta private.data__player_score_list,x
	// Record the heighest calculated score. The highest score is sued to determine which move to make.
	cmp private.data__curr_highest_move_score
	bcc !skip+
	sta private.data__curr_highest_move_score
!skip:
	dec private.data__temp_curr_count
	dex
	bmi !select_move+
	jmp !piece_loop-
	//
	// Here we move all the pieces with the highest matching score to the start of various lists and keep a count of
	// the number of pieces. This action will overwrite the lower scores at the start of the list, but at this point
	// we don't care as we are only interested in the highest scores now.
	// A random move will be selected if more than one move matches the highest score.
!select_move:
	ldy #$FF // Starts at FF so that first move will rollover to 00 giving us a zero offset count
	ldx #$00
!loop:
	lda private.data__player_score_list,x
	cmp private.data__curr_highest_move_score
	bne !next+
	iny
	lda private.data__player_piece_list,x
	sta private.data__player_piece_list,y
	lda private.data__player_square_idx_list,x
	sta private.data__player_square_idx_list,y
	lda private.data__player_destination_row_list,x
	sta private.data__player_destination_row_list,y
	lda private.data__player_destination_col_list,x
	sta private.data__player_destination_col_list,y
!next:
	inx
	cpx private.cnt__active_ai_pieces
	bne !loop-
	// Select a move from the new list of maximum score moves. If only one move was copied we select that one,
	// otherwise we select a single random move from the list.
	// We do this by rounding down the random number to the number of moves. Random numbers are always generated
	// between 0 and FF. To round down we do the following:
	// - If number moves > 8: And #$0F to round the number between 0 and 16.
	// - If number moves < 8 but > 4: And #$07 to round the number between 0 and 7.
	// - If number moves < 4: And #$03 to round the number between 0 and 3.
	// If the rounded number is still too high (eg we could have 12 moves and the random number is 14) then we
	// regenerate another random number and try again until we find a number that works.
	tya
	beq !set_move+
!loop:
	lda RANDOM
	cpy #$08
	bcc !next+
	and #$0F // Random number now between 0 and 16
	bpl !check+
!next:
	cpy #$04
	bcc !next+
	and #$07 // Random number now between 0 and 7
	bpl !check+
!next:
	and #$03 // Random number now between 0 and 3
!check:
	sta private.data__temp_store_2
	cpy private.data__temp_store_2
	bcc !loop-
	lda private.data__temp_store_2 // This line is not needed
	// Retrieve the selected move from the list and store it.
!set_move:
	tax // A holds the index to the selected move within the move storage lists
	ldy private.data__player_piece_list,x
	lda board.data__piece_icon_offset_list,y
	sta common.param__icon_offset_list // Selected piece
	lda private.data__player_destination_row_list,x
	sta private.idx__selected_piece_destination_row
	lda private.data__player_destination_col_list,x
	sta private.idx__selected_piece_destination_col
	stx private.idx__selected_move
	lda private.data__player_square_idx_list,x
	stx private.flag__selected_move
	// Derive row and column from the selected move board square index.
	ldy #$00
!loop:
	sec
	sbc #BOARD_NUM_COLS
	bcc !next+
	iny
	bcs !loop-
!next:
	adc #BOARD_NUM_COLS
	sta private.idx__selected_piece_source_row
	sty private.idx__selected_piece_source_col
	//
	// 6FB0
complete_turn:
    // Store selected peice sprite position used for initial location of the ai movement animation.
	ldx #$04 // Special code used by `convert_coord_sprite_pos` used to not set sprite position registers
	jsr board.convert_coord_sprite_pos // A=Sprite X pos, Y=Sprite Y pos
	// The above method sets the position of the sprite within the square. However the AI uses the position to
	// display the selection square and therefore the calculated coordinates need to be slightly adjusted to
	// display the square at the correct location.
	sec
	sbc #$02
    sta private.data__sprite_curr_x_pos
	tya
	sec
	sbc #$01
    sta private.data__sprite_curr_y_pos
    // Configure the animation path from current location to selected destination.
	ldy common.param__icon_offset_list
	lda game.data__icon_num_moves_list,y
	bmi !return+ // Icon can fly
	sta private.param__piece_number_moves
	jsr private.find_path_to_destination
	lda private.idx__selected_move
	sta private.flag__selected_move // Restore flag as it is modified by above subroutine
!return:
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
    // 6FD7
    get_score_walking_piece:
        rts // TODO:

    // 7041
    get_score_flying_piece:
        rts // TODO:

    // 71C7
    // Adjusts player score if the player destination is a magic square and the magic square preference flag is
    // set.
    // Requires:
    // - X: Board square index of the square to test
    // Sets:
    // - data__derived_score_adj: Adds $06 to the score adjustment if the board square is a magic square.
    set_score__magic_square:
        lda flag__prefer_magic_square_destination
        beq !return+
        ldy #(BOARD_NUM_MAGIC_SQUARES-1) // 0 offset
        txa
    !loop:
        cmp game.data__magic_square_offset_list,y
        beq !found_magic_square+
        dey
        bpl !loop-
    !return:
        rts
    !found_magic_square:
        lda #$06 // Score adjustment
        clc
        adc data__derived_score_adj
        sta data__derived_score_adj
        rts

    // 71E2
    // Calculates player score adjustment for a specific square on the board. The score is derived using the
    // the current square color.
    // Requires:
    // - X: Board square index of the square to test
    // Sets:
    // - data__derived_score_adj: Contains the derived score based on player and square color
    set_score__square_color:
        // Get square score. The score is $00 (dark) to $0E (light). The score is anwhere in between for varying
        // color based upon the current phase. See `game.data__phase_cycle`. The score counts up in steps of 2.
        lda board.data__board_square_color_list,x
        beq !next+ // Dark square color
        bmi !vary_square+ // Varying square color
        lda #$0E // Maximum color score
        bpl !next+
    !vary_square:
        lda game.data__phase_cycle_board
        and #$0F
    !next:
        lsr // Halve score to 0 to 7
        sta data__derived_score_adj
        lda game.data__ai_player_ctl
        bpl !return+
        // Invert score if player is dark. Therefore the a dark player on a black square will have score of 7
        // and a dark player on a white square will have a score of 0.
        lda #$07
        sec
        sbc data__derived_score_adj
        sta data__derived_score_adj
    !return:
        rts

    // 7282
    find_path_to_destination:
        rts // TODO:     

    // 7512
    // Calls the spell check function for the specified spell.
    // Requires:
    // - X: Contains the spell priority index (see `data__spell_check_priority_list`)
    // Sets:
    // - flag__selected_move: Set > $80 if spell selected
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
    // BD15
    // Current y position of the selected piece sprite.
    data__sprite_curr_y_pos: .byte $00

    // BD17
    // Current x position of the selected piece sprite.
    data__sprite_curr_x_pos: .byte $00
    
    // BD28
    // Source board row of piece selected by AI.
    idx__selected_piece_source_row: .byte $00

    // BD29
    // Source board column of piece selected by AI.
    idx__selected_piece_source_col: .byte $00

    // BD2E
    // Temporary counter.
    data__temp_curr_count: .byte $00

    // BD2E
    // Index of move selected by the AI algorithm used to index move data lists.
    idx__selected_move: .byte $00

    // BD2D
    // Number of active AI player pieces found (excludes dead and imprisoned pieces).
    cnt__active_ai_pieces: .byte $00

    // BD2F
    // Derived player score. The score is the current defensive score adjusted up for offensive actions such as
	// moving towards a strategic square or challenging an opponent piece.
    data__derived_player_score: .byte $00

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

    // BE25
    // List of AI player pieces found while scanning the player board.
    data__player_piece_list: .fill BOARD_NUM_PLAYER_PIECES, $00

    // BD2B
    // Maximum number of moves for current piece.
    param__piece_number_moves: .byte $00

    // BE37
    // Board square index of each AI player piece. The array is ordered in the same order as `data__player_piece_list`.
    data__player_square_idx_list: .fill  BOARD_NUM_PLAYER_PIECES, $00

    // BE49
    // AI player derived score for each piece. The array is ordered in the same order as `data__player_piece_list`.
    data__player_score_list: .fill  BOARD_NUM_PLAYER_PIECES, $00

    // BE5B
    // Derived destination row for each AI player piece. The array is ordered in the same order as
    // `data__player_piece_list`.
    data__player_destination_row_list: .fill  BOARD_NUM_PLAYER_PIECES, $00

    // BE6D
    // Derived destination column for each AI player piece. The array is ordered in the same order as
    // `data__player_piece_list`.
    data__player_destination_col_list: .fill  BOARD_NUM_PLAYER_PIECES, $00

    // BD72
    // Lost strength of current piece used when calculating movement score.
    param__piece_lost_strength: .byte $00

    // BD73
    // Initial strength of current piece used when calculating movement score.
    param__piece_initial_strength: .byte $00

    // BE87
    // ID of icon currently being processed by the AI algorithms.
    data__selected_icon_id: .byte $00
    
    // BF1A
    // Square offset of current icon.
    idx__square_offset: .byte $00

    // BF22
    // This is a special double meaning flag. If >=$80 then the selected move as a spell. If <$80 then the selected
    // move was a piece movement and the flag contains the index of the movement used to access the movement
    // parameters from the move lists (see `data__player_piece_list`).
    flag__selected_move: .byte $00

    // BF23
    // Temporary storage.
    data__temp_store_1: .byte $00

    // BF2F
    // Derived player score adjustment. Is used to determine the score of a derived movemement based on variables
    // such as whether the destination square has a color score adjustment or whether the square is a magic square.
    data__derived_score_adj: .byte $00

    // BF2F
    // Temporary storage.
    data__temp_store_2: .byte $00

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
   
    // BF3A
    // Destination board row for piece selected by AI.
    idx__selected_piece_destination_row: .byte $00

    // BF3B
    // Destination board column for piece selected by AI.
    idx__selected_piece_destination_col: .byte $00

    // BF42
    // Current maximum calculated movement score. Used to determine if the calculated move has a higher score than the
    // current selected move.
    data__curr_highest_move_score: .byte $00 
}
