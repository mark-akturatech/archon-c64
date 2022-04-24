.filenamespace challenge
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used during challenge and battle erena game play.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 7ACE
entry:
    // Redraw the board with only the challenge icons.
    jsr board.clear_text_area
    lda #FLAG_ENABLE
    sta board.param__render_square_ctl // Render only the current square when drawing the board
    jsr board.draw_board
    ldx #(1*JIFFIES_PER_SECOND)
    jsr common.wait_for_jiffy
    //
    sei
    lda #<main.play_challenge
    sta main.ptr__raster_interrupt_fn
    lda #>main.play_challenge
    sta main.ptr__raster_interrupt_fn+1
    cli
    // Configure sprites.
    lda #EMPTY_SPRITE_BLOCK
    sta SPTMEM+1
    sta SPTMEM+2
    sta SPTMEM+3
    sta SPTMEM+7
    jsr common.clear_mem_sprite_24
    jsr common.clear_mem_sprite_48
    jsr common.clear_mem_sprite_56_57
    lda #%0000_0011 // Icons multicolor, weapons/projectiles single color
    sta SPMC
    lda XXPAND
    and #%1111_1100 // Icons standard height, weapons/projectiles expanded in X direction
    sta XXPAND
    lda #%0000_0000 // No icons expanded in Y direction
    sta YXPAND
    //
    // Get the color of the square being challenged. This will be used to set the strength of the challenging
    // pieces. The logic below will generate a number from 0 to 7, where 0 is if square is black, 7 if square is
    // white and 2 to 6 depending on the current phase (with 2 being darkest phase and 6 being the lightest phase).
    // The number is then added to the strength of the piece as follows:
    // - Dark piece: Adds 7-strength (so if on white it adds 0, if on black adds 7)
    // - Light piece: Adds strength (so if on white it adds 7, black it adds 0)
    // Therefore a pieces strength will increase by up to 7 depending upon the color or phase of the challenged square.
    ldy board.data__curr_board_row
    sty board.data__curr_icon_row
    lda board.ptr__color_row_offset_lo,y
    sta CURLIN
    lda board.ptr__color_row_offset_hi,y
    sta CURLIN+1
    ldy board.data__curr_board_col
    sty board.data__curr_icon_col
    lda (CURLIN),y
    sta private.data__curr_square_color_code // Color of the square - Not used
    // Get the battle square color (a) and a number between 0 and 7 (y). 0 is strongest on black, 7 is strongest on
    // white.
    beq !dark_square+
    bmi !vary_square+
    ldy #$07
    lda board.data__board_player_square_color_list+1 // White
    bne !next+
!dark_square:
    ldy #$00
    lda board.data__board_player_square_color_list // Black
    beq !next+
!vary_square:
    lda game.data__phase_cycle_board
    lsr
    tay
    lda game.data__phase_color // Phase color
!next:
    sta private.param__arena_color // Square color used to set battle arena border
    tya
    asl
    sta private.data__strength_adj_x2 // ??? Not used?
    sty private.data__strength_adj
    iny
    sty private.data__strength_adj_plus1 // ??? Not used?
    // Set A with light piece and Y with dark piece.
    lda common.param__icon_type_list
    ldy game.data__challenge_icon
    bit game.flag__is_light_turn
    bpl !next+
    ldy common.param__icon_type_list
    lda game.data__challenge_icon
!next:
    //
    // Configure battle pieces
    sta common.param__icon_type_list
    tax
    lda board.data__piece_icon_offset_list,x
    sta common.param__icon_offset_list
    sty common.param__icon_type_list+1
    lda board.data__piece_icon_offset_list,y
    tay
    cpy #SHAPESHIFTER_OFFSET // Shapeshifter?
    bne !next+
    ldy common.param__icon_offset_list // Set dark icon type to same as light icon
!next:
    sty common.param__icon_offset_list+1
    //
    ldx #(NUM_PLAYERS-1) // 0 offset
    // Create sprites at original coordinates on board. This will allow us to do the animation where the sprites slide
    // in to battle position.
!player_loop:
    // Create sprite group.
    jsr common.initialize_sprite
    lda #BYTES_PER_ICON_SPRITE
    sta common.param__sprite_source_len
    jsr common.add_sprite_set_to_graphics
    // Place the sprite at the challenge square.
    lda board.data__curr_board_col
    ldy board.data__curr_board_row
    jsr board.convert_coord_sprite_pos
    // Configure player.
    ldy common.param__icon_offset_list,x
    lda private.data__icon_attack_speed_list,y
    sta private.data__player_sprite_speed_list,x
    lda private.data__icon_attack_damage_list,y
    sta private.data__player_attack_damage_list,x
    // Configure icon weapon/projectile.
    tya
    asl
    tay
    lda private.ptr__weapon_sprite_mem_offset_list,y
    sta common.ptr__sprite_source_lo_list+2,x
    lda private.ptr__weapon_sprite_mem_offset_list+1,y
    sta common.ptr__sprite_source_hi_list+2,x
    //
    // Configure piece strength. The strength is adjusted by the square color they are fighting on. Shapeshifters
    // will obtain the initial full strength of the icon they are fighting, unless the shapeshifter is fighting an
    // elemental, in which case the strength is set to 10.
    ldy common.param__icon_type_list,x
    lda board.data__piece_icon_offset_list,y
    cmp #SHAPESHIFTER_OFFSET
    bne !not_shape_shifter+
    // Set Shape Shifter strength. Set to 10 if challenging an elemental, otherwise assume challenge icon initial
    // strength.
    ldy common.param__icon_offset_list
    cpy #AIR_ELEMENTAL_OFFSET
    bcc !skip+
    ldy #SHAPESHIFTER_OFFSET
!skip:
    lda game.data__icon_strength_list,y
    bne !adj_dark+ // Skip the player check as we know we are a dark player as Shape Shifter is only available to dark
!not_shape_shifter:
    lda game.data__piece_strength_list,y
    cpy #AIR_ELEMENTAL
    bcs !skip_adj+ // Don't adjust strength for elementals
    // Adjust strength. Remember the adjustment is the additional amount the light gains, so is 0 on a black square and
    // 7 on a light square. So if the number is 2, light will gain 2 strength and dark will gain 5 (7-2).
    cpx #$01 // Dark player?
    bne !adj_light+
!adj_dark:
    clc
    adc #$07
    sec
    sbc private.data__strength_adj // 7 - color strength adjustment
    jmp !adj_magic+
!adj_light:
    clc
    adc private.data__strength_adj // 0 + color strength adjustment
    // Add negative strength adjustment when defending a players magic square.
!adj_magic:
    jsr private.magic_square_strength_adj
    sec
    sbc magic.data__used_spell_count
!skip_adj:
    sta private.data__player_attack_strength_list,x
    //
    // Configure the icon sprite color.
    ldy common.param__icon_offset_list,x
    cpy #PHOENIX_OFFSET
    bne !set_color+
    // Enable sprite 3 multicolor for phonex attack animation. X is always 0 here.
    lda SPMC
    ora private.data__sprite_offset_bit_list,x
    sta SPMC
    lda common.data__player_icon_color_list,x
    bpl !skip+
!set_color:
    lda private.data__icon_weapon_color_list,y
!skip:
    sta SP2COL,x
    // Reset variables.
    lda #FLAG_DISABLE
    sta game.cnt__stalemate_moves // Reset stalemate counter
    sta private.data__player_weapon_sprite_speed_list,x
    sta game.data__icon_speed,x
    sta private.cnt__player_cooldown_delay_list,x
    // Set icons speed.
    lda common.param__icon_offset_list,x
    cmp #EARTH_ELEMENTAL_OFFSET
    beq !set_slow_speed+
    and #%0001_0111
    cmp #$03 // Tests if icon is Golem or Troll
    bne !skip+
!set_slow_speed:
    lda #ICON_SLOW_SPEED
    sta game.data__icon_speed,x
!skip:
    // Configure sound.
    jsr board.get_sound_for_icon
    ldy common.param__icon_offset_list,x
    lda private.idx__sound_attack_pattern,y
    tay
    lda board.prt__sound_icon_effect_list,y
    sta private.ptr__player_attack_pattern_lo_list,x
    lda board.prt__sound_icon_effect_list+1,y
    sta private.ptr__player_attack_pattern_hi_list,x
    jsr board.set_icon_sprite_location
    //
    // Next player.
    dex
    bmi !next+
    jmp !player_loop-
!next:
    //
    // 7C4C
    lda #LEFT_FACING_ICON_FRAME
    sta common.param__icon_sprite_source_frame_list+1 // Default dark player to left facing
    lda #FLAG_DISABLE
    sta common.flag__is_complete // Flag will be set to exit arena when battle is complete
    // Create weapon/projectile sprites
    ldx #$02
!loop:
    // Each weapon/projectile comprises 8 bytes. There are 4 sprite frames that are rotated to create sprites for each
    // direction. Up and down direction use the same sprite.
    lda #BYTES_PER_WEAPON_SPRITE
    sta common.param__sprite_source_len
    jsr common.add_sprite_set_to_graphics
    inx
    cpx #$04
    bcc !loop-
    // Disable weapon/projectile sprites by default (they'll be enabled when one is shot)
    lda #%0000_1111
    ora SPENA
    sta SPENA
    lda private.data__icon_weapon_color_list+PHOENIX_OFFSET // Set color of Phoenix fire
    sta SPMC1
    jsr private.set_multicolor_screen
    jsr common.clear_screen
    jsr private.set_arena_colors
    // Set sprite starting positions. They will be animated from the current square to the starting position.
    lda #$19
    sta private.data__sprite_initial_x_pos_list
    lda #$7B
    sta private.data__sprite_initial_x_pos_list+1
    lda #$58
    sta private.data__sprite_initial_y_pos_list
    lda #$68
    sta private.data__sprite_initial_y_pos_list+1
    // Set player starting location.
    jsr private.set_player_sprite_location
    ldx #(1.5*JIFFIES_PER_SECOND)
    jsr common.wait_for_jiffy
    jsr common.clear_screen
    //
    lda #BLACK
    sta BGCOL0
    //
    // The challenge arena has a small character set at $6000
    lda #%0001_1000 // +$2000-$20FF char memory, +$0400-$07FF screen memory
    sta VMCSB
    //
    // Draw arena border.
    // Top border (row 1).
    lda #<SCNMEM
    sta FREEZP+2
    lda #>SCNMEM
    sta FREEZP+3
    .const NUM_HORIZONTAL_BORDERS = 3 // 2 x Top and 1 x bottom border
    ldx #(NUM_HORIZONTAL_BORDERS-2) // 0 offset
!border_loop:
    ldy #(NUM_SCREEN_COLUMNS-1) // 0 offset
!row_loop:
    .const BORDER_CHARACTER = $05
    lda #BORDER_CHARACTER // It's not great loading A every time within the loop.
    sta (FREEZP+2),y
    dey
    bpl !row_loop-
    dex
    bmi !next+
    beq !bottom_border+
    lda FREEZP+2
    clc
    adc #NUM_SCREEN_COLUMNS // Next screen row
    sta FREEZP+2
    bcc !border_loop-
    inc FREEZP+3
    jmp !border_loop-
    // Bottom border (rows 24 and 25).
!bottom_border:
    lda #<(SCNMEM+(NUM_SCREEN_ROWS-1)*NUM_SCREEN_COLUMNS)
    sta FREEZP+2
    lda #>(SCNMEM+(NUM_SCREEN_ROWS-1)*NUM_SCREEN_COLUMNS)
    sta FREEZP+3
    jmp !border_loop-
!next:
    // Side border (columns 1 and 40).
    ldx #(NUM_SCREEN_ROWS-2)
    lda #<(SCNMEM+NUM_SCREEN_COLUMNS)
    sta FREEZP+2
    lda #>SCNMEM
    sta FREEZP+3
!border_loop:
    ldy #$00
    lda #BORDER_CHARACTER
    sta (FREEZP+2),y // Left border
    ldy #(NUM_SCREEN_COLUMNS-1)
    sta (FREEZP+2),y // Right border
    lda FREEZP+2
    clc
    adc #NUM_SCREEN_COLUMNS
    sta FREEZP+2
    bcc !next+
    inc FREEZP+3
!next:
    dex
    bne !border_loop-
    //
    // Set single color mode for first character on each row.
    // This is so we can use the same character to represent current strength on both sides. Left side has
    // multicolor off and therefore will display as green, right side has multicolor on and will display as blue.
    ldx #(NUM_SCREEN_ROWS-1) // 0 offset
    lda #<COLRAM
    sta FREEZP+2
    lda #>COLRAM
    sta FREEZP+3
!loop:
    ldy #$00
    lda (FREEZP+2),y
    and #%1111_1000
    ora #%0000_0111 // Turn off multicolor bit
    sta (FREEZP+2),y
    lda FREEZP+2
    clc
    adc #NUM_SCREEN_COLUMNS
    sta FREEZP+2
    bcc !next+
    inc FREEZP+3
!next:
    dex
    bne !loop-
    // Set default secondary color to blue.
    lda common.data__player_icon_color_list+1
    sta BGCOL2
    // Set player starting positions.
    lda private.data__arena_sprite_x_boundary_list
    sta private.data__sprite_initial_x_pos_list
    lda private.data__arena_sprite_x_boundary_list+1
    sta private.data__sprite_initial_x_pos_list+1
    jsr private.set_player_sprite_location
    //
    // Cofigure barrier initial states.
    // A barrier is an obstacle within the battle arena that is either impermeable or slows down the icon.
    // The magic numbers set the starting phase of three cycles used to control barrier states.
    lda #FLAG_DISABLE
    sta game.flag__phase_direction_list
    sta game.flag__phase_direction_list+1
    lda #FLAG_ENABLE_FF
    sta game.flag__phase_direction_list+2
    lda #$00
    sta game.data__phase_cycle
    lda #$08
    sta game.data__phase_cycle+1
    lda #$0A
    sta game.data__phase_cycle+2
    jsr private.initialize_barriers
    //
    // Count the number of pieces remaining on both sides. Used by AI algorithm.
	lda #$00
	sta private.data__piece_count_list
	sta private.data__piece_count_list+1
	ldx #$01 // dark player
	ldy #(BOARD_TOTAL_NUM_PIECES-1) // 0 offset
!loop:
	lda game.data__piece_strength_list,y
	beq !skip+
	inc private.data__piece_count_list,x
!skip:
	dey
	bmi !next+
	cpy #(BOARD_NUM_PLAYER_PIECES-1) // Check if now up to light player pieces (0 offset)
	bne !loop-
	dex // light player
	beq !loop-
!next:
    //
	// Determine if challenging for a magic square. Sets an offset (presumably aggresiveness) to 0 for non-magic and
	// 3 for magic square. Used by AI Algorithm.
	lda board.data__curr_board_row
	sta magic.idx__board_row
	lda board.data__curr_board_col
	sta magic.idx__board_col
	jsr magic.test_magic_square_selected
	lda #FLAG_DISABLE
	bit game.flag__is_destination_valid
	bmi !skip+
	lda #$03
!skip:
	sta private.data__magic_square_aggression
	//
	ldx #$00
	lda game.data__ai_player_ctl
	beq !skip+
	// Configure challenge for AI player.
	// This code is inline in the original source. We move it out here so that all AI can be split in to a single
	// file.
	// 7D8E - 7DF5
	jsr ai.configure_challenge
!skip:
    //
    lda #$00
	// Initialize sprite variables.
	ldx #(NUMBER_CHALLENGE_SPRITES-1) // 0 offset
!loop:
	// 7DFA 9D 36 BF sta private.data__piece_count_list,x // TODO: ?? why - Used by AI? DEF need last 2 cleared tho
	// 7DFD 9D 32 BF sta temp_data__dark_piece_count,x // TODO: ?? why - Used by AI? DEF need last 2 cleared tho
	sta board.cnt__sprite_frame_list,x
	dex
	bpl !loop-
	// Initialize player variables.
	ldx #(NUM_PLAYERS-1) // 0 offset
!loop:
	sta private.flag__did_player_weapon_hit_list,x
	// 7E0B 9D 6C BD sta WBD6C,x // TODO: ?? Used for AI somehow
	dex
	bpl !loop-
	// Initialize timers.
	sta TIME+2
	sta TIME+1
	sta private.date__curr_time
	// Initialize collision registers.
	// The registers are cleared when they are read.
	lda SPSPCL
	lda SPBGCL
	//
	jsr game.wait_for_state_change
    // ---------------------------------------------------
    // Challenge complete
    // ---------------------------------------------------
    //
    // Default to no winner. The winner is set to the winning icon type a little lower down.
    lda #FLAG_ENABLE 
	sta private.data__winning_icon_type
	// Remove weapon/projectile sprites.
	lda #EMPTY_SPRITE_BLOCK
	sta SPTMEM+2
	sta SPTMEM+3
	lda #$00
	sta YXPAND
	//
	// Update strength data of winning and losing pieces.
	ldx #(NUM_PLAYERS-1) // 0 offset
!player_loop:
	ldy common.param__icon_type_list,x
	cpy #AIR_ELEMENTAL
	bcc !skip+
	// Remove elemental sprite and don't bother updating the strength data.
	lda #EMPTY_SPRITE_BLOCK
	sta SPTMEM,x
	lda #SPRITE_Y_OFFSCREEN
	sta board.data__sprite_curr_y_pos_list,x
	jmp !next+
!skip:
	// Update piece strength.
	lda private.data__player_attack_strength_list,x
	bne !alive+
	// Player was defeated.
	tya
	cmp game.data__imprisoned_icon_list,x
	bne !skip+
	lda #FLAG_ENABLE_FF
	sta game.data__imprisoned_icon_list,x // Remove defeated piece from prison (in case the piece is later revived)
!skip:
	lda #SPRITE_Y_OFFSCREEN
	sta board.data__sprite_curr_y_pos_list,x
	lda #$00 // Set player strength data to 0 - dead
	beq !update_strength+
!alive:
	// Player is victor.
	sty private.data__winning_icon_type
	cmp game.data__piece_strength_list,y
	bcs !next+ // Victor won without taking any damage - no need to update strength
	pha
	// If victor is a Shapeshifter, then reset the shapeshifter strength back to initial strength. This is interesting,
	// Shapeshifter always restores full strength after each battle.
	lda board.data__piece_icon_offset_list,y
	cmp #SHAPESHIFTER_OFFSET
	bne !skip+
	pla
	lda game.data__icon_strength_list,y
	bpl !update_strength+
!skip:
	pla
!update_strength:
	sta game.data__piece_strength_list,y
!next:
	dex
	bpl !player_loop-
    // Set location of winning square on the board. 
	lda private.data__winning_icon_type
	sta common.param__icon_type_list
	ldy board.data__curr_icon_row
	sty board.data__curr_board_row
	lda board.data__curr_icon_col
	sta board.data__curr_board_col
	ldx #$04
	jsr board.convert_coord_sprite_pos
	// Add the piece back on to the board (both pieces were removed when the battle started).
	pha // X position of square
	tya
	pha // Y position of square
	jsr board.add_icon_to_matrix
	jsr private.remove_barriers
	//
	ldx #JIFFIES_PER_SECOND
	jsr common.wait_for_jiffy
	ldx #$00
	lda common.param__icon_type_list
	bpl !animate_sprite+
	// Draw - just return to the game.
	pla
	pla
	jmp !return+
	//
!animate_sprite:
	// Animate the victor sprite to the winning square location.
	ldy #$00
	cmp #MANTICORE
	bcc !skip+
	ldy #LEFT_FACING_ICON_FRAME
	inx
!skip:
	lda #$00
	sta board.cnt__sprite_frame_list,x
	tya
	sta common.param__icon_sprite_source_frame_list,x
	// Store the final position of teh victor.
	pla // Y position of square
	sta private.data__sprite_initial_y_pos_list,x
	pla // X position of square
	sta private.data__sprite_initial_x_pos_list,x
	// Store the final position of the loser (off screen)
	txa
	eor #$01
	tax
	lda #SPRITE_Y_OFFSCREEN
	sta private.data__sprite_initial_y_pos_list,x
	jsr private.set_player_sprite_location
	//
!return:
	lda #%0001_0010
	sta VMCSB // +$0000-$07FF char memory, +$0400-$07FF screen memory (game board character set)
	// Clear the screen. We do this by first clearing the screen with the victor icon still shown for 1 second and then
	// removing the victor icon for 0.5 seconds (showing a blank screen).
	lda EXTCOL
	and #$0F
	sta private.param__arena_color
	jsr common.clear_screen
	jsr private.set_arena_colors
	ldx #(1*JIFFIES_PER_SECOND)
	jsr common.wait_for_jiffy
	jsr board.draw_board
	lda #EMPTY_SPRITE_BLOCK
	sta SPTMEM
	sta SPTMEM+1
	ldx #(0.5*JIFFIES_PER_SECOND)
	jsr common.wait_for_jiffy
	// Go back to strategy game play.
	jmp game.entry

// 938D
interrupt_handler:
	lda common.flag__cancel_interrupt_state
	bmi !return+
	lda game.data__ai_player_ctl
	beq !next+
	lda common.flag__is_complete
	bpl !next+
	jsr common.stop_sound
!return:
	jmp common.complete_interrupt
!next:
	//
	// Update sprite locations. The sprite location is only updated if `data__player_sprite_speed_list` has a speed
    // set for the current sprite. For example, the projectiles will have a 0 speed when the projectile is not being
    // fired.
	ldx #(NUMBER_CHALLENGE_SPRITES-1) // 0 offset
!sprite_loop:
	cpx #(NUMBER_CHALLENGE_SPRITES/2) // Player sprite (first two sprites are player icons, last two are projectiles)
	bcc !update_player_location+
	lda private.data__player_sprite_speed_list,x
	beq !next+
!update_player_location:
	jsr board.set_icon_sprite_location
!next:
	dex
	bpl !sprite_loop-
	// Store sprite collision status.
	lda SPSPCL
	sta private.flag__sprite_to_sprite_collision
	lda SPBGCL
	sta private.flag__sprite_to_char_collision
    //
    // Draw strength bars for both players. The strength bar is a bar int he left border for light player and
	// right border for the dark player. The bar's height is dynamically calculated based on the amount of remaining
	// strength of each player.
	ldy #(NUM_SCREEN_COLUMNS-1) // Dark player column offset for strength bar
	ldx #(NUM_PLAYERS-1) // 0 offset
	.const STRENGTH_BAR_CHARACTER = $06 // Character code for character used by the strength bar for dark player
	lda #STRENGTH_BAR_CHARACTER
	sta private.cnt__strength_bar_character // Strength bar character is $06 for dark and $07 for light player
!player_loop:
	txa
	pha
	lda #(NUM_SCREEN_ROWS-1)
	sec
	sbc private.data__player_attack_strength_list,x
	sta private.data__curr_inverted_strength // inverted strength 0 for $18 strength, $18 for 0 strength.
	// Detect if one of the icons are dead. If so, we allow the game to continue for a few seconds to allow for
	// existing projectiles from the current player to complete (may hit the other player and end in a draw).
	cmp #(NUM_SCREEN_ROWS-1) // Icon dead?
	bne !next+
	// Delay end of game by allowing the game to continue with one icon until they delay has expired.
	lda private.cnt__end_game_delay
	bpl !continue+
    // Don't exit until the projectiles have finished moving.
	lda private.data__player_weapon_sprite_speed_list
	ora private.data__player_weapon_sprite_speed_list+1
	bne !next+
	lda #FLAG_ENABLE
	sta common.flag__cancel_interrupt_state
!continue:
	dec private.cnt__end_game_delay
!next:
	// Draw strength bars. Start at the bottom of the screen and draw up.
	lda private.cnt__strength_bar_character
	sta private.data__temp_storage
	ldx #(NUM_SCREEN_ROWS-2)
	lda #<(SCNMEM+NUM_SCREEN_COLUMNS*(NUM_SCREEN_ROWS-2))
	sta FREEZP+2
	lda #>(SCNMEM+NUM_SCREEN_COLUMNS*(NUM_SCREEN_ROWS-2))
	sta FREEZP+3
!bar_loop:
	cpx private.data__curr_inverted_strength
	bcs !show_bar_char+
	lda #BORDER_CHARACTER
	bne !skip+
!show_bar_char:
	lda private.data__temp_storage
!skip:
	sta (FREEZP+2),y
	lda FREEZP+2
	sec
	sbc #NUM_SCREEN_COLUMNS
	sta FREEZP+2
	bcs !next+
	dec FREEZP+3
!next:
	dex
	bpl !bar_loop-
	// Light player
	ldy #$00 // Set strength bar column location to first column
	inc private.cnt__strength_bar_character // Set character code to $07
	pla
	tax
	dex
	bpl !player_loop-    
    //
	// Detect if the sprite has collided with a barrier. If so, convert the sprite location to a screen location and
	// read the underlying character from the screen location to determine the barrier type and phase. For example, if
	// an icon hits a hard barrier, it will bounce off. If a projectile hits a translucent barrier, it will penetrate
	// though.
	// The formula used to determine the screen character location based off the sprite location is:
	// - column = 2*round((sprite_x_pos-4)/8)
	// - row = if sprite_y_pos < 16 then 0 else: round((sprite_y_pos-16)/16)
	// NOTE rounding will round up if the result of the division is has a remainder > 0.5
	// Once the column and row are determined, we can the read the character from screen memory. The character is then
	// converted to a phase using the follwing:
	// - phase = char_code/8 - 1
	// Remember that the barrier character codes of each phase are 8 apart and the first barrier starts at character
	// code 8.
	// A value of 0 is stored for the current sprite if no collision with a character has occurred.
	ldx #(NUMBER_CHALLENGE_SPRITES-1) // 0 offset
!sprite_loop:
	lda private.flag__sprite_to_char_collision
	and common.data__math_pow2_list,x
	beq !skip_collsion+ // No .collision
	// Calculate screen column.
	lda board.data__sprite_curr_x_pos_list,x
	sec
	sbc #$04
	lsr
	lsr
	lsr
	tay
	lsr
	bcc !skip+
	iny  // Round up
!skip:
	tya
	asl
	pha
	// Calculate screen row.
	lda board.data__sprite_curr_y_pos_list,x
	cmp #$10
	bcs !next+
	ldy #$00
	beq !skip+
!next:
	sec
	sbc #$10
	lsr
	lsr
	lsr
	lsr
	tay
	lsr
	bcc !skip+
	iny // Round up
!skip:
	// Read character from screen memory.
	lda private.ptr__screen_barrier_row_offset_lo,y
	sta FREEZP
	lda private.ptr__screen_barrier_row_offset_hi,y
	sta FREEZP+1
	pla
	tay
	lda (FREEZP),y
	// Convert character to phase (0-2)
	lsr
	lsr
	lsr
	tay
	dey
	// Store phase.
	lda private.flag__phase_state_list,y
!skip_collsion:
	sta private.data__sprite_barrier_phase_collision_list,x
	dex
	bpl !sprite_loop-
	//
	// Update barrier phase states ~ every 4 seconds. The barriers will phase through various colors. The third phase
	// will cycle between impermeable and permeable.
	lda TIME+1
	cmp private.date__curr_time
	beq !next+
	sta private.date__curr_time
	ldy #(NUM_BARRIER_TYPES-1) // 0 offset
!loop:
	jsr game.cycle_phase_counters
	dey
	bpl !loop-
	jsr private.update_barrier_state
!next:
	// Play icon sound. The routine uses `common.flag__is_player_sound_enabled` to determine if a sound is enabled
	// for each player. OLDTXT and OLDTXT+2 will be set to the sound pattern made by the specific player while
	// moving or firing. Note that when a player is firing, the player movement sound is replaced with the weopon
	// sound until the weapon has finished firing (eg hits a target, flies off the screen or finishes
	// thrusting etc). Therefore, only two voices (one for each player) are only ever used during a challenge.
	jsr board.play_icon_sound
	//
	ldx #(NUM_PLAYERS-1) // 0 offset
!player_loop:
	lda #FLAG_DISABLE
 	sta private.flag__was_icon_moved
	sta private.flag__is_weapon_active
	jsr private.update_activated_weapon // Continue firing (or thrusting) weapon
	//
	// Disallow a player from moving if the player has an active thrust weapon or the Phoenix is activated.
	lda private.data__player_icon_sprite_speed_list,x
	and #(ICON_CAN_TRANSFORM + ICON_CAN_THRUST)
	beq !next+ // Icon does not thrust or transform attack
	lda private.data__player_weapon_sprite_speed_list,x
	beq !next+ // Icon is currently not attacking
	lda common.param__icon_offset_list,x
	cmp #BANSHEE_OFFSET
	beq !next+ // Banshee transform attacks, however the Banshee is allowed to move while attacking
	jmp !move_complete+ // Don't update the player's position (ie hold in place while the attack is underway)
	//
!next:
	lda private.data__player_attack_strength_list,x
	bne !allow_move+
	jmp !skip_move+
!allow_move:
	// 
	lda private.data__sprite_barrier_phase_collision_list,x
	beq !no_barrier+
	bpl !permiable_barrier+
	jsr private.bounce_player_off_barrier
	lda game.data__ai_player_ctl
	beq !next+
	// 94C2 EC 26 BD cpx temp_data__curr_sprite_ptr // TODO: AI
	// 94C5 F0 31 beq !move_ai_player+
!next:
	jmp !skip_move+
!permiable_barrier:
	// Halve the player speed when traversing over a permiable barrier.
	lda private.cnt__icon_delay_list,x
	eor #$FF
!no_barrier:
	sta private.cnt__icon_delay_list,x
	beq !next+
	jmp !skip_move+
!next:
	// Slow down slow pieces (Troll, Golem, Earth Elemental). Here we skip the move every 4th move, effectively making
	// the player 3/4 the speed of every other player.
	lda game.data__icon_speed,x
	beq !check_move+ // Not a slow moving piece
	inc game.data__icon_speed,x
	lda game.data__icon_speed,x
	and #$03 // Will be true every 4th increment
	bne !check_move+
	lda #ICON_SLOW_SPEED
	sta game.data__icon_speed,x // Reset counter
	jmp !skip_move+
    //
	// Check joystick direction.
!check_move:
	lda game.data__ai_player_ctl
	beq !next+
	// 94F3 EC 26 BD cpx temp_data__curr_sprite_ptr
	// 94F6 D0 06 bne !next+
!move_ai_player:
	// 94F8 20 E3 9A jsr W9AE3 // TODO: AI
	jmp !move_complete+
!next:
	// Check joystick position.
	txa
	eor #$01
	tay
	lda CIAPRA,y
	pha // Current joystick status
	and #%0000_1000 // Joystick right
	bne !next+
	jsr private.check_player_right
	jmp !check_up_down+
!next:
	pla
	pha
	and #%0000_0100 // Joystick left
	bne !check_up_down+
	jsr private.check_player_left
!check_up_down:
	pla
	lsr // Joystick up
	pha
	bcs !next+
	jsr private.check_player_up
!next:
	pla
	lsr // Joystick down
	bcs !move_complete+
	jsr private.check_player_down
    //
    // 9528
!move_complete:
	lda private.flag__was_icon_moved
	bne !configure_sound+
	//
	// Reset player and turn off sound if player wasn't moved.
	// Reset animation frame.
	sta board.cnt__sprite_frame_list,x
	// Disable sound if sound was previously enabled.
	lda common.flag__is_player_sound_enabled,x
	beq !next+
	cmp #FLAG_ENABLE
	bne !next+
	lda #FLAG_DISABLE
	sta common.flag__is_player_sound_enabled,x 
	sta common.data__voice_note_delay,x
	txa
	asl
	tay
	lda common.ptr__voice_ctl_addr_list,y
	sta FREEZP+2
	lda common.ptr__voice_ctl_addr_list+1,y
	sta FREEZP+3
	lda #$00
	ldy #$04 // Voice contrrol register
	sta (FREEZP+2),y
!next:
	// Detect if fire button held and stop the player from moving it is.
	txa
	eor #$01
	tay
	lda CIAPRA,y
	and #%0001_0000 // Fire button
	bne !skip_move+
	// Check if icon is Phoenox or Banshee (type $06 or $0E) and if so initiate an attack.
	lda common.param__icon_offset_list,x
	and #$07
	cmp #$06
	bne !skip_move+ // Not banshee or phoenix
	jsr private.attack_player
	jmp !skip_move+
	//
	// Counfigure movement sound when movement is first detected.
!configure_sound:
	lda #FLAG_ENABLE
	cmp common.flag__is_player_sound_enabled,x
	beq !animate_movement+
	bcc !animate_movement+
	sta common.flag__is_player_sound_enabled,x
	lda #$00
	sta common.data__voice_note_delay,x
	txa
	asl
	tay
	lda board.ptr__player_sound_pattern_lo_list,x
	sta OLDTXT,y
	lda board.ptr__player_sound_pattern_hi_list,x
	sta OLDTXT+1,y
	// Increment the animation frame after every 4 pixels of movement.
!animate_movement:
	inc private.idx__icon_frame,x
	lda private.idx__icon_frame,x
	and #$03
	bne !skip_move+
	inc board.cnt__sprite_frame_list,x
	//
!skip_move:
	jsr private.configure_weapon
	// Decrement weapon cooldown timer if active.
	lda private.cnt__player_cooldown_delay_list,x
	beq !next+
	dec private.cnt__player_cooldown_delay_list,x
	bne !next+
	// Play recharge sound on player weapon cooldown timeout.
	lda #PLAYER_SOUND_RECHARGE
	cmp common.flag__is_player_sound_enabled,x
	bcc !next+
	sta common.flag__is_player_sound_enabled,x
	lda #$00
	sta common.data__voice_note_delay,x
	txa
	asl
	tay
	lda game.ptr__sound_game_effect_list,y
	sta OLDTXT,y
	lda game.ptr__sound_game_effect_list+1,y
	sta OLDTXT+1,y
!next:
	lda board.cnt__countdown_timer
	beq !next+
	// Set cooldown complete flag used by AI.
	txa
	eor #$01
	// 95CE 8D 26 BD sta temp_data__curr_sprite_ptr // TODO:
!next:
	dex
	bmi !next+
	jmp !player_loop-
!next:
	//
	// Set the Banshee weapon sprite frame to match the current direction of the Banshee.
	lda common.param__icon_offset_list+1
	cmp #BANSHEE_OFFSET
	bne !return+
	lda private.data__player_weapon_sprite_speed_list+1
	beq !return+
	lda common.param__icon_sprite_source_frame_list+1
	lsr
	lsr
	cmp #$03
	bcc !next+
	lda #$03
!next:
	sta common.param__icon_sprite_source_frame_list+3
	//
!return:
	jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Private routines.
.namespace private {
    // 649D
    // Move player sprites in to the starting battle location.
    // When moving the icons, the may need to move up or down or left or right depending upon the battle square and
    // the starting battle position.
    // Requires: 
    // - `data__sprite_curr_y_pos_list` and `data__sprite_curr_x_pos_list` will be already set to the current location
    //   of the sprites - on top of each other on the battle square.
    set_player_sprite_location:
        // OK here we set the 4th bit in a register. When a player sprite reaches the corrext X or Y position, the
        // register is shifted right. When the register reaches 0 we know both pieces are now at the corrext X and
        // Y position (as by then it would have been shifted 4 times). I can't work out why we don't just start with
        // #$03 and dec each time - maybe this is more efficient if you count clock cycles. But this isn't code that
        // needs to be highly optimized.
        lda #%0000_1000
        sta cnt__moves_remaining
        //
        ldx #(NUM_PLAYERS-1) // 0 offset
    !player_loop:
        // Adjust Y position
        lda board.data__sprite_curr_y_pos_list,x
        cmp data__sprite_initial_y_pos_list,x
        bcc !move_down+
        bne !move_up+
        lsr cnt__moves_remaining // At Y position
        jmp !next+
    !move_up:
        dec board.data__sprite_curr_y_pos_list,x
        jmp !next+
    !move_down:
        inc board.data__sprite_curr_y_pos_list,x
        // Adjust X position
    !next:
        lda board.data__sprite_curr_x_pos_list,x
        cmp data__sprite_initial_x_pos_list,x
        bcc !move_right+
        bne !move_left+
        lsr cnt__moves_remaining // At X position
        jmp !next+
    !move_left:
        dec board.data__sprite_curr_x_pos_list,x
        jmp !next+
    !move_right:
        inc board.data__sprite_curr_x_pos_list,x
    !next:
        jsr board.set_icon_sprite_location
        dex
        bpl !player_loop-
        // Add a short delay before each consecutive move (1/60th second).
        lda TIME+2
    !loop:
        cmp TIME+2
        beq !loop-
        // Keep moving to position if the sprites are not at the corretc position.
        lda cnt__moves_remaining
        beq !return+
        jmp set_player_sprite_location
    !return:
        rts

    // 65DE
    // Draws a set of random barriers and intializes timings for updating barrier states.
    // There are 3 types of barriers that use different character dot data and colors. Each barrier type has a maximum
    // of 6 barriers.
    // Once the barriers locations are initialized, they will not change locations throughout the entire battle. The
    // barriers though will slowly change phase through 4 cycles (three different character representations and off).
    // One phase will allow the character to pass over the barrier however the character will walk slower while doing
    // so.
    initialize_barriers:
        lda #NUM_BARRIER_TYPES
        sta cnt__barrier_cycle
        .const INITIAL_BARRIER_CHARACTER = 8 // Starting barrier character index for first barrier type
        lda #INITIAL_BARRIER_CHARACTER
        sta cnt__barrier_character
    !cycle_loop:
        .const NUM_BARRIERS_PER_PHASE = 6
        ldx #NUM_BARRIERS_PER_PHASE
        // Pick a random even number between $02 and $10. This will represent the column where the barrier is drawn.
        // BTW at first I thought the algorithm below may favor certain numbers but I must have too much time on my
        // hands because I wrote small Python script to generate a hundred thousand numbers and the distribution was
        // even.
    !barrier_type_loop:
        lda RANDOM
        and #%0001_1110 // Even numbers only and take first 5 bits ($10 requires 5 bits)
        beq !barrier_type_loop-
        cmp #$12
        bcs !barrier_type_loop-
        asl // Ensure there is space between the barriers
        sta idx__board_col
        // Pick a random even number between $00 and $0A. This will represent the row where the barrier is drawn.
    !loop:
        lda RANDOM
        and #%0000_1110
        cmp #$0B
        bcs !loop-
        sta idx__board_row
        // Draw the barrier on the screen.
        // A barrier comprises 4 characters (2 wide and 2 high). The draw routine updates the barrier character
        // counter as the barrier is drawn, so below we push the counter on to the stack and restore it again after
        // barrier has been drawn.
        lda cnt__barrier_character
        pha
        jsr draw_barrier
        pla
        sta cnt__barrier_character
        // Select another barrier location if the current location will overlap an existing barrier.
        lda flag__was_barrier_drawn
        bpl !barrier_type_loop-
        // Keep drawing barriers so that we have 6 barriers of the current barrier type.
        dex
        bne !barrier_type_loop-
        //
        // Select the starting barrier character for the next type of barrier.
        lda cnt__barrier_character
        clc
        .const NUM_CHARS_IN_BARRIER_GROUP = 8 // Each barrier type comprises 2 sets of 4 characters
        adc #NUM_CHARS_IN_BARRIER_GROUP
        sta cnt__barrier_character
        dec cnt__barrier_cycle
        bne !cycle_loop-
        //
        jmp update_barrier_state

    // 6629
    // Draw a single barrier character.
    // A barrier comprises 4 characters in a 2x2 grid.
    // Requires:
    // - idx__board_row: Screen row where barrier will be drawn.
    // - idx__board_col: Screen column where barrier will be drawn.
    // - cnt__barrier_character: Initial character id of character in top left position of the grid.
    // Sets:
    // - flag__was_barrier_drawn: TRUE if the barrier was drawn or FALSE an existing barrier already occupies the
    //   screen location.
    // - cnt__barrier_character: Updated to character id of character in bottom right position of the grid.
    // Preserves:
    // - X is purposely untouched
    draw_barrier:
        lda #(FLAG_ENABLE/2)
        sta flag__was_barrier_drawn // Default barrier drawn flag to off
        // Set the starting screen row of the barrier.
        ldy idx__board_row
        lda ptr__screen_barrier_row_offset_lo,y
        sta FREEZP+2
        lda ptr__screen_barrier_row_offset_hi,y
        sta FREEZP+3
        .const NUMBER_BARRIER_ROWS = 2
        lda #NUMBER_BARRIER_ROWS
        sta cnt__screen_row
    !row_loop:
        ldy idx__board_col
        lda (FREEZP+2),y
        bne !return+ // don't overwrite an existing barrier
        // Draw the barrier. Barriers comprise of 4 characters in a 2x2 grid.
        lda cnt__barrier_character
        sta (FREEZP+2),y
        iny
        inc cnt__barrier_character
        lda cnt__barrier_character
        sta (FREEZP+2),y
        inc cnt__barrier_character
        // Next row.
        lda FREEZP+2
        clc
        adc #NUM_SCREEN_COLUMNS
        sta FREEZP+2
        bcc !next+
        inc FREEZP+3
    !next:
        dec cnt__screen_row
        bne !row_loop-
        // Set barrier drawn flag.
        asl flag__was_barrier_drawn
    !return:
        rts

    // 666C
    // Scans the entire arena memory area to find barrier characters. Sets the color and barrier character index of
    // each barrier based on the current cycle.
    update_barrier_state:
        // Set a state value flag of 0, 40 or 80 for each phase depending upon the current phase cycle. This will be
        // used to set colors and barrier impermeability.
        ldy #(NUM_BARRIER_TYPES-1) // 0 0ffset
    !state_loop:
        ldx #$00
        lda game.data__phase_cycle,y
        beq !next+
        ldx #$40
        cmp #$02
        beq !next+
        ldx #$80
    !next:
        txa
        sta flag__phase_state_list,y
        dey
        bpl !state_loop-
        //
        lda #(NUM_SCREEN_ROWS-3) // Number of rows in the arena (3 rows are consumed by the arena borders)
        sta cnt__screen_row
        // Configure screen and color area pointers.
        lda ptr__screen_barrier_row_offset_lo
        sta FREEZP+2
        sta VARPNT
        lda ptr__screen_barrier_row_offset_hi
        sta FREEZP+3
        clc
        adc common.data__color_mem_offset
        sta VARPNT+1
    !row_loop:
        ldy #(NUM_SCREEN_COLUMNS-2-1) // Number of columns in the arean (2 are consumed by borders) 0 Offset
    !col_loop:
        ldx #$02 // Would be more efficient if this was after the BEQ below
        lda (FREEZP+2),y
        beq !next_char+ // No barrier found at current location
        //
        // Detect barrier type of displayed character.
        and #(INITIAL_BARRIER_CHARACTER+(2*NUM_CHARS_IN_BARRIER_GROUP))
        cmp #(INITIAL_BARRIER_CHARACTER+(2*NUM_CHARS_IN_BARRIER_GROUP))
        bcs !next+ // X is 02 for barrier type 3
        dex
        cmp #(INITIAL_BARRIER_CHARACTER+(1*NUM_CHARS_IN_BARRIER_GROUP))
        bcs !next+ // X is 01 for barrier type 2
        dex // // X is 00 for barrier type 1
    !next:
        // Update character index. Here we toggle bit 4 to enable or disabled barrier character set 2 (basically by
        // adding 4 or removing the addition from the initial character code).
        lda flag__phase_state_list,x
        bpl !skip+
        lda (FREEZP+2),y
        ora #%0000_0100 
        jmp !next+
    !skip:
        lda (FREEZP+2),y
        and #%1111_1011
    !next:
        sta (FREEZP+2),y
        // Update the barrier colors.
        lda game.data__phase_cycle,x
        lsr
        tax
        lda (VARPNT),y
        and #%1111_0000 // Reset color
        ora #%0000_1000 // Turn on multi-color
        ora game.data__phase_color_list,x // Set color based on current phase
        sta (VARPNT),y
        //
    !next_char:
        dey
        bpl !col_loop- // Stop at col 1 as this is the left border
        // Next row.
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
        bne !row_loop-
        rts

    // 7F05
    // Pieces will receive an negative strength adjustment when defending the caster magic square based on the number
    // of spells already cast by the spell caster. The caster magic square is the square that the spell caster
    // initially starts the game on.
    // I think the idea here is that the spell caster weakens the square as they cast spells, making the square harder
    // to defend.
    // Preserves:
    // - A, X
    magic_square_strength_adj:
        pha
        ldy #$00
        sty magic.data__used_spell_count
        lda board.data__curr_board_row
        .const MIDDLE_BOARD_ROW = 4
        cmp #MIDDLE_BOARD_ROW // Spell casters always start the game in the middle row
        bne !return+
        cpx #$00 // Light player
        beq !next+
        ldy #(BOARD_NUM_COLS-1) // Dark player coloumn (Y remains at 0 for light player row)
    !next:
        cpy board.data__curr_board_col
        bne !return+
        cpy #(BOARD_NUM_COLS-1)
        bne !skip+
        dey // `count_used_spells` needs 0 for light, 7 for dark in Y
    !skip:
        jsr magic.count_used_spells
    !return:
        pla
        rts

    // 7F63
    // Configures colors for battle arena.
    // Requires:
    // - param__arena_color: Color code of secondary multicolor for battle arena area.
    set_arena_colors:
        lda param__arena_color
        bne !skip+
        lda #DARK_GRAY // Use grey instead of black if fighting on a black square
    !skip:
        sta BGCOL0
        sta EXTCOL
        sta BGCOL1
        // Configure color data around the border of the battle arena.
        lda board.ptr__screen_row_offset_lo
        sta FREEZP+2
        sta VARPNT
        lda board.ptr__screen_row_offset_hi
        sta FREEZP+3
        clc
        adc common.data__color_mem_offset
        sta VARPNT+1
        ldx #(BOARD_NUM_ROWS*2) // 2 characters per row
    !row_loop:
        ldy #(BOARD_NUM_COLS*3-1) // 3 characters per column (0 offset)
    !char_loop:
        .const ARENA_CHARACTER = $60
        lda #ARENA_CHARACTER
        sta (FREEZP+2),y // Screen memory
        lda (VARPNT),y // Color memory
        // Reset color of all characters in the arena to the background color
        and #%1111_1000
        ora #%0000_1000
        sta (VARPNT),y
        dey
        bpl !char_loop-
        lda FREEZP+2
        clc
        adc #NUM_SCREEN_COLUMNS
        sta FREEZP+2
        sta VARPNT
        bcc !next+
        inc FREEZP+3
        inc VARPNT+1
    !next:
        dex
        bne !row_loop-
        rts

    // 7FCA
    // Remove all barriers from the screen.
    remove_barriers:
        ldx #(NUM_SCREEN_ROWS-3) // The top and bottom 2 rows will not include barriers (0 Offset)
        lda ptr__screen_barrier_row_offset_lo
        sta FREEZP+2
        lda ptr__screen_barrier_row_offset_hi
        sta FREEZP+3
    !row_loop:
        lda #$00
        ldy #(NUM_SCREEN_COLUMNS-4) // Barriers do not appear in the final 4 columns
    !column_loop:
        sta (FREEZP+2),y
        dey
        bpl !column_loop-
        // Next row.
        lda FREEZP+2
        clc
        adc #NUM_SCREEN_COLUMNS
        sta FREEZP+2
        bcc !next+
        inc FREEZP+3
    !next:
        dex
        bne !row_loop-
        rts

    // 9367
    // Enable multicolor character mode for all screen character locations.
    // If multicolor mode is enabled, bit 4 is used to turn on multicolor mode for the specified character. In this
    // mode, the color is controlled using the first 3 bits to select the appropriate color.
    set_multicolor_screen:
        lda #<COLRAM
        sta FREEZP+2
        lda #>COLRAM
        sta FREEZP+3
        ldx #$03
        ldy #$00
    !loop:
        lda (FREEZP+2),y
        ora #%0000_1000
        sta (FREEZP+2),y
        iny
        bne !loop-
        inc FREEZP+3
        dex
        bne !loop-
    !loop:
        lda (FREEZP+2),y
        ora #%0000_1000
        sta (FREEZP+2),y
        iny
        cpy #$E8 // Screen memory ends at +$03E8 (remaining bytes are used for sprite pointers)
        bcc !loop-
        rts

	// 95FC
	// Check joystick right direction and move player or fire weapon in the direction.
	check_player_right:
		lda CIAPRA,y
		and #%0001_0000 // Fire button
		beq !fire+
	//9603
	move_player_right:
		// Set flag used by AI.
		lda data__player_direction_flag_list,x
		and #%1000_0001
		ora #%0100_0000
		sta data__player_direction_flag_list,x
		// Set new player position.
		inc flag__was_icon_moved
		lda #RIGHT_FACING_ICON_FRAME
		sta common.param__icon_sprite_source_frame_list,x
		lda board.data__sprite_curr_x_pos_list,x
		cmp data__arena_sprite_x_boundary_list+1 // Right boundary
		bcs !return+
		inc board.data__sprite_curr_x_pos_list,x
	!return:
		rts
	!fire:
		// Ignore fire button if weapon is still cooling down.
		lda cnt__player_cooldown_delay_list,x
		bne !return-
	// 9626
	attack_player_right:
		inc flag__is_weapon_active
		lda data__player_sprite_speed_list,x
		and #ICON_CAN_TRANSFORM
		bne !return- // Don't set transformation attack here - we'll do this separately
		// Set player attack frame.
		lda #RIGHT_FACING_ATTACK_FRAME
		sta common.param__icon_sprite_source_frame_list,x
		// Position the projectile to the right of the player sprite.
		lda board.data__sprite_curr_x_pos_list,x
		clc
		adc #$09
		sta board.data__sprite_curr_x_pos_list+2,x
		// Activate the projectile.
		lda data__player_sprite_speed_list,x
		sta data__player_weapon_sprite_x_dir_list,x
		// Set the initial projectile animation frame.
		.const RIGHT_WEAPON_FRAME = $04
		lda #RIGHT_WEAPON_FRAME
		sta common.param__icon_sprite_source_frame_list+2,x
		bpl set_projectile_y_pos

	// 964B
	// Check joystick left direction and move player or fire weapon in the direction.
	check_player_left:
		lda CIAPRA,y
		and #%0001_0000 // Fire button
		beq !fire+
	// 9652
	move_player_left:
		// Set flag used by AI.
		lda data__player_direction_flag_list,x
		and #%1000_0001
		ora #%0100_0010
		sta data__player_direction_flag_list,x
		// Set new player position.
		inc flag__was_icon_moved
		lda #LEFT_FACING_ICON_FRAME
		sta common.param__icon_sprite_source_frame_list,x
		lda board.data__sprite_curr_x_pos_list,x
		cmp data__arena_sprite_x_boundary_list // Left boundary
		bcc !return+
		dec board.data__sprite_curr_x_pos_list,x
	!return:
		rts
	!fire:
		// Ignore fire button if weapon is still cooling down.
		lda cnt__player_cooldown_delay_list,x
		bne !return-
	// 9675
	attack_player_left:
		inc flag__is_weapon_active
		lda data__player_sprite_speed_list,x
		and #ICON_CAN_TRANSFORM
		bne !return- // Don't set transformation attack here - we'll do this separately
		// Activate the projectile.
		lda #$00
		sec
		sbc data__player_sprite_speed_list,x
		sta data__player_weapon_sprite_x_dir_list,x
		// Set player attack frame.
		lda #LEFT_FACING_ATTACK_FRAME
		sta common.param__icon_sprite_source_frame_list,x
		// Position the projectile to the left of the player sprite.
		lda board.data__sprite_curr_x_pos_list,x
		sec
		sbc #$07
		sta board.data__sprite_curr_x_pos_list+2,x
		// Set the initial projectile animation frame.
		.const LEFT_WEAPON_FRAME = $04
		lda #LEFT_WEAPON_FRAME
		sta common.param__icon_sprite_source_frame_list+2,x
		//
	// 969B
	// Position the projectile vertically centered on the player sprite.
	set_projectile_y_pos:
		lda board.data__sprite_curr_y_pos_list,x
		clc
		adc #$04
		sta board.data__sprite_curr_y_pos_list+2,x
		rts

	// 96A5
	// Check joystick up direction and move player or fire weapon in the direction.
	check_player_up:
		lda CIAPRA,y
		and #%0001_0000 // Fire button
		beq !fire+
	// 96AC
	move_player_up:
		lda flag__was_icon_moved
		bne !next+ // Left/right animation has precedence over up if moving diagonally
		inc flag__was_icon_moved
		lda #UP_FACING_ICON_FRAME		
		sta common.param__icon_sprite_source_frame_list,x
	!next:
		// Set flag used by AI.
		lda data__player_direction_flag_list,x
		and #%0100_0010
		ora #%1000_0001
		sta data__player_direction_flag_list,x
		// Set new player position.
		lda board.data__sprite_curr_y_pos_list,x
		cmp data__arena_sprite_y_boundary_list // Top boundary
		bcc !return+
		dec board.data__sprite_curr_y_pos_list,x
	!return:
		rts
	!fire:
		// Ignore fire button if weapon is still cooling down.
		lda cnt__player_cooldown_delay_list,x
		bne !return-
	// 96D4
	attack_player_up:
		inc flag__is_weapon_active
		lda data__player_sprite_speed_list,x
		and #ICON_CAN_TRANSFORM
		bne !return- // Don't set transformation attack here - we'll do this separately
		// Set player attack frame.
		lda #UP_FACING_ATTACK_FRAME
		sta common.param__icon_sprite_source_frame_list,x
		// Position the projectile above the player sprite.
		lda board.data__sprite_curr_y_pos_list,x
		sec
		sbc #$07
		sta board.data__sprite_curr_y_pos_list+2,x
		// Activate the projectile.
		lda #$00
		sec
		sbc data__player_sprite_speed_list,x
		sta data__player_weapon_sprite_y_dir_list,x
		jmp set_projectile_x_pos

	// 96F8
	// Check joystick down direction and move player or fire weapon in the direction.
	check_player_down:
		lda CIAPRA,y
		and #%0001_0000 // Fire button
		beq attack_player
		//
	// 96FF
	move_player_down:
		// Set flag used by AI.
		lda data__player_direction_flag_list,x
		and #%0100_0010
		ora #%1000_0000
		sta data__player_direction_flag_list,x
		//
		lda flag__was_icon_moved
		bne !next+ // Left/right animation has precedence over up if moving diagonally
		inc flag__was_icon_moved
		lda #DOWN_FACING_ICON_FRAME
		sta common.param__icon_sprite_source_frame_list,x
	!next:
		// Set new player position.
		lda board.data__sprite_curr_y_pos_list,x
		cmp data__arena_sprite_y_boundary_list+1 // Bottom boundary
		bcs !return+
		inc board.data__sprite_curr_y_pos_list,x
	!return:
		rts
	attack_player:
		// Ignore fire button if weapon is still cooling down.
		lda cnt__player_cooldown_delay_list,x
		bne !return-
    // 9727
	attack_player_down:
		inc flag__is_weapon_active
		lda data__player_sprite_speed_list,x
		and #ICON_CAN_TRANSFORM
		bne !return- // Don't set transformation attack here - we'll do this separately
		// Set player attack frame.
		lda #DOWN_FACING_ATTACK_FRAME
		sta common.param__icon_sprite_source_frame_list,x
		// Activate the projectile.
		lda data__player_sprite_speed_list,x
		sta data__player_weapon_sprite_y_dir_list,x
		// Position the projectile below the player sprite.
		lda board.data__sprite_curr_y_pos_list,x
		clc
		adc #$10
		sta board.data__sprite_curr_y_pos_list+2,x
		//
	// 9745
	// Set X position of the projecitle and adjust the animation frame if the projectile is being fired diagonally.
	set_projectile_x_pos:
		lda data__player_weapon_sprite_x_dir_list,x
		bne !diagonal_shot+
		// Determine X offset for projectile. The code below will set X offset to $02 when shooting up and $01 when
		// shooting down.
		ldy #$00
		lda data__player_weapon_sprite_y_dir_list,x
		bmi !next+
		iny
	!next:
		lda board.data__sprite_curr_x_pos_list,x
		clc
		adc data__vertical_projectile_x_offset,y
		sta board.data__sprite_curr_x_pos_list+2,x
		.const VERTICAL_WEAPON_FRAME = $01
		lda #VERTICAL_WEAPON_FRAME
		sta common.param__icon_sprite_source_frame_list+2,x
		rts
    // 9764
	!diagonal_shot:
		// Set weapon animation frame offset. Is calculated as follows:
		// - $02: Up/Right
		// - $03: Down/Right
		// - $05: Up/Left
		// - $06: Down/Left
		ldy #$02
		lda data__player_weapon_sprite_y_dir_list,x
		bmi !next+
		iny
	!next:
		tya
		ldy data__player_weapon_sprite_x_dir_list,x
		bpl !next+
		clc
		adc #$03
	!next:
		sta common.param__icon_sprite_source_frame_list+2,x
		// Set icon animation frame offset. Is calculated as follows:
		// - $0D: Up/Right
		// - $0F: Down/Right
		// - $15: Up/Left
		// - $17: Down/Left
		ldy #$0D
		lda data__player_weapon_sprite_y_dir_list,x
		bmi !next+
		iny
		iny
	!next:
		tya
		ldy data__player_weapon_sprite_x_dir_list,x
		bpl !next+
		clc
		adc #$08
	!next:
		sta common.param__icon_sprite_source_frame_list,x
		// Set the Y position of the projectile.
		ldy #$00
		lda data__player_weapon_sprite_y_dir_list,x
		bmi !next+
		iny
	!next:
		lda board.data__sprite_curr_y_pos_list+2,x
		clc
		adc data__vertical_projectile_y_offset,y
		sta board.data__sprite_curr_y_pos_list+2,x
	!return:
		rts
    
	// 97A2
	// Configure weapon sound, cooldown time, speed
	configure_weapon:
		lda flag__is_weapon_active
		beq !return-
		lda #PLAYER_SOUND_WEAPON
		cmp common.flag__is_player_sound_enabled,x
		bcc !skip_sound_config+
		// Configure sound.
		sta common.flag__is_player_sound_enabled,x
		lda #$00
		sta common.data__voice_note_delay,x
		txa
		asl
		tay
		lda ptr__player_attack_pattern_lo_list,x
		sta OLDTXT,y
		lda ptr__player_attack_pattern_hi_list,x
		sta OLDTXT+1,y
		lda resources.snd__effect_attack_01+4
		sta ptr__player_attack_sound_fq_lo_list,x
		lda resources.snd__effect_attack_01+5
		sta ptr__player_attack_sound_fq_hi_list,x
	!skip_sound_config:
		//
		// Configure cooldown countdown delay.
		ldy common.param__icon_offset_list,x
		lda data__icon_attack_recovery_list,y
		sta cnt__player_cooldown_delay_list,x
		// Configure projectile speed.
		lda data__player_sprite_speed_list,x
		and #(ICON_CAN_TRANSFORM + ICON_CAN_THRUST)
		beq !set_speed+
		// Configure thrust weapon.
		cmp #ICON_CAN_THRUST
		beq !set_thrust_count+
		// Configure transform weapon.
		sta data__player_weapon_sprite_speed_list,x
		lda #$00
		sta board.cnt__sprite_frame_list+2,x
		sta data__player_weapon_sprite_x_dir_list,x
		sta data__player_weapon_sprite_y_dir_list,x
		lda common.param__icon_offset_list,x
		cmp #BANSHEE_OFFSET
		beq !configure_banshee+
		// Configure Phoenix.
		lda common.param__icon_sprite_source_frame_list,x
		sta data__icon_sprite_frame_before_attack_list,x
		lda board.data__sprite_curr_y_pos_list,x
		sta data__icon_sprite_y_pos_before_attack_list,x
		lda #SPRITE_Y_OFFSCREEN
		sta board.data__sprite_curr_y_pos_list,x // Move Phoenix icon offscreen as it is replaced by fire
		jmp configure_phoenix_animation
	!configure_banshee:
		// Configure Banshee scream. The scream will last for 40 frames (1 offset). The scream sprite is expanded
		// in the X and Y directions. Note that we can hardcode the expansion of sprite 4 only as Banshee is a
		// dark piece only (attack sprite 4) and light player doesn't have a Shape Shifter (unfortunately every
		// light player needs to allow for a dark player of the same type if challenging the Shape Shifter).
		lda #BANSHEE_SCREAM_ACTIVE_COUNT
		sta data__player_weapon_sprite_x_dir_list,x
		lda #$08
		ora XXPAND
		sta XXPAND
		lda #$08
		ora YXPAND
		sta YXPAND
		jmp banshee_attack
		//
	!set_thrust_count:
		lda #THRUST_WEAPON_ACTIVE_COUNT
	!set_speed:
		ora #FLAG_ENABLE
		sta data__player_weapon_sprite_speed_list,x
		// Set animation initial frame if the projectile is rotating. Note that the routine returns to the parent if
		// the icon does not support a rotating projectile. See `check_rotatating_projectile` for more details.
		jsr check_rotatating_projectile
		lda #$00
		sta common.param__icon_sprite_source_frame_list+2,x
		rts

	// 9836
	// Handle attack from transforming icons. The transforming icons are:
	// - Phoenix: Transforms in to fire. The fire radius increases as the attack progresses. The phoenix cannot be
	//   hurt while transformed however the Phoenix cannot move while transformed. 
	// - Banshee: Attacks with a scream that surrounds the icon. The Banshee can be hurt while attacking however the
	//   Banshee can move while screaming.
	transform_attack:
		lda common.param__icon_offset_list,x
		cmp #BANSHEE_OFFSET
		beq banshee_attack
		//
		// Phoenix attack
		// The X and Y weapon positions are used as delay counters instead of positions.
		//
		// The X direction is used to delay detecting a hit on the challenger. Hits are only registered once in every
		// 10 frames (on the 5th, 15th, 25th etc). 
		inc data__player_weapon_sprite_x_dir_list,x
		lda data__player_weapon_sprite_x_dir_list,x
		cmp #$05
		bne !next+
		jmp check_hit
	!next:
		cmp #$0A
		bne !return+
		//
		// Every 10 frames we update the flame animation. The flame animation has 5 parameters and that define the
		// flame state. There are 5 flame animations after which the flame attack completes.
		// The Y direction is used to keep track of the flame animation. It is incremented 5 each timne the state
		// changes so that it always points to the first parameter. The parameters define the sprite expansion
		// parameters, x and y offset (so animation is centered around the icon) and sprite frame offset.
		lda #$00
		sta data__player_weapon_sprite_x_dir_list,x // Reset X counter
		lda data__player_weapon_sprite_y_dir_list,x
		clc
		.const PARAMS_PER_ANIMATION = 5
		.const NUM_ANIMATION_STATES = 5
		adc #PARAMS_PER_ANIMATION
		sta data__player_weapon_sprite_y_dir_list,x
		cmp #(PARAMS_PER_ANIMATION * NUM_ANIMATION_STATES)
		bcc configure_phoenix_animation
		jmp !restore_icon+
    // 9863
	configure_phoenix_animation:
		// Apply animation parameters.
		ldy data__player_weapon_sprite_y_dir_list,x
		lda data__sprite_offset_bit_list,x // Used to determine which sprite to expand (needed for shapeshifter)
		pha
		// Expand sprite in X direction.
		lda data__phoenix_flame_animation_list,y
		beq !toggle_x_expand+
		// Force X expand.
		pla
		pha
		ora XXPAND
		jmp !skip+
		// Toggle X expand.
	!toggle_x_expand:
		pla
		pha
		eor #$FF
		and XXPAND
	!skip:
		sta XXPAND
		// Expand sprite in Y direction.
		lda data__phoenix_flame_animation_list+1,y
		beq !toggle_y_expand+
		pla
		ora YXPAND
		jmp !skip+
	!toggle_y_expand:
		pla
		eor #$FF
		and YXPAND
	!skip:
		sta YXPAND
		// Set flame sprite animation frame.
		lda data__phoenix_flame_animation_list+2,y
		sta common.param__icon_sprite_source_frame_list+2,x
		// Set flame x position offset.
		lda board.data__sprite_curr_x_pos_list,x
		clc
		adc data__phoenix_flame_animation_list+3,y
		sta board.data__sprite_curr_x_pos_list+2,x
		// Set flame y position offset.
		lda data__icon_sprite_y_pos_before_attack_list,x
		clc
		adc data__phoenix_flame_animation_list+4,y
		sta board.data__sprite_curr_y_pos_list+2,x
	!return:
		rts
	//
	// 98B3
	// Banshee attack.
	// The X and Y weapon positions are used as delay counters instead of positions.
	banshee_attack:
		// The X position is set to $29 when the attack is intiated. This is the total number of frames that the
		// attack will last.
		dec data__player_weapon_sprite_x_dir_list,x
		bmi !complete_attack+
		// The Y position is used to check for a hit on every 5th frame.
		lda data__player_weapon_sprite_y_dir_list,x
		clc
		adc #$01
		cmp #$05
	    bcc !next+
		jsr check_hit
		lda #$00
	!next:
		sta data__player_weapon_sprite_y_dir_list,x
		//
		lda #$03 // NFI: left over code maybe?
	//
	// 98CC
	// Set Banshee scream position.
	// The scream position is hard coded to appeare 6 pixels to the left and 12 pixels above the icon sprite position.
	set_banshee_attack_pos:
		lda board.data__sprite_curr_x_pos_list,x
		sec
		sbc #$06
		sta board.data__sprite_curr_x_pos_list+2,x
		lda board.data__sprite_curr_y_pos_list,x
		sec
		sbc #$0C
		sta board.data__sprite_curr_y_pos_list+2,x
		rts
	//
	// Restore the icon position and frame prior to commencement of the attack. Used for Phoenix attack only.
	!restore_icon:
		lda data__icon_sprite_frame_before_attack_list,x
		sta common.param__icon_sprite_source_frame_list,x
		lda data__icon_sprite_y_pos_before_attack_list,x
		sta board.data__sprite_curr_y_pos_list,x
	!complete_attack:
		jmp remove_weapon

    // 992A
	// Update the player weapon. This may include firing a projectile, continue moving a projectile across the
	// screen, surrounding the player with a weapon (eg scream or fire) or thrusting a weapon (eg club or sword).
	update_activated_weapon:
		lda data__player_weapon_sprite_speed_list,x // Speed will be set if weapon is activated
		bne !next+
		rts
	!next:
		lda data__player_icon_sprite_speed_list,x
		and #ICON_CAN_TRANSFORM
		beq !next+
		jmp transform_attack
	!next:
		lda data__player_icon_sprite_speed_list,x
		cmp #ICON_CAN_THRUST
		beq !next+
		jsr check_hit
		lda flag__weapon_hit_detected
		bmi !return+
	!next:
		// Check if projectile has hit a barrier.
		// If the projectile hits a impermiable barrier the projectile will stop moving. If the barrier is
		// permiable, the projectile will move at half speed until it has passed the barrier at which point
		// it will speed up again (ignoring the laws of physics).
		lda data__weapon_barrier_phase_collision_list,x
		beq !skip+ // No barrier
		bpl !permiable+
		jmp remove_weapon // No more projectile :(
	!permiable:
	 	// Halves projectile speed when firing over a permiable barrier. Very hard to tell though.
		lda cnt__projectile_delay_list,x
		eor #$FF
	!skip:
		sta cnt__projectile_delay_list,x
		// Here we return if the barrier is permiable and the "every second time" toggle is 0 (we toggle between
		// 0 and FF). The Accumulator will be non-zero in every other case.
		beq !next+
		rts
	!next:
		lda data__player_icon_sprite_speed_list,x
		cmp #ICON_CAN_THRUST
		bne !projectile+
		jmp thrust_weapon
	!projectile:
		// Reduce the frequency of the projectile as it remains active. Each player uses a single voice for the
		// attack sound effects. The code below takes the existing note being played and reduces the frequency
		// each time the projectile is moved. This effect makes it sound like the projectile is moving away
		// from you.
		txa
		asl
		tay
		lda common.ptr__voice_ctl_addr_list,y
		sta FREEZP+2
		lda common.ptr__voice_ctl_addr_list+1,y
		sta FREEZP+3
		lda ptr__player_attack_sound_fq_lo_list,x
		sec
		sbc #$80
		sta ptr__player_attack_sound_fq_lo_list,x
		ldy #$00
		sta (FREEZP+2),y
		iny
		lda ptr__player_attack_sound_fq_hi_list,x
		sbc #$00
		sta ptr__player_attack_sound_fq_hi_list,x
		sta (FREEZP+2),y
		// Continue moving the projectile until it disappears off the screen.
		lda data__player_weapon_sprite_y_dir_list,x
		clc
		adc board.data__sprite_curr_y_pos_list+2,x
		sta board.data__sprite_curr_y_pos_list+2,x
		cmp #$0A // Offscreen top
		bcc remove_weapon
		cmp #$BE // Offscreen bottom
		bcs remove_weapon
		lda data__player_weapon_sprite_x_dir_list,x
		clc
		adc board.data__sprite_curr_x_pos_list+2,x
		sta board.data__sprite_curr_x_pos_list+2,x
		cmp #$02 // Offscreen left
		bcc remove_weapon
		cmp #$9B // Offscreen right
		bcs remove_weapon
		// Rotate the projectile if the icon has a rotating projectile type.
		// Note the routine below will immeditaly return from this routine if the icon does not have a rotating
		// projectile.
		jsr check_rotatating_projectile
		inc cnt__projectile_rotate_delay_list,x
		lda cnt__projectile_rotate_delay_list,x
		and #$03 // Rotate every 3rd frame
		beq !return+
		inc board.cnt__sprite_frame_list+2,x
	!return:
		rts

	// 9907
	// Keep thrust weapon going for a max count of 15 frames. Detect a hit while weapon is active.
	thrust_weapon:
		lda flag__did_player_weapon_hit_list,x
		bmi !skip_hit+ // Only register one hit per thrust attack
		jsr check_hit
		lda flag__weapon_hit_detected
		bpl !skip_hit+ // No hit
		sta flag__did_player_weapon_hit_list,x // Store hit so we don't process any more hits until next attack
	!skip_hit:
		// Keep the weapon active for a maximum of 15 frames
		lda data__player_weapon_sprite_speed_list,x
		and #THRUST_WEAPON_ACTIVE_COUNT
		bne !next+
		jmp remove_weapon
	!next:
		lda flag__did_player_weapon_hit_list,x
		bmi !next+ // NFI. This must be some left over code as it does nothing.
	!next:
		dec data__player_weapon_sprite_speed_list,x
		rts

	// 99C2
	// Check for icon types with rotating projectiles. Icons such as the Dragon or Unicorn fire a projectile that
	// shoots in a straight line. Elementatls or Trolls on the other hand fire rocks or file that roll as they
	// travel.
	// The following icon types fire rotating projectiles;
	//    Wizard, Golem, Djinni, Troll, Air Elemental, Fire Elemental, Earth Elemental, Water Elemental
	// NOTE This method pulls the last two registers from the stack if the icon does NOT throw rotating projectiles,
	// effectively turning the JSR in to JMP. Let me explain - when a method is called via a JSR, the operation
	// adds the memory location of the next command to the stack. When a RTS is executed the last two registers are
	// pulled from the stack to determine which address to return to. When we pull two regisetrs from the stack,
	// the RTS will return to the parent's parent.
	// This is common however it is a bit of anti-pattern as it can be difficult to debug.
	check_rotatating_projectile:
		.const NUM_ICONS_WITH_ROTATING_PROJECTILES = 7
		ldy #NUM_ICONS_WITH_ROTATING_PROJECTILES
	!loop:
		lda data__icon_with_rotating_projectile_list,y
		cmp common.param__icon_offset_list,x
		beq !return+
		dey
		bpl !loop-
		pla
		pla
	!return:
		rts

	// 99DA
	// Removes the active weapon or projectile. This routine is called after a projectile hits a target or flies
	// off-screen or a thrust or transform weapon has timed out.
	// Requires:
	// - X: current player (0 for light, 1 for dark).
	remove_weapon:
		// Configure starting sound control register for player voice (so that the voice control register can be
		// cleared).
		txa
		asl
		tay
		lda common.ptr__voice_ctl_addr_list,y
		sta FREEZP+2
		lda common.ptr__voice_ctl_addr_list+1,y
		sta FREEZP+3
		// Remove weapon/projectile sprite.
		lda #EMPTY_SPRITE_BLOCK
		sta SPTMEM+2,x
		// Clear weapon/projectile variables (position, speed, collission).
		lda #$00
		sta data__player_weapon_sprite_speed_list,x
		sta data__player_weapon_sprite_x_dir_list,x
		sta data__player_weapon_sprite_y_dir_list,x
		sta flag__did_player_weapon_hit_list,x
		// Stop weapon firing sound.
		lda common.flag__is_player_sound_enabled,x
		cmp #PLAYER_SOUND_WEAPON
		bne !skip+
		lda #$00
		sta common.flag__is_player_sound_enabled,x
		ldy #$04
		sta (FREEZP+2),y // Voice control register
	!skip:
		// Detect if player icon is still in firing stance and if so, return the player back to the correct stance
		// facing in the correct position.
		// Note frames below $0C are non-firing stances. This could happen if the player was moved before the
		// projectile finished firing. Once $0c is subtracted, the following values will result:
		// - $00=north, $01=north east, $02=east, $03=south east, $04=south, $05+=west
		// Therefore the calculation below will set the correct frame based on the current attack frame to set the icon
		// facing in the correct position.
		lda common.param__icon_sprite_source_frame_list,x
		sec
		sbc #$0C
		bmi !return+ // Not in attack pose
		cmp #$05
		bcs !pose_left+ // West facing
		tay
		lda idx__icon_frame_offset_list,y
	!set_pose:
		sta common.param__icon_sprite_source_frame_list,x
	!return:
		rts
	!pose_left:
		lda #LEFT_FACING_ICON_FRAME
		bne !set_pose-

    // 9A27
    // Detect if a player's weapon or projectile has hit the opposing player. Subtract damage from the player if a hit
    // was detected.
    // Requires:
    // - X: Player's projectile to check (0 for light, 1 for dark)
    // Returns:
    // - `flag__weapon_hit_detected`: Set TRUE if a hit was detected.
    check_hit:
        lda #FLAG_DISABLE
        sta flag__weapon_hit_detected
        txa
        eor #$01 // Check opposite player (eg changes 0 to 1 and 1 to 0)
        tay
        lda data__sprite_offset_bit_list,x
        and flag__sprite_to_sprite_collision
        beq !return+
        lda common.data__math_pow2_list,y // Ensure we don't register a hit if weapon/projectiles hit each other
        and flag__sprite_to_sprite_collision
        beq !return+
        //
        // Hit detected!
        // BUG: Pretty sure this will register a hit if both players fire within the same interrupt as the collission
        // register will detect collissions on both players at the same time. Will only happen for icons with long
        // projectiles such as Unicorn vs Dragon.
        lda common.param__icon_offset_list,y
        // If the Phoenix was hit while active, the Phonex will suffer no damage and the projectile will 'burn up' and
        // be removed.
        cmp #PHOENIX_OFFSET
        bne !next+
        lda data__player_weapon_sprite_speed_list,y // Phoenix weapon active?
        bne !skip_damage+
    !next:
        // Reduce strength of opposing player.
        lda data__player_attack_strength_list,y
        sec
        sbc data__player_attack_damage_list,x
        bpl !skip+
        lda #$00 // Ensure strength doesn't go negative
    !skip:
        sta data__player_attack_strength_list,y
        bne !register_hit+
        //
        // Player was killed. RIP :(
        lda common.param__icon_offset_list,y
        cmp #BANSHEE_OFFSET
        bne !skip+
        // If victor was the Banshee, remove the Banshee scream while we parade the winner.
        lda #EMPTY_SPRITE_BLOCK
        sta SPTMEM+2,y
        lda #$00
        sta data__player_weapon_sprite_speed_list,y
    !skip:
        // Remove the loser icon (by moving it off the screen) and configure the game to wait 1 second before ending
        // challenge gameplay. 
        lda #SPRITE_Y_OFFSCREEN
        sta board.data__sprite_curr_y_pos_list,y
        lda #(1*JIFFIES_PER_SECOND)
        sta private.cnt__end_game_delay
        //
    !register_hit:
        // The game play logic uses `flag__is_player_sound_enabled` to determine whic action caused the last sound
        // effect. $83 must be the hit action.
        lda #PLAYER_SOUND_HIT
        sta common.flag__is_player_sound_enabled,x
        lda #$00
        sta common.data__voice_note_delay,x
        txa
        asl
        tay
        lda ptr__sound_hit_effect_list,y
        sta OLDTXT,y
        lda ptr__sound_hit_effect_list+1,y
        sta OLDTXT+1,y
        //
    !skip_damage:
        lda #FLAG_ENABLE
        sta flag__weapon_hit_detected
        // Check if icon is Phoenox or Banshee (type $06 or $0E) and if so, don't remove the weapon if a hit was
        // detected.
        lda common.param__icon_offset_list,x
        and #$07
        cmp #$06
        beq !return+
        jmp remove_weapon
    !return:
        rts

	// 9AA2
	// Bounce player off the barrier when the player runs in to a barrier.
	bounce_player_off_barrier:
		// Set new X position.
		// The maths here is interesting. The X position is anded with #$F0 which separates the X position in to blocks
		// of 16 pixels (so X is rounded down to the nearest block - eg 24 becomes 16, 35 becomes 32 etc). Then the
		// OR #$0C basically adds 12 to the value. This results in the player being bounced to one side of the
		// barrier (left or right depending upon the exact X position value).
		// The algorithm results in a preference for bouncing right more often than left.
		lda board.data__sprite_curr_x_pos_list,x
		and #$F0
		ora #$0C
		cmp #$91 // Maximum X position (we don't need to worry about minimum as barriers are not near the left edge)
		bcc !next+
		lda #$91
	!next:
		sta board.data__sprite_curr_x_pos_list,x
		// Set new Y position.
		// 8 (half the height of the barrier) is added to the Y position and then the position is then rounded down to
		// the nearest 32 pixel boundary. This results in the player being bounced up if and part of the sprite
		// collides with the barrier above the the center line, and down if sprite collides below the center line.
		lda board.data__sprite_curr_y_pos_list,x
		clc
		adc #$08
		and #$E0
		cmp #$12 // Minimum Y position
		bcs !next+
		adc #$20
	!next:
		cmp #$AE // Maximum Y position
		bcc !next+
		sbc #$20
	!next:
		sta board.data__sprite_curr_y_pos_list,x
		// 9AC9 A9 00 lda #$00 // TODO: Probably for AI?
		// 9ACB 9D 36 BF sta temp_data__light_piece_count,x
		// 9ACE 9D 32 BF sta temp_data__dark_piece_count,x
		// Update the Banshee scream position if the Banshee weapon is currently active.
		lda common.param__icon_offset_list,x
		cmp #BANSHEE_OFFSET
		bne !return+
		lda data__player_weapon_sprite_speed_list,x // Is non-zero if weapon is active
		beq !return+
		ldx #$01 // Banshee is always player 2
		jmp set_banshee_attack_pos
	!return:
		rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 7F01
    // Minimum and maximum sprite X positions within the battle arena.
    data__arena_sprite_x_boundary_list:
        //    left right
        .byte $08, $91

    // 7F03
    // Minimum and maximum sprite Y positions within the battle arena.
    data__arena_sprite_y_boundary_list:
        //    top  bottom
        .byte $12, $AE
    

    // 8BAA
    // Sound pattern used for attack sound of each icon type. The data is an index to the icon pattern pointer array.
    idx__sound_attack_pattern:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 12, 12, 12, 12, 12, 12, 16, 14, 12, 12, 12, 12, 12, 12, 18, 14, 12, 12, 12, 12

    // 8A8B
    // Icon attack Speed.
    // - 0-7 = projectile speed
    // - 20 = directional thrust weapon
    // - 40 = transofrmation weapon (eg scream)
    // - 00 = shapeshifter - it gets speed of opponent
    data__icon_attack_speed_list:
        //    UC, WZ, AR, GM, VK, DJ, PH,                 KN
        .byte 07, 05, 04, 03, 03, 04, ICON_CAN_TRANSFORM, ICON_CAN_THRUST
        //    BK, SR, MC, TL, SS, DG, BS,                 GB
        .byte 07, 06, 03, 03, 00, 04, ICON_CAN_TRANSFORM, ICON_CAN_THRUST
        //    AE, FE, EE, WE
        .byte 04, 05, 03, 03

    // 8AEB
    // Color of the icon's weapon.
    data__icon_weapon_color_list:
        //    UC,     WZ,     AR,    GM     VK     DJ          PH      KN
        .byte YELLOW, ORANGE, BROWN, BROWN, BROWN, LIGHT_GRAY, ORANGE, WHITE
        //    BK,          SR,    MC,         TL,   SS,         DG,  BS,         GB
        .byte LIGHT_GREEN, WHITE, LIGHT_BLUE, GRAY, LIGHT_BLUE, RED, LIGHT_BLUE, BROWN
        //    AE,         FE,  EE,    WE
        .byte LIGHT_GRAY, RED, BROWN, BLUE

    // 8A9F
    // Icon attack Damage.
    // - 00 = shapeshifter - it gets damage of opponent
    data__icon_attack_damage_list:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 07, 10, 05, 10, 07, 06, 02, 05, 09, 08, 04, 10, 00, 11, 01, 05, 05, 09, 09, 06

    // 8AD7
    // Icon attack recovery speed (in number of jiffies).
    // - 00 = shapeshifter - it gets the recovery speed from the opponent
    data__icon_attack_recovery_list:
        //    UC,  WZ,  AR,  GM,  VK,  DJ,  PH,  KN,  BK,  SR,  MC,  TL,  SS,  DG,  BS,  GB,  AE,  FE,  EE,  WE
        .byte $3C, $50, $50, $64, $50, $5A, $64, $28, $3C, $50, $50, $64, $00, $78, $64, $28, $46, $3C, $64, $64

    // 8B4F
    // Weapon/projectile animation sprite offsets. Note that some icons use the same weapons/projectiles.
    // Phoenix and Banshee use full height shape data stored with the icon shape data.
    ptr__weapon_sprite_mem_offset_list:
        .word resources.ptr__sprites_weapon+UNICORN_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // UC
        .word resources.ptr__sprites_weapon+WIZARD_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // WZ
        .word resources.ptr__sprites_weapon+ARCHER_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // AR
        .word resources.ptr__sprites_weapon+GOLEM_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // GM
        .word resources.ptr__sprites_weapon+VALKYRIE_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // VK
        .word resources.ptr__sprites_weapon+DJINNI_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // DJ
        .word resources.prt__sprites_icon+PHOENIX_OFFSET*BYTES_PER_ICON_SPRITE*15+BYTES_PER_ICON_SPRITE*10 // PH                                                         // PH
        .word resources.ptr__sprites_weapon+KNIGHT_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // KN
        .word resources.ptr__sprites_weapon+BASILISK_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // BK
        .word resources.ptr__sprites_weapon+SORCERESS_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // SR
        .word resources.ptr__sprites_weapon+MANTICORE_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // MC
        .word resources.ptr__sprites_weapon+GOLEM_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // TL
        .word resources.ptr__sprites_weapon+SHAPESHIFTER_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // SS
        .word resources.ptr__sprites_weapon+DRAGON_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // DG
        .word resources.prt__sprites_icon+BANSHEE_OFFSET*BYTES_PER_ICON_SPRITE*15+BYTES_PER_ICON_SPRITE*5 // BS
        .word resources.ptr__sprites_weapon+GOBLIN_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // GB
        .word resources.ptr__sprites_weapon+DJINNI_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // AE
        .word resources.ptr__sprites_weapon+SHAPESHIFTER_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // FE
        .word resources.ptr__sprites_weapon+GOLEM_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // EE
        .word resources.ptr__sprites_weapon+SHAPESHIFTER_OFFSET*BYTES_PER_WEAPON_SPRITE*4 // WE

    // 95F4
    // Pointers to hit sound effect.
    ptr__sound_hit_effect_list:
        .word resources.snd__effect_hit_player_light   // 00
        .word resources.snd__effect_hit_player_dark    // 02

    // 9762
    // X offset for projectiles when fired vertically.
    data__vertical_projectile_x_offset:
        //    Up   Down
        .byte $02, $01

    // 97A0
    // Y offset for projectiles when fired diagonally.
    data__vertical_projectile_y_offset:
        //    Up   Down
        .byte $04, $FC        

    // 98B1
    // Bits used to enable sprite 2 and 3 (and set color mode etc).
    // - 0 for sprite 2, 1 for sprite 3
    data__sprite_offset_bit_list:
        .byte %0000_0100 // Sprite 2 bit
        .byte %0000_1000 // Sprite 3 bit

	// 98EE
	// Phoenix flame attack animation parameters.
	// - Byte 1: toggle expand x (0=toggle, non-zero=expand)
	// - Byte 2: toggle expand y (0=toggle, non-zero=expand)
	// - Byte 3: sprite frame
	// - Byte 4: offset x
	// - Byte 5: offset y
	data__phoenix_flame_animation_list:
		.byte 00, 00, 00, 00, 00 // Not-expanded
		.byte 00, 00, 01, -2, -2 // Expanded
		.byte 01, 01, 01, -6, -6 // Expanded, large flame frame offset
		.byte 00, 00, 01, -2, -2 // Expanded
		.byte 00, 00, 00, 00, 00 // Not-expanded

    // 99D2
    // List of icon types with rotating projectiles.
    //                                              WZ   GM   DJ   TL   AE   FE   EE   WE
    data__icon_with_rotating_projectile_list: .byte $01, $03, $05, $0b, $10, $11, $12, $13        

    // 9A22
    // Frame index offset for east facing positions. $08=north, $00=east, $04=south
    //                                 n    n-e  s-e  e    s
    idx__icon_frame_offset_list: .byte $08, $00, $00, $00, $04

    // BEE4
    // Low byte screen memory offset of start of each board row for a barrier.
    .const BARRIER_START_OFFSET = $51 // Screen memory offset of first possible barrier character
    ptr__screen_barrier_row_offset_lo: .fill 11, <(SCNMEM+BARRIER_START_OFFSET+i*2*NUM_SCREEN_COLUMNS)

    // BEEF
    // High byte screen memory offset of start of each board row.
    ptr__screen_barrier_row_offset_hi: .fill 11, >(SCNMEM+BARRIER_START_OFFSET+i*2*NUM_SCREEN_COLUMNS)
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BCDC
    // icon frame prior to attack
    data__icon_sprite_frame_before_attack_list: .byte $00, $00	

    // BCEE
    // Counter used to advance animation frame (every 4 pixels).
    idx__icon_frame: .byte $00

	// BCF0
	// List of counters used to delay the rotation of a rotating projectile will the projectile is moving across the
	// screen. One count for each player. 
	cnt__projectile_rotate_delay_list: .byte $00, $00

    // BCF2
    // Current color of square in which a battle is being faught.
    param__arena_color: .byte $00

    // BCF2
    // Current delay counter used to delay end of game after a character dies.
    cnt__end_game_delay: .byte $00

    // BCF3
    // Current medium jiffy time (~4s). Used to detect if the jiffy has changed and implement background tasks
    // such as updating the barrier colors.
    date__curr_time: .byte $00

    // BCF6
    // Is TRUE if the player's projectile hit the other player.
    flag__did_player_weapon_hit_list: .byte $00, $00

    // BCF8
    // Is set to the current barrier phrase if a sprite collission was detected hitting the barrier.
    data__sprite_barrier_phase_collision_list:
    data__icon_barrier_phase_collision_list:
        .byte $00, $00
    // BCFA
    data__weapon_barrier_phase_collision_list:
        .byte $00, $00

    // BCFE
    // Holds the number of moves remaining to shift the player pieces in to the starting location.
    cnt__moves_remaining: .byte $00

    // BCFE
    // Is TRUE if the player weapon/projectile has hit the opposing player.
    flag__weapon_hit_detected: .byte $00

    // BCFE
    // Is $40 if the barrier was not drawn because it would overlap an existing barrier. Is $80 if the barrier was
    // drawn.
    flag__was_barrier_drawn: .byte $00

    // BD01
    // Sprite speed for each challenge icon (light icon, dark icon, light projectile, dark projectile).
    data__player_sprite_speed_list: 
    data__player_icon_sprite_speed_list:
        .byte $00, $00
    // BD03
    data__player_weapon_sprite_speed_list:
        .byte $00, $00

    // BD05
    // Starting strength for each challenge icon (light, dark).
    data__player_attack_strength_list: .byte $00, $00

    // BD07
    // Attack damage for each challenge icon (light, dark).
    data__player_attack_damage_list: .byte $00, $00

    // BD0D
    // Is non-zero if the player icon was moved (in X or Y direction) during the interrupt.
    flag__was_icon_moved: .byte $00

    // BD10
    // Is non-zero if the player projectile was fired (in X or Y direction) during the interrupt.
    flag__is_weapon_active: .byte $00

    // BD12
    // Calculated strength adjustment based on color of the challenge square.
    data__strength_adj: .byte $00

    // BD15
    // Starting y position of each player.
    data__sprite_initial_y_pos_list: .byte $00, $00

    // BD17
    // Starting x position of each player.
    data__sprite_initial_x_pos_list: .byte $00, $00

    // BD19
    // Tristate flag used to represent the current state of each cycle based on the current phase. The flag is
    // used to set barrier colors and impermeability.
    flag__phase_state_list: .byte $00, $00, $00

    // BD1D
    // Toggle used to delay a player icon while travelling over a permiable barrier.
    cnt__icon_delay_list: .byte $00, $00

    // BD1F
    // Toggle used to delay a player projectile while travelling over a permiable barrier.
    cnt__projectile_delay_list: .byte $00, $00

    // BD21
    // Cooldown delay countdown timer used to delay a player from activating the weapon again until the timer has
    // expired.
    cnt__player_cooldown_delay_list: .byte $00, $00

    // BD23
    // Color of square where challenge was initiated. Used for determining icon strength.
    // TODO: Is this used?
    data__curr_square_color_code: .byte $00

    // BD62
    // Direction flag for each player used by AI.
    data__player_direction_flag_list: .byte $00, $00

    // BD68
    // Low byte of player attack pattern frequency (one byte for each player). Used to vary the sound while the
    // attack is in progress (eg while a projectile is still in the air).
    ptr__player_attack_sound_fq_lo_list: .byte $00, $00

    // BD6A
    // High byte of player attack pattern frequency (one byte for each player).
    ptr__player_attack_sound_fq_hi_list: .byte $00, $00

    // BF0E
    // Low byte pointer to attack sound pattern for current icon (one byte for each player).
    ptr__player_attack_pattern_lo_list: .byte $00, $00

    // BF10
    // High byte pointer to attack sound pattern for current icon (one byte for each player).
    ptr__player_attack_pattern_hi_list: .byte $00, $00

    // BF16
    // AI aggression adjustment used when challenging for a magic square.
    data__magic_square_aggression: .byte $00

    // BF1A
    // Screen row counter. Used to keep track of the current screen row.
    cnt__screen_row: .byte $00

    // BF1A
    // Type of icon taht was the victor after the challenge. Is $80 if both pieces were killed or the victor was an
    // elemental.
    data__winning_icon_type: .byte $00

    // BF1C
    // Current character code index for the strength bar character.
    cnt__strength_bar_character: .byte $00

    // BF20
    // Current player strength inverted so that $18=$00 strength and $00=$18 strength.
    data__curr_inverted_strength: .byte $00

    // BF21
    // Temporary storage used store a value and then retrieve it later unmodified.
    data__temp_storage: .byte $00

    // BF23
    // Barrier cycle counter. Used to count the current cycle (3 cycles used for setting the barrier phases).
    cnt__barrier_cycle: .byte $00

    // BF24
    // Current character code index for the barrier character.
    cnt__barrier_character: .byte $00

    // BF30
    // Current board row.
    idx__board_row: .byte $00

    // BF31
    // Current board column.
    idx__board_col: .byte $00

    // BF34
    // Current y direction of the player weapon sprite.
    // 0=no movement, -ve=up movement, +ve=down movement
    data__player_weapon_sprite_y_dir_list: .byte $00, $00

    // BF36
    // Calculated strength adjustment based on color of the challenge square plus 1.
    // TODO: Is this used?
    data__strength_adj_plus1: .byte $00

    // BF36
    // Piece count of each side. Used by AI algorithm.
    data__piece_count_list: .byte $00, $00

    // BF38
    // Current x direction of the player weapon sprite.
    // 0=no movement, -ve=left movement, +ve=right movement
    data__player_weapon_sprite_x_dir_list: .byte $00, $00

    // BF41
    // Calculated strength adjustment based on color of the challenge square times 2.
    // TODO: Is this used?
    data__strength_adj_x2: .byte $00

    // BF45
	// Sprite to sprite collision flag. Contians a list of bits for each sprite that has collided with another sprite.
	flag__sprite_to_sprite_collision: .byte $00

	// BF46
	// Sprite to foreground collision flag. Contians a list of bits for each sprite that has collided with a foreground
	// character.
	flag__sprite_to_char_collision: .byte $00

    // BF47
    // Holds the position of the icon sprite before commencement of the attack. This is required for the Phoenix icon
    // as the icon sprite position is moved off the screen while the attack occurs so that the icon isn't displayed
    // while it is transformed to a flame.
    data__icon_sprite_y_pos_before_attack_list: .byte $00, $00
}
