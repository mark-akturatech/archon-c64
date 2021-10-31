.filenamespace board_walk

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for displaying and animating the board setup animations.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment BoardWalk

// 8E36
entry:
    jsr common.clear_screen
    //Configure graphics area again. We seem to do this alot.
    lda #%0001_0010
    sta VMCSB

    // Enable multicolor text mode again.
    lda SCROLX
    ora #%0001_0000
    sta SCROLX
    // Set interrupt handler to set intro loop state.
    // Thinking this should have a SEI and CLI wrapping it, but it doesn't.
    lda #<interrupt_handler
    sta main.interrupt.system_fn_ptr
    lda #>interrupt_handler
    sta main.interrupt.system_fn_ptr+1
    // Set sprite second colour to black; exand all spites except 7 in X direction and expand only sprite 7 in y
    // direction.
    lda #$00
    sta main.temp.data__piece_offset
    sta SPMC0
    sta YXPAND
    lda #%1000_0000
    sta XXPAND
    lda %0111_1111
    sta SPMC
    lda #$36 // 54 bytes per sprite
    sta board.sprite.copy_length
    //
    // Adds piece types to the board one at a time. Each piece is added by animating it (flying or walking) to the
    // piece's square.
    // The anitmation is performed using sprites that are loaded in to the first four sprite slots for each piece. After
    // the animation is completed, the piece is drawn on to the square using character set characters.
    // The board is redrawn for each piece.
    // The board current player indication (border color) is toggled as each side's piece is loaded.
    // The board is a 9x9 grid.
    // For description purposes, we'll number board squares as A-I across the top starting from left and 1 to 9 on the
    // sides starting at the bottom.
add_piece:
    jsr common.clear_sprites
    jsr board.set_player_color
    jsr board.draw_board
    jsr board.draw_border
    jsr board.create_magic_square_sprite
    ldx main.temp.data__piece_offset
    // Read piece and location.
    // Each piece is represented as 4 bytes in a table.
    // - Byte 1: Piece type/Sprite offset
    // - Byte 2: Number of pieces of the type (Only accepts 07, 02, and 01)
    // - Byte 3: Intitial column (00 = A, 01 = B etc)
    // - Byte 4: Row offset (00=1, 01=2 etc). The offset is mirrored for 2 pieces (eg 02 = Row 3 and 7). For 07 pieces
    //   row offset is the start row and other pieces are adde done after the other below it.
    // There are a total of 16 different piece types.
    lda piece.data,x
    sta board.character.piece_type
    lda piece.data+1,x
    sta main.temp.data__num_pieces
    lda piece.data+2,x
    sta main.temp.data__current_board_col
    lda piece.data+3,x
    sta main.temp.data__current_board_row
    jsr animate_piece
    lda main.temp.data__piece_offset
    clc
    adc #$04
    cmp #(16 * 4) // Check if finished (16 piece types * 4 data bytes)
    bcc !next+
    rts
!next:
    sta main.temp.data__piece_offset
    // Toggle current player.
    lda board.flag__current_player
    eor #$FF
    lda board.flag__current_player
    jmp add_piece

// 8EB0
// Adds a piece to the board.
animate_piece:
    ldx #$04 // TODO: WHY 4?
    lda main.temp.data__current_board_col
    ldy main.temp.data__current_board_row
    jsr board.convert_coord_sprite_pos
    sta main.temp.data__sprite_final_x_pos
    sty main.temp.data__sprite_final_y_pos
    lda main.temp.data__num_pieces
    cmp #$07 // Adding 7 pieces (knights, goblins)?
    bne !next+
    sta main.temp.data__current_board_row // Start at row 7
add_7_pieces:
    jsr board.add_piece_to_matrix
    dec main.temp.data__current_board_row
    bne add_7_pieces
    lda #$01 // Unused code?
    ldx #$10
    stx main.temp.data__sprite_y_offset
    jmp add_piece_to_board
!next:
    jsr board.add_piece_to_matrix
    lda main.temp.data__num_pieces
    cmp #$02 // Adding 2 pieces?
    bcc add_piece_to_board
    // Add 2 pieces.
    lda main.temp.data__current_board_row
    sta main.temp.data__curr_line
    lda #$08
    sec
    sbc main.temp.data__current_board_row
    sta main.temp.data__current_board_row
    jsr board.add_piece_to_matrix
    lda main.temp.data__curr_line
    sec
    sbc main.temp.data__current_board_row
    bcs !next+
    eor #$FF
    adc #$01
!next:
    asl
    asl
    asl
    asl
    eor #$FF
    adc #$01
    sta main.temp.data__sprite_y_offset
add_piece_to_board:
    // Creates sprites for each piece and animates them walking/flying in to the board position.
    lda #$00 // Starting X position
    ldy #$04 // Pixels to move each frame
    ldx board.flag__current_player
    bpl !next+ // Start at right side and move to the left for player 2
    lda #$94
    ldy #$FC 
!next:
    sty main.temp.data__x_pixels_per_move
    sta main.temp.data__curr_x_pos
    ldx main.temp.data__num_pieces
    dex
    stx main.temp.data__curr_sprite_count
!loop:
    lda main.temp.data__curr_x_pos
    sta main.sprite.curr_x_pos,x
    dex
    clc
    adc main.temp.data__x_pixels_per_move
    sta main.sprite.curr_x_pos,x
    dex
    bpl !loop-
    ldx #$06
!loop:
    txa
    asl
    tay
    lda #$00
    sta SP0Y,y
    dex
    bpl !loop-
    //
    ldx #$00
    stx intro.sprite.animation_counter
    ldy board.character.piece_type
    lda board.character.setup_matrix,y
    sta board.character.piece_offset
    jsr board.sprite_initialize
    // Configure sprites.
    lda #%1111_1111 // Enable all sprites
    sta SPENA
    lda #1000_0000 // Set sprite 7 expanded, all other normal
    sta XXPAND
    lda #%0111_1111 // Enable multicolor more on all sprites except 7
    sta SPMC
    lda #BLACK // Set multicolor background color to black
    sta SPMC0
    // Calculate starting Y position and color of each sprite.
    ldx main.temp.data__curr_sprite_count
!loop:
    lda SP0COL
    sta SP0COL,x
    lda main.temp.data__sprite_final_y_pos
    sta main.sprite.curr_y_pos,x
    clc
    adc main.temp.data__sprite_y_offset
    sta main.temp.data__sprite_final_y_pos
    dex
    bpl !loop-
    // Load sprites in to graphical memory. Add first 4 frames of the sprite character set.
    lda #$80
    sta board.sprite.copy_character_set_flag
    and board.flag__current_player
    sta main.temp.data__character_sprite_frame
    lda #$04
    sta main.temp.data__frame_count
    lda main.sprite._00_memory_ptr
    sta FREEZP+2
    sta main.temp.data__sprite_y_direction_offset
    lda main.sprite._00_memory_ptr+1
    sta FREEZP+3
    ldx #$00
!loop:
    jsr board.add_sprite_to_graphics
    lda main.temp.data__sprite_y_direction_offset
    clc
    adc #$40
    sta FREEZP+2
    sta main.temp.data__sprite_y_direction_offset
    bcc !next+
    inc FREEZP+3
!next:
    inc main.temp.data__character_sprite_frame
    dec main.temp.data__frame_count
    bne !loop-
    // Display piece name.
    jsr board.clear_text_area
    ldy board.character.piece_offset
    lda board.character.string_id,y
    ldx #$0A // Column offset 10
    jsr board.write_text
    // Set character sound.
    jsr board.get_sound_for_piece
    lda board.sound.phrase_lo_ptr
    sta OLDTXT // pointer to sound phrase
    lda board.sound.phrase_hi_ptr
    sta OLDTXT+1                  
    lda #$80                         
    sta common.sound.current_phrase_data_fn_ptr  // <<< I THINK THIS IS USED FOR SOMETHING ELSE
    jsr common.wait_for_key
    rts

// 8FE6
interrupt_handler:
    jsr board.draw_magic_square
    lda main.state.flag_update
    bpl !next+
    jmp common.complete_interrupt
!next:
    //.. TODO
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace piece {
    // 8DF6
    data: // Contains data for each board piece (type, number, location, row offset)
        .byte KNIGHT, $07, $01, $01
        .byte GOBLIN, $07, $07, $01
        .byte ARCHER, $02, $01, $08
        .byte MANTICORE, $02, $07, $08
        .byte VALKYRIE, $02, $00, $08
        .byte BANSHEE, $02, $08, $08
        .byte GOLEM, $02, $00, $07
        .byte TROLL, $02, $08, $07
        .byte UNICORN, $02, $00, $06
        .byte BASILISK, $02, $08, $06
        .byte DJINNI, $01, $00, $03
        .byte DRAGON, $01, $08, $05
        .byte PHOENIX, $01, $00, $05
        .byte SHAPESHIFTER, $01, $08, $03
        .byte WIZARD, $01, $00, $04
        .byte SORCERESS, $01, $08, $04
}
