.filenamespace challenge
//---------------------------------------------------------------------------------------------------------------------
// Icon challenge and battle arena.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 7ACE
entry:
    // Redraw board without any icons.
    jsr board.clear_text_area
    lda #$80
    sta board.flag__render_square_ctl
    jsr board.draw_board
    ldx #$40 // ~ 1 second
    jsr common.wait_for_jiffy
    //
    sei
    lda #<main.play_challenge
    sta main.ptr__raster_interrupt_fn
    lda #>main.play_challenge
    sta main.ptr__raster_interrupt_fn+1
    cli
    // Configure sprites.
    lda #%0000_1111
    sta SPTMEM+1
    sta SPTMEM+2
    sta SPTMEM+3
    sta SPTMEM+7
    jsr common.clear_mem_sprite_24
    jsr common.clear_mem_sprite_48
    jsr common.clear_mem_sprite_56_57
    lda #%000_0011
    sta SPMC
    lda XXPAND
    and #%1111_1100
    sta XXPAND
    lda #%0000_0000
    sta YXPAND
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
    sta curr_square_color // Color of the sqauare - I don't think this is used anywhere
    // Get the battle sqauer color (a) and a number between 0 and 7 (y). 0 is strongest on black, 7 is strongest on
    // white.
    beq dark_square
    bmi vary_square
    ldy #$07
    lda board.data__board_player_cell_color_list+1 // White
    bne !next+
dark_square:
    ldy #$00
    lda board.data__board_player_cell_color_list // Black
    beq !next+
vary_square:
    lda game.data__phase_cycle_board
    lsr
    tay
    lda game.curr_color_phase // Phase color
!next:
    sta curr_battle_square_color // Square color used to set battle arena border
    tya
    asl
    sta square_strength_adj_x2 // ??? Not used?
    sty square_strength_adj
    iny
    sty data__strength_adj_plus1 // ??? Not used?
    // Set A with light piece and Y with dark piece.
    lda common.data__icon_type
    ldy game.curr_challenge_icon_type
    bit game.flag__is_light_turn
    bpl !next+
    ldy common.data__icon_type
    lda game.curr_challenge_icon_type
!next:
    // Configure battle pieces
    sta common.data__icon_type
    tax
    lda board.data__piece_icon_offset_list,x
    sta common.idx__icon_offset
    sty magic.temp_selected_icon_store // ??? Not used?
    lda board.data__piece_icon_offset_list,y
    tay
    cpy #SHAPESHIFTER_OFFSET // Shapeshifter?
    bne !next+
    ldy common.idx__icon_offset //
!next:
    sty common.idx__icon_offset+1
    //
    // Do this for both the light and dark icons...
    ldx #$01
    // Create sprites at original coordinates on board. This will allow us to do the animation where the sprites slide
    // in to battle position.
!loop:
    // Create sprite group.
    jsr common.sprite_initialize
    lda #BYTERS_PER_STORED_SPRITE
    sta common.param__sprite_source_size
    jsr common.add_sprite_set_to_graphics
    // Place the sprite at the challenge square.
    lda board.data__curr_board_col
    ldy board.data__curr_board_row
    jsr board.convert_coord_sprite_pos

!next:
    rts // TODO remove


// 938D
interrupt_handler:
    jmp common.complete_interrupt // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// 8BAA
idx__sound_attack_pattern:
// Sound pattern used for attack sound of each icon type. The data is an index to the icon pattern pointer array
// defined above.
    //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
    .byte 12, 12, 12, 12, 12, 12, 16, 14, 12, 12, 12, 12, 12, 12, 18, 14, 12, 12, 12, 12

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCF2
// Current color of square in which a battle is being faught.
// TODO: WHY IS THIS DIFFERENT TO curr_square_color
curr_battle_square_color: .byte $00

// BD12
// Calculated strength adjustment based on color of the challenge square.
square_strength_adj: .byte $00

// BD23
// Color of square where challenge was initiated. Used for determining icon strength.
curr_square_color: .byte $00

// BF36
// Calculated strength adjustment based on color of the challenge square plus 1.
// Doesn't appear to be used in the code.
data__strength_adj_plus1: .byte $00

// BF41
// Calculated strength adjustment based on color of the challenge square times 2.
// Doesn't appear to be used in the code.
square_strength_adj_x2: .byte $00
