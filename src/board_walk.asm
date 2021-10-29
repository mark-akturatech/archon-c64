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
    lda  #<interrupt_handler
    sta  main.interrupt.system_fn_ptr
    lda  #>interrupt_handler
    sta  main.interrupt.system_fn_ptr+1
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
    //lda #$36
    //sta WBCDF // WHAT IS THIS? ////////////////////////////////////////// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
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
    // - Byte 4: byte 4: Row offset (00=1, 01=2 etc). The offset is mirrored for 2 pieces (eg 02 = Row 3 and 7). For
    //   07 pieces, row offset is the start row and other pieces are adde done after the other below it.
    // There are a total of 16 different piece types.
    lda piece.data,x
    sta main.temp.data__piece_type
    lda piece.data+1,x
    sta main.temp.data__num_pieces
    lda piece.data+2,x
    sta main.temp.data__current_board_col
    lda piece.data+3,x
    sta main.temp.data__current_board_row
    jsr animate_piece
    lda main.temp.data__piece_offset
    clc
    adc #$04 // 4 sprites per animation???
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
// Adds a piece to the board. Requires:
animate_piece:
    // todo
    rts

// 8FE6
interrupt_handler:
    jsr board.draw_magic_square
    lda main.state.flag_update
    bmi !next+
    jmp  common.complete_interrupt
!next:
    //.. TODO
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace piece {
    // 8dF6
    data: // Contains data for each board piece (type, number, location, row offset)
        .byte $03, $07, $01, $01, $14, $07, $07, $01
        .byte $01, $02, $01, $08, $12, $02, $07, $08
        .byte $00, $02, $00, $08, $13, $02, $08, $08
        .byte $02, $02, $00, $07, $15, $02, $08, $07
        .byte $04, $02, $00, $06, $17, $02, $08, $06
        .byte $06, $01, $00, $03, $1D, $01, $08, $05
        .byte $0A, $01, $00, $05, $19, $01, $08, $03
        .byte $08, $01, $00, $04, $1B, $01, $08, $04
}
