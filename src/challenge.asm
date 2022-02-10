.filenamespace challenge

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for challenge battles.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

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
    sta main.interrupt.raster_fn_ptr
    lda #>main.play_challenge
    sta main.interrupt.raster_fn_ptr+1
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
    ldy main.temp.data__curr_board_row
    sty main.temp.data__curr_icon_row
    lda board.data.row_color_offset_lo_ptr,y
    sta CURLIN
    lda board.data.row_color_offset_hi_ptr,y
    sta CURLIN+1
    ldy main.temp.data__curr_board_col
    sty main.temp.data__curr_icon_col
    lda (CURLIN),y
    sta curr_square_color // Color of the sqauare - I don't think this is used anywhere
    // Get the battle sqauer color (a) and a number between 0 and 7 (y). 0 is strongest on black, 7 is strongest on
    // white.
    beq dark_square
    bmi vary_square
    ldy #$07
    lda board.data.square_colors__square+1 // White
    bne !next+
dark_square:
    ldy #$00
    lda board.data.square_colors__square // Black
    beq !next+
vary_square:
    lda main.state.curr_cycle+3
    lsr
    tay
    lda game.curr_color_phase // Phase color
!next:
    sta main.temp.curr_battle_square_color // Square color used to set battle arena border
    tya
    asl
    sta square_strength_adjx2 // ??? Not used?
    sty square_strength_adj
    iny
    sty main.temp.data__light_icon_count // ??? Not used?
    // Set A with light piece and Y with dark piece.
    lda board.icon.type
    ldy game.curr_challenge_icon_type
    bit game.state.flag__is_light_turn
    bpl !next+
    ldy board.icon.type
    lda game.curr_challenge_icon_type
!next:
    // Configure battle pieces
    sta board.icon.type
    tax
    lda board.icon.init_matrix,x
    sta board.icon.offset
    sty magic.temp_selected_icon_store // ??? Not used?
    lda board.icon.init_matrix,y
    tay
    cpy #SHAPESHIFTER_OFFSET // Shapeshifter?
    bne !next+
    ldy board.icon.offset // 
!next:
    sty board.icon.offset+1
    //
    // Do this for both the light and dark icons...    
    ldx #$01
    // Create sprites at original coordinates on board. This will allow us to do the animation where the sprites slide
    // in to battle position.
!loop:
    // Create sprite group.
    jsr board.sprite_initialize
    lda #BYTERS_PER_STORED_SPRITE
    sta board.sprite.copy_length
    jsr board.add_sprite_set_to_graphics
    // Place the sprite at the challenge square.
    lda main.temp.data__curr_board_col
    ldy main.temp.data__curr_board_row
    jsr board.convert_coord_sprite_pos

!next:
    rts // TODO remove


// 938D
interrupt_handler:
    jmp common.complete_interrupt // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
.segment DynamicData

// BD12
square_strength_adj: .byte $00 // Calculated strength adjustment based on color of the challenge square.

// BD23
curr_square_color: .byte $00 // Color of square where challenge was initiated. Used for determining icon strength.

// BF41
// Calculated strength adjustment based on color of the challenge square TIMES 2.
// Doesn't appear to be used in the code.
square_strength_adjx2: .byte $00
