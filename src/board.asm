.filenamespace board

//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used for rendering the game board.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

.segment Common

// 62EB
// Gets sound for the current piece.
// X may be 0 or 1, allowing sound to be retrieved for both characters in a battle.
get_sound_for_piece:
    ldy piece.offset,x
    lda sound.character_phrase,y
    tay
    lda sound.phrase_ptr,y
    sta sound.phrase_lo_ptr,x
    lda sound.phrase_ptr+1,y
    sta sound.phrase_hi_ptr,x
    rts

// 6422
// Converts a board row and column coordinate to a corresponding sprite screen position.
// Requires:
// - A Register: Board column
// - Y Register: Board row
// - X Register: Sprite number
// Sets `sprite.curr_x_pos,x` and `sprite.curr_y_pos,x` with the calculated position for all sprites except
// sprite number 4.
// Returns calculated X position in A register and Y position in Y register.
convert_coord_sprite_pos:
    // Calculate X position.
    pha
    asl
    asl
    asl
    sta main.temp.data__math_store
    pla
    asl
    asl
    clc
    adc main.temp.data__math_store
    clc
    adc #$1A
    cpx #$04
    bcs !next+
    sta common.sprite.curr_x_pos,x
!next:
    pha
    // Calculate Y position.
    tya
    asl
    asl
    asl
    asl
    clc
    adc #$17
    cpx #$04
    bcs !next+
    sta common.sprite.curr_y_pos,x
!next:
    tay
    pla
    rts

// 644D
// Determine sprite source data address for a given peice, set the sprite color and direction and enable.
sprite_initialize:
    lda piece.offset,x
    asl
    tay
    lda sprite.piece_offset,y
    sta sprite.copy_source_lo_ptr,x
    lda sprite.piece_offset+1,y
    sta sprite.copy_source_hi_ptr,x
    lda piece.type,x
    cmp #AIR_ELEMENTAL // Is sprite an elemental?
    bcc !next+
    and  #$03
    tay
    lda sprite.elemental_color,y
    bpl intialize_enable_sprite
!next:
    ldy #$00 // Set Y to 0 for light piece, 1 for dark piece
    cmp #MANTICORE // Dark piece
    bcc !next+
    iny
!next:
    lda sprite.piece_color,y
intialize_enable_sprite:
    sta SP0COL,x
    lda main.math.pow2,x
    ora SPENA
    sta SPENA
    lda piece.offset,x
    and #$08 // Pieces with bit 8 set are dark pieces
    beq !next+
    lda #$11
!next:
    sta common.sprite.init_animation_frame,x
    rts

// 6509
// Writes a predefined text message to the board text area.
// Requires:
// - A regsiter set with the text message offset.
// - X register with column offset.
write_text:
    asl
    tay
    lda screen.message_ptr,y
    sta FREEZP
    lda screen.message_ptr+1,y
    sta FREEZP+1
    ldy #$00
!loop:
    lda (FREEZP),y
    bpl !next+
    rts
!next:
    // Convert petscii to correct game character map offset.
    and #$3F
    clc
    adc #$C0
    sta (SCNMEM+23*CHARS_PER_SCREEN_ROW),x
    inx
    iny
    jmp !loop-

// 8965
// Adds a piece to the board matrix.
// Requires the board row and column to be set in the temp data.
add_piece_to_matrix:
    ldy main.temp.data__curr_board_row
    lda game.data.row_occupancy_lo_ptr,y
    sta OLDLIN
    lda game.data.row_occupancy_hi_ptr,y
    sta OLDLIN+1
    //
    ldy main.temp.data__curr_board_col
    lda piece.type
    sta (OLDLIN),y
    rts

// 8C6D
// Copies a sprite frame in to graphical memory.
// Also includes additional functionality to add a mirrored sprite to graphics memory.
add_sprite_to_graphics:
    lda main.temp.data__character_sprite_frame
    and #$7F // The offset has #$80 if the sprite frame should be inverted on copy
    // Get frame source memory address.
    // This is done by first reading the sprite source offset of the character set and then adding the frame offset.
    asl
    tay
    lda sprite.frame_offset,y
    clc
    adc sprite.copy_source_lo_ptr,x
    sta FREEZP
    lda sprite.copy_source_hi_ptr,x
    adc sprite.frame_offset+1,y
    sta FREEZP+1
//     lda  board_sprite_flag__copy_animation_group // TODO!!!!!!!!!!!!! - I think the copy below copies and entire sprite character set
//     bmi  board_move_sprite
//     cpx  #$02
//     bcc  board_move_sprite
//     txa
//     and  #$01
//     tay
//     lda  board_character_piece_offset,y
//     and  #$07
//     cmp  #$06
//     bne  W8CA3
//     lda  #$FF
//     sta  board_sprite_copy_length
//     jmp  board_move_sprite

// W8CA3:
//     ldy  #$00
// W8CA5:
//     lda  main_temp_data__character_sprite_frame
//     bpl  W8CBF
//     lda  #$08
//     sta  temp_data__curr_color
//     lda  (io_FREEZP),y
//     sta  temp_ptr__sprite
// W8CB4:
//     ror  temp_ptr__sprite
//     rol
//     dec  temp_data__curr_color
//     bne  W8CB4
//     beq  W8CC1
// W8CBF:
//     lda  (io_FREEZP),y
// W8CC1:
//     sta  (io_FREEZP+2),y
//     inc  io_FREEZP+2
//     inc  io_FREEZP+2
//     iny
//     cpy  board_sprite_copy_length
//     bcc  W8CA5
//     rts
move_sprite:
    ldy #$00
    lda main.temp.data__character_sprite_frame
    bmi move_sprite_and_invert
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    cpy sprite.copy_length
    bcc !loop-
    rts
// Mirror the sprite on copy - used for when sprite is moving in the opposite direction.
move_sprite_and_invert:
    lda #$0A
    sta main.temp.data__temp_store // Sprite is inverted in 10 blocks
    tya
    clc
    adc #$02
    tay
    lda (FREEZP),y
    sta main.temp.data__temp_store+3
    dey
    lda (FREEZP),y
    sta main.temp.data__temp_store+2
    dey
    lda (FREEZP),y
    sta main.temp.data__temp_store+1
    lda #$00
    sta main.temp.data__temp_store+4
    sta main.temp.data__temp_store+5
!loop:
    jsr invert_bytes
    jsr invert_bytes
    pha
    and #$C0
    beq !next+
    cmp #$C0
    beq !next+
    pla
    eor #$C0
    jmp !next++
!next:
    pla
!next:
    dec main.temp.data__temp_store
    bne !loop-
    sta (FREEZP+2),y
    iny
    lda main.temp.data__temp_store+4
    sta (FREEZP+2),y
    iny
    lda main.temp.data__temp_store+5
    sta (FREEZP+2),y
    iny
    cpy sprite.copy_length
    bcc move_sprite_and_invert
    rts
invert_bytes:
    rol main.temp.data__temp_store+3
    rol main.temp.data__temp_store+2
    rol main.temp.data__temp_store+1
    ror
    ror main.temp.data__temp_store+4
    ror main.temp.data__temp_store+5
    rts


// 8D6E
// Places a sprite at a given location and enables the sprite.
// The following prerequisites are required:
// - X register is loaded with the sprite number to be enabled.
// - The sprite frame ofsfetis set
// - The sprite location is set in `main_sprite_curr_x_pos` and ``main_sprite_curr_y_pos`.
render_sprite:
    txa
    asl
    tay
    lda common.sprite.number,x
    and #$03 // Ensure sprite number is between 0 and 3 to allow multiple animation frames for each sprite id
    clc
    adc common.sprite.init_animation_frame,x
    adc main.sprite.offset_00,x
    sta SPTMEM,x
// 8D80
// Places a sprite at a given location and enables the sprite.
// The following prerequisites are required:
// - The sprite location is set in `main_sprite_curr_x_pos` and `main_sprite_curr_y_pos`.
// - X register is loaded with the sprite number to be enabled.
// - Y register is loaded with 2 * the sprite number to be enabled.
// The Y position is offset by 50 and X position is doubled and then offset by 24.
render_sprite_preconf:
    lda common.sprite.curr_y_pos,x
    clc
    adc #$32
    sta SP0Y,y
    //
    lda common.sprite.curr_x_pos,x
    clc
    adc common.sprite.curr_x_pos,x
    sta main.temp.data__math_store_1
    lda #$00
    adc #$00
    sta main.temp.data__math_store_2
    lda main.temp.data__math_store_1
    adc #$18
    sta SP0X,y
    lda main.temp.data__math_store_2
    adc #$00
    beq !next+
    lda MSIGX
    ora main.math.pow2,x
    sta MSIGX
    rts
!next:
    lda main.math.pow2,x
    eor #$FF
    and MSIGX
    sta MSIGX
    rts

// 915B
// Inverts the color character dot data in character memory for the player tile. The character is a square block that is
// toggled between two different color bits.
// This works as the current player flag has two uses. First it is positive (< 128) or negative (>= 128) to indicate
// current player (positive is player 1). Second, it used to fill the player character tile as the flag toggles
// between $55 and $aa which makes the tile solid color 1 or solid color 2.
set_player_color:
    .const player_dot_data_offset = $600 // Offset of character dot data for player tile
    lda #<(CHRMEM2 + player_dot_data_offset)
    sta FREEZP+2
    lda #>(CHRMEM2 + player_dot_data_offset)
    sta FREEZP+3
    ldy #$07
    lda game.state.flag__is_curr_player_light
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 9076
// Draws the board squares and renders the occupied characters on the board. The squares are colored according to the
// color matrix and the game current color phase.
// Each sqaure is 3 characters wide and 2 characters high.
draw_board:
    ldx #$02
!loop:
    lda data.square_colors__piece,x
    sta BGCOL0,x
    dex
    bpl !loop-
    lda data.square_colors__piece
    sta EXTCOL
    //
    lda #(BOARD_NUM_ROWS - 1) // Number of rows (0 based, so 9)
    sta main.temp.data__curr_row
    // Draw each board row.
draw_row:
    lda #(BOARD_NUM_COLS - 1) // Number of columns (0 based, so 9)
    sta main.temp.data__curr_column
    ldy main.temp.data__curr_row
    //
    lda data.row_screen_offset_lo_ptr,y
    sta FREEZP+2 // Screen offset
    sta VARPNT // Color memory offset
    lda data.row_screen_offset_hi_ptr,y
    sta FREEZP+3
    clc
    adc main.screen.color_mem_offset
    sta VARPNT+1
    //
    lda game.data.row_occupancy_lo_ptr,y
    sta FREEZP // Square occupancy
    lda game.data.row_occupancy_hi_ptr,y
    sta FREEZP+1
    //
    lda data.row_color_offset_lo_ptr,y
    sta CURLIN // Square color
    lda data.row_color_offset_hi_ptr,y
    sta CURLIN+1
    //
draw_square:
    ldy main.temp.data__curr_column
    bit flag__render_square_control
    bvs render_square // Disable piece render
    bpl render_piece
    // Only render piece for a given row and coloumn.
    lda #FLAG_ENABLE // disable square render (set to piece offset to render a piece)
    sta render_sqaure_piece_offset
    lda main.temp.data__curr_board_col
    cmp main.temp.data__curr_column
    bne draw_empty_square
    lda main.temp.data__curr_board_row
    cmp main.temp.data__curr_line
    bne draw_empty_square
render_piece:
    lda (FREEZP),y
    bmi !next+ // if $80 (blank)
    tax
    lda piece.init_matrix,x  // Get character dot data offset
!next:
    sta render_sqaure_piece_offset
    bmi draw_empty_square
    // Here we calculate the piece starting piece. We do this as follows:
    // - Set $60 if the piece has a light or variable color background
    // - Multiply the piece offset by 6 to allow for 6 characters per piece type
    // - Add both together to get the actual character starting offset
    ldx #$06 // Each piece compriss a block 6 characters (3 x 2)
    lda (CURLIN),y  // Get sqaure background color (will be 0 for dark, 60 for light and variable)
    and #$7F
!loop:
    clc
    adc render_sqaure_piece_offset
    dex
    bne !loop-
    sta main.temp.data__board_piece_char_offset
    jmp render_square
draw_empty_square:
    lda (CURLIN),y
    and #$7F
    sta main.temp.data__board_piece_char_offset
render_square:
    // Draw the square. Squares are 2x2 characters. The start is calculated as follows:
    // - offset = row offset + (current column * 2) + current column
    // We call `render_sqaure_row` which draws 2 characters. We then increase the offset by 40 (moves to next line)
    // and call `render_sqaure_row` again to draw the next two characters.
    lda (CURLIN),y
    bmi !next+
    lda data.square_colors__square+1
    bpl !skip+
!next:
    lda game.curr_color_phase
!skip:
    ora #$08 // Derive square color
    sta main.temp.data__curr_square_color_code
    lda main.temp.data__curr_column
    asl
    clc
    adc main.temp.data__curr_column
    tay
    jsr draw_sqaure_part
    lda main.temp.data__curr_column
    asl
    clc
    adc main.temp.data__curr_column
    adc #CHARS_PER_SCREEN_ROW
    tay
    jsr draw_sqaure_part
    //
    dec main.temp.data__curr_column
    bpl draw_square
    dec main.temp.data__curr_row
    bmi !return+
    jmp draw_row
!return:
    rts
draw_sqaure_part: // Draws 3 characters of the current row.
    lda #$03
    sta main.temp.data__counter
!loop:
    lda main.temp.data__board_piece_char_offset
    sta (FREEZP+2),y
    lda (VARPNT),y
    and #$F0
    ora main.temp.data__curr_square_color_code
    sta (VARPNT),y
    iny
    lda render_sqaure_piece_offset
    bmi !next+
    // Draw the board piece. The piece comprises 4 contiguous characters.
    inc main.temp.data__board_piece_char_offset
!next:
    dec main.temp.data__counter
    bne !loop-
    rts

// 916E
// Draws a border around the board.
draw_border:
    .const BORDER_CHARACTER = $C0
    // Draw top border.
    lda data.row_screen_offset_lo_ptr
    sec
    sbc #(CHARS_PER_SCREEN_ROW + 1) // 1 row and 1 character before start of board
    sta FREEZP+2 // Screen offset
    sta FORPNT // Color memory offset
    lda data.row_screen_offset_hi_ptr
    sbc #$00
    sta FREEZP+3
    clc
    adc main.screen.color_mem_offset
    sta FORPNT+1
    ldy #(BOARD_NUM_COLS*3 + 1) // 9 squares (3 characters per square) + 1 character each side of board (0 based)
!loop:
    lda #BORDER_CHARACTER // Border character
    sta (FREEZP+2),y
    lda (FORPNT),y // Set border color
    and #$F0
    ora #$08
    sta (FORPNT),y
    dey
    bpl !loop-
    // Draw side borders.
    ldx #(BOARD_NUM_ROWS*2) //  9 squares (2 characters per square)
!loop:
    lda FREEZP+2
    clc
    adc #CHARS_PER_SCREEN_ROW
    sta FREEZP+2
    sta FORPNT
    bcc !next+
    inc FREEZP+3
    inc FORPNT+1
!next:
    ldy #$00 // Left border
    lda #BORDER_CHARACTER
    sta (FREEZP+2),y
    lda (FORPNT),y
    and #$F0
    ora #$08
    sta (FORPNT),y
    ldy #$1C // Right border
    lda #BORDER_CHARACTER
    sta (FREEZP+2),y
    lda (FORPNT),y
    and #$F0
    ora #$08
    sta (FORPNT),y
    dex
    bne !loop-
    // Draw bottom border.
    lda FREEZP+2
    clc
    adc #CHARS_PER_SCREEN_ROW
    sta FREEZP+2
    sta FORPNT
    bcc !next+
    inc FREEZP+3
    inc FORPNT+1
!next:
    ldy #(BOARD_NUM_COLS*3 + 1) // 9 squares (3 characters per square) + 1 character each side of board (0 based)
!loop:
    lda #BORDER_CHARACTER
    sta (FREEZP+2),y
    lda (FORPNT),y
    and #$F0
    ora #$08
    sta (FORPNT),y
    dey
    bpl !loop-
    rts

// 91FB
// Creates sprites in 56 and 57 from character dot data (creates "ARCHON"), position the sprites above the board,
// set the sprite color to current player color and enable as sprite 2 and 3.
create_logo:
    lda main.sprite.mem_ptr_56
    sta FREEZP+2 // Sprite location
    sta main.temp.data__temp_store
    sta main.temp.data__temp_store+1
    lda main.sprite.mem_ptr_56+1
    sta FREEZP+3
    lda #$03 // Number of letters per sprite
    sta main.temp.data__temp_store+2
    ldx #$00
convert_logo_character:
    lda sprite.logo_string,x // Get logo letter
    // Convert character to dot data offset.
    and #$3F
    asl
    asl
    asl
    sta FREEZP // Character dot data offset
    .const UPPERCASE_OFFSET = $600
    lda #>(CHRMEM2 + UPPERCASE_OFFSET)
    adc #$00
    sta FREEZP+1
    ldy #$00
copy_character_to_sprite:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    inc FREEZP+2
    inc FREEZP+2
    cpy #$08
    bcc copy_character_to_sprite
    // Set next letter.
    inc main.temp.data__temp_store
    lda main.temp.data__temp_store
    sta FREEZP+2
    dec main.temp.data__temp_store+2
    bne !next+
    // Sprite full - Move to next sprite.
    lda #$03
    sta main.temp.data__temp_store+2
    lda main.temp.data__temp_store+1
    clc
    adc #BYTES_PER_SPRITE
    sta FREEZP+2
    sta main.temp.data__temp_store
    bne !next+
    inc FREEZP+3
!next:
    inx
    cpx #$06 // Logo has 6 letters (ARCHON)
    bcc convert_logo_character
    // Configure and enable sprites.
    lda #$38 // Place above board (positions hard coded)
    sta SP2Y
    sta SP3Y
    lda #$84
    sta SP2X
    lda #$B4
    sta SP3X
    lda #((VICGOFF / BYTES_PER_SPRITE) + 56) // should use main.sprite.offset_56 but source doesn't :(
    sta SPTMEM+2
    lda #((VICGOFF / BYTES_PER_SPRITE) + 57)
    sta SPTMEM+3
    rts

// 927A
// Create the sprite used to indicate a magic board square.
// The sprite is stored in sprite offset 48.
create_magic_square_sprite:
    lda main.sprite.mem_ptr_48
    sta FREEZP+2
    lda main.sprite.mem_ptr_48+1
    sta FREEZP+3
    ldx #$00
    ldy #$00
!loop:
    lda sprite.magic_sqauare_data,x
    sta (FREEZP+2),y
    iny
    iny
    iny
    inx
    cpx #$0C
    bcc !loop-
    // Set sprite color.
    lda #LIGHT_GRAY
    sta SP0COL+7
    rts

// 92BB
draw_magic_square:
    ldy magic_square_counter
    iny
    cpy #$05 // Total number of magic sqaures
    bcc !next+
    ldy #$00
!next:
    .const SPRITE_NUMBER=7
    sty magic_square_counter
    lda sprite.magic_square_x_pos,y
    sta common.sprite.curr_x_pos+SPRITE_NUMBER
    lda sprite.magic_square_y_pos,y
    sta common.sprite.curr_y_pos+SPRITE_NUMBER
    //
    ldx #SPRITE_NUMBER
    lda main.sprite.offset_48
    sta SPTMEM+SPRITE_NUMBER
    ldy #(SPRITE_NUMBER*2)
    jmp render_sprite_preconf


// 92EB
create_selection_square:
    lda main.sprite.mem_ptr_24
    sta FREEZP+2 // Sprite location
    lda main.sprite.mem_ptr_24+1
    sta FREEZP+3
    ldy #$00
    jsr selection_square__vert_line
    // Draw sides.
    ldx #$10 // 16 pixels high
!loop:
    lda #$C0 // Hard coded sprite dot data
    sta (FREEZP+2),y
    iny
    lda #$18 // Hard coded sprite dot data
    sta (FREEZP+2),y
    iny
    iny
    dex
    bne !loop-
    jsr selection_square__vert_line
    rts
// Draw top/bottom.
selection_square__vert_line:
    ldx #$02
!loop:
    lda #$FF // Hard coded sprite dot data
    sta (FREEZP+2),y
    iny
    lda #$F8 // Hard coded sprite dot data
    sta (FREEZP+2),y
    iny
    iny
    dex
    bne !loop-
    rts

// 9352
// Clear text area underneath the board and reset the color to white.
clear_text_area:
    ldx #(CHARS_PER_SCREEN_ROW*2-1) // Two rows of text
!loop:
    lda #$00
    sta SCNMEM+23*CHARS_PER_SCREEN_ROW,x // Start at 23rd text row
    lda COLRAM+23*CHARS_PER_SCREEN_ROW,x
    and #$F0
    ora #$01
    sta COLRAM+23*CHARS_PER_SCREEN_ROW,x
    dex
    bpl !loop-
    rts

// 8948
clear_text_row:
    ldy #(CHARS_PER_SCREEN_ROW - 1)
    lda #$00
!loop:
    sta SCNMEM+24*CHARS_PER_SCREEN_ROW,y
    dey
    bpl !loop-
    rts

// A0B1
// Plays a character movement or shoot sound.
play_character_sound:
    ldx #$01
    // Character sounds can be played on voices 1 and 2 sepparately. this allows two character movement sounds to be
    // played at the same time.
    // If 00, then means don't play sound for that piece.
!loop:
    lda common.sound.flag__enable_voice,x
    beq !next+
    jsr play_voice
!next:
    dex
    bpl !loop-
    rts
play_voice:
    lda common.sound.new_note_delay,x
    beq configure_voice
    dec common.sound.new_note_delay,x
    bne !return+
configure_voice:
    txa
    asl
    tay
    lda common.sound.note_data_fn_ptr,y
    sta common.sound.curr_note_data_fn_ptr
    lda common.sound.note_data_fn_ptr+1,y
    sta common.sound.curr_note_data_fn_ptr+1
    lda common.sound.voice_io_addr,y
    sta FREEZP+2 // SID voice address
    lda common.sound.voice_io_addr+1,y
    sta FREEZP+3
get_next_note:
    jsr common.get_note
    cmp #SOUND_CMD_NEXT_PHRASE // Repeat phrase
    beq repeat_phrase
    cmp #SOUND_CMD_END // Finished - turn off sound
    beq stop_sound
    cmp #SOUND_CMD_NO_NOTE // Stop note
    bne get_note_data
    ldy #$04
    sta (FREEZP+2),y
    jmp get_next_note
get_note_data:
    // If the phrase data is not a command (ie FE, FF or 00), then the data represents a note. A note comprises several
    // bytes as follows:
    // - 00: Delay/note hold
    // - 01: Attack/decay
    // - 02: Sustain/Release
    // - 03: Frequency Lo
    // - 04: Frequency Hi
    // - 05: Voice control (wafeform etc)
    sta common.sound.new_note_delay,x
    jsr common.get_note
    ldy #$05
    sta (FREEZP+2),y
    jsr common.get_note
    ldy #$06
    sta (FREEZP+2),y
    jsr common.get_note
    ldy #$00
    sta (FREEZP+2),y
    jsr common.get_note
    ldy #$01
    sta (FREEZP+2),y
    jsr common.get_note
    ldy #$04
    sta (FREEZP+2),y
!return:
    rts
repeat_phrase:
    txa
    asl
    tay
    lda board.sound.phrase_lo_ptr,x
    sta OLDTXT,y
    lda board.sound.phrase_hi_ptr,x
    sta OLDTXT+1,y
    jmp get_next_note
stop_sound:
    ldy #$04
    lda #$00
    sta (FREEZP+2),y
    sta common.sound.flag__enable_voice,x
    sta common.sound.new_note_delay,x
    rts

// AE12
interrupt_handler:
    jsr draw_magic_square
    lda main.interrupt.flag__enable
    bmi !return+
    jmp (main.state.curr_fn_ptr)
interrupt_handler__play_music:
    jsr common.play_music
!return:
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace data {
    .const ROW_START_OFFSET = $7e
    .const ROWS_PER_SQUARE = 2

    // 0B5D
    .enum { DARK = $00, LITE = $60, VARY = $E0 }
    sqaure_color: // Board sqaure colors
        .byte DARK, LITE, DARK, VARY, VARY, VARY, LITE, DARK, LITE
        .byte LITE, DARK, VARY, LITE, VARY, DARK, VARY, LITE, DARK
        .byte DARK, VARY, LITE, DARK, VARY, LITE, DARK, VARY, LITE
        .byte VARY, LITE, DARK, LITE, VARY, DARK, LITE, DARK, VARY
        .byte LITE, VARY, VARY, VARY, VARY, VARY, VARY, VARY, DARK
        .byte VARY, LITE, DARK, LITE, VARY, DARK, LITE, DARK, VARY
        .byte DARK, VARY, LITE, DARK, VARY, LITE, DARK, VARY, LITE
        .byte LITE, DARK, VARY, LITE, VARY, DARK, VARY, LITE, DARK
        .byte DARK, LITE, DARK, VARY, VARY, VARY, LITE, DARK, LITE

    // 6323
    magic_square_col: .byte $4A, $1A, $4A, $4A, $7A // Column of each magic square (used with magic_square_row)

    // 6328
    magic_square_row: .byte $17, $57, $57, $97, $57 // Row of each magic square (used with magic_square_col)

    // 8BD2
    color_phase: // Colors used for each board game phase
        .byte BLACK, BLUE, RED, PURPLE, GREEN, YELLOW, CYAN, WHITE

    // 9071
    square_colors__square: // Board sqaure colors
        .byte BLACK, WHITE

    // 9073
    square_colors__piece: // Board background colors used when rendering the player board
        .byte BLACK, YELLOW, LIGHT_BLUE

    // BEAE
    row_screen_offset_lo_ptr: // Low byte screen memory offset of start of each board row
        .fill BOARD_NUM_COLS, <(ROW_START_OFFSET + i * ROWS_PER_SQUARE * CHARS_PER_SCREEN_ROW)

    // BEB7
    row_screen_offset_hi_ptr: // High byte screen memory offset of start of each board row
        .fill BOARD_NUM_COLS, >(SCNMEM + ROW_START_OFFSET + i * ROWS_PER_SQUARE * CHARS_PER_SCREEN_ROW)

    // BED2
    row_color_offset_lo_ptr: // Low byte memory offset of sqaure color data for each board row
        .fill BOARD_NUM_COLS, <(sqaure_color + i * BOARD_NUM_COLS)

    // BEDB
    row_color_offset_hi_ptr: // High byte memory offset of sqaure color data for each board row
        .fill BOARD_NUM_COLS, >(sqaure_color + i * BOARD_NUM_COLS)
}

.namespace sprite {
    // 8B27
    // Source offset of the first frame of each character piece sprite. A character comprises of multiple sprites
    // (nominally 15) to provide animations for each direction and action. One character, the Shape Shifter, comprises
    // only 10 sprites though as it doesn't need a shooting sprite set as it shape shifts in to the opposing piece
    // when fighting.
    .const BYTES_PER_CHAR_SPRITE = 54;
    piece_offset:
        // UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS
        .fillword 13, source+i*BYTES_PER_CHAR_SPRITE*15
        // DG
        .fillword 1, source+12*BYTES_PER_CHAR_SPRITE*15+1*BYTES_PER_CHAR_SPRITE*10
        // BS, GB, AE, FE, EE, WE
        .fillword 6, source+(13+i)*BYTES_PER_CHAR_SPRITE*15+1*BYTES_PER_CHAR_SPRITE*10

    // 8BDA
    elemental_color: // Color of each elemental (air, fire, earth, water)
        .byte LIGHT_GRAY, RED, BROWN, BLUE

    // 8D44
    frame_offset: // Memory offset of each sprite frame within a sprite set
        .word $0000, $0036, $006C, $00A2, $00D8, $010E, $00D8, $0144
        .word $017A, $01B0, $017A, $01E6, $021C, $0252, $0288, $02BE
        .word $02F4, $0008, $0000, $0010, $0018

    // 906F
    piece_color: // Color of character based on side (light, dark)
        .byte YELLOW, LIGHT_BLUE

    // 9274
    logo_string: // Logo string that is converted to a sprite using character set dot data as sprite source data
        .text "ARCHON"

    // 929B
    magic_sqauare_data: // Sprite data used to create the magic square icon
        .byte $00, $00, $00, $00, $00, $18, $24, $5A, $5A, $5A, $24, $18

    // 92E1
    magic_square_x_pos: .byte $4A, $1A, $4A, $4A, $7A // Sprite X position of each magic square

    // 92E6
    magic_square_y_pos: .byte $17, $57, $57, $97, $57 // Sprite Y position of each magic square

    // BAE-3D3F and AE23-BACA
    // Character icon sprites. Note that sprites are not 64 bytes in length like normal sprites. Archon sprites are
    // smaller so that they can fit on a board sqare and therefore do not need to take up 64 bytes. Instead, sprites
    // consume 54 bytes only. The positive of this is that we use less memory for each sprite. The negative is that
    // we can't just load the raw sprite binary file in to a sprite editor.
    // Anyway, there are LOTS of sprites. Generally 15 sprites for each piece. This includes fram animations in each
    // direction, shoot animations and projectiles. NOTE that spearate frames for left moving and right moving
    // animations. Instead, the routine used to load sprites in to graphical memory has a function that allows
    // sprites to be mirrored when copied.
    source: .import binary "/assets/sprites-game.bin"
}

.namespace piece {
    // 8AB3
    // Initial strength of each character piece. Uses character offset as index. Eg Knight has an offset of 7 and
    // therefore the initial strength of a knight is $05.
    init_strength:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 09, 10, 05, 15, 08, 15, 12, 05, 06, 10, 08, 14, 10, 17, 08, 05, 12, 10, 17, 14

    // 8AFF
    // Matrix used to determine offset of each piece type AND determine which peices occupy which sqaures on initial
    // setup.
    // This is a little bit odd - the numbers below are indexes used to retrieve an address from
    // `sprite.piece_offset` to determine the source sprite memory address. The `Character Piece Type` are actually
    // an offset in to this matrix. So Phoenix is ID# 10, which is the 11th (0 offset) byte below which is $06, telling
    // us to read the 6th word of the sprite character offset to determine the first frame of the Phoenix character
    // set.
    // NOTE also thought hat certain offsets are relicated. The matrix below also doubles as the intial piece setup
    // with 2 bytes represeting two columns of each row. The setup starts with all the light peices, then dark.
    init_matrix:
        .byte VALKYRIE_OFFSET, ARCHER_OFFSET, GOLEM_OFFSET, KNIGHT_OFFSET, UNICORN_OFFSET, KNIGHT_OFFSET
        .byte DJINNI_OFFSET, KNIGHT_OFFSET, WIZARD_OFFSET, KNIGHT_OFFSET, PHOENIX_OFFSET, KNIGHT_OFFSET
        .byte UNICORN_OFFSET, KNIGHT_OFFSET, GOLEM_OFFSET, KNIGHT_OFFSET, VALKYRIE_OFFSET, ARCHER_OFFSET
        .byte MANTICORE_OFFSET, BANSHEE_OFFSET, GOBLIN_OFFSET, TROLL_OFFSET, GOBLIN_OFFSET, BASILISK_OFFSET
        .byte GOBLIN_OFFSET, SHAPESHIFTER_OFFSET, GOBLIN_OFFSET, SORCERESS_OFFSET, GOBLIN_OFFSET, DRAGON_OFFSET
        .byte GOBLIN_OFFSET, BASILISK_OFFSET, GOBLIN_OFFSET, TROLL_OFFSET, MANTICORE_OFFSET, BANSHEE_OFFSET
        .byte AIR_ELEMENTAL_OFFSET, FIRE_ELEMENTAL_OFFSET, EARTH_ELEMENTAL_OFFSET, WATER_ELEMENTAL_OFFSET

    // 8B7C
    // The ID of the string used to represent each piece type using piece offset as index.
    // eg UNICORN has 00 offset and it's text representation is STRING_28.
    string_id:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB
        .byte 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43
}

.namespace sound {
    // 8B94
    phrase_ptr:
        .word phrase_walk_large   // 00
        .word phrase_fly_01       // 02
        .word phrase_fly_02       // 04
        .word phrase_walk_quad    // 06
        .word phrase_fly_03       // 08
        .word phrase_fly_large    // 10
        .word phrase_fire_01      // 12
        .word phrase_fire_02      // 14
        .word phrase_fire_03      // 16
        .word phrase_fire_04      // 18
        .word phrase_walk_slither // 20

    // 8BAA
    fire_phrase:
    // Sound phrase used for shot sound of each piece type. The data is an index to the character sound pointer array.
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 12, 12, 12, 12, 12, 12, 16, 14, 12, 12, 12, 12, 12, 12, 18, 14, 12, 12, 12, 12

    // 8BBE
    // Sound phrase used for each piece type. The data is an index to the character sound pointer array. Uses piece
    // offset as index.
    character_phrase:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 06, 08, 08, 00, 02, 02, 10, 08, 20, 08, 06, 00, 02, 04, 02, 08, 02, 02, 00, 04

    // A15E
    phrase_walk_large:
        .byte SOUND_CMD_NO_NOTE, $08, $34, SOUND_CMD_NO_NOTE, $20, $03, $81, SOUND_CMD_NO_NOTE, $08, $34
        .byte SOUND_CMD_NO_NOTE, $20, $01, $81
        .byte SOUND_CMD_NEXT_PHRASE
    phrase_fly_01:
        .byte SOUND_CMD_NO_NOTE, $04, SOUND_CMD_NO_NOTE, $40, $60, $08, $81, $04, SOUND_CMD_NO_NOTE, $40, $60
        .byte $0A, $81
        .byte SOUND_CMD_NEXT_PHRASE
    phrase_fly_02:
        .byte SOUND_CMD_NO_NOTE, $08, $70, SOUND_CMD_NO_NOTE, $E2, $04, $21, $08, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PHRASE
    phrase_walk_slither:
        .byte SOUND_CMD_NO_NOTE, $08, $70, SOUND_CMD_NO_NOTE, $C0, $07, $21, $08, $70, SOUND_CMD_NO_NOTE, $C0, $07
        .byte SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PHRASE
    phrase_walk_quad:
        .byte $04, $01, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $02, $81, SOUND_CMD_NO_NOTE, $04, $01
        .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $03, $81, SOUND_CMD_NO_NOTE, $04, $01, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NO_NOTE, $04, $81, SOUND_CMD_NO_NOTE, $04, $01, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PHRASE
    phrase_fly_03:
        .byte SOUND_CMD_NO_NOTE, $04, $12, SOUND_CMD_NO_NOTE, $20, $03, $81, $04, $12, SOUND_CMD_NO_NOTE, $20, $03
        .byte SOUND_CMD_NO_NOTE, $04, $12, SOUND_CMD_NO_NOTE, $20, $02, $81, $04, $12, SOUND_CMD_NO_NOTE, $20, $02
        .byte SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PHRASE
    phrase_fire_03:
        .byte SOUND_CMD_NO_NOTE, $32, $A9, SOUND_CMD_NO_NOTE, $EF, $31, $81, SOUND_CMD_END
        .byte SOUND_CMD_NO_NOTE, $12, $08, SOUND_CMD_NO_NOTE, $C4, $07, $41, SOUND_CMD_END
        .byte SOUND_CMD_NO_NOTE, $12, $08, SOUND_CMD_NO_NOTE, $D0, $3B, $43, SOUND_CMD_END
    phrase_fire_04:
        .byte SOUND_CMD_NO_NOTE, $28, $99, SOUND_CMD_NO_NOTE, $6A, $6A, $21, SOUND_CMD_END
    phrase_fly_large:
        .byte SOUND_CMD_NO_NOTE, $10, $84, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $06, $81
        .byte SOUND_CMD_NEXT_PHRASE
    phrase_fire_01:
        .byte SOUND_CMD_NO_NOTE, $80, $4B, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $21, $81, SOUND_CMD_END
    phrase_fire_02:
        .byte SOUND_CMD_NO_NOTE, $10, $86, SOUND_CMD_NO_NOTE, $F0, $F0, $81, SOUND_CMD_END
        .byte SOUND_CMD_NO_NOTE, $1E, $09, SOUND_CMD_NO_NOTE, $3E, $2A, $11, SOUND_CMD_END
        .byte SOUND_CMD_NO_NOTE, $1E, $09, SOUND_CMD_NO_NOTE, $1F, $16, $11, SOUND_CMD_END
        .byte SOUND_CMD_NO_NOTE, $80, $03, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $23, $11, SOUND_CMD_END
}

.namespace screen {
    // A21E
    message_ptr: // Pointer to start predefined text message. Messages are FF terminated.
        .word string_0,  string_1,  string_2,  string_3,  string_4,  string_5,  string_6,  string_7
        .word string_8,  string_9,  string_10, string_11, string_12, string_13, string_14, string_15
        .word string_16, string_17, string_18, string_19, string_20, string_21, string_22, string_23
        .word string_24, string_25, string_26, string_27, string_28, string_29, string_30, string_31
        .word string_32, string_33, string_34, string_35, string_36, string_37, string_38, string_39
        .word string_40, string_41, string_42, string_43, string_44, string_45, string_46, string_47
        .word string_48, string_49, string_50, string_51, string_52, string_53, string_54, string_55
        .word string_56, string_57, string_58, string_59, string_60, string_61, string_62, string_63
        .word string_64, string_65, string_66, string_67, string_68, string_69, string_70

    // A2AC
    string_1:
        .text "ALAS, MASTER, THIS ICON CANNOT MOVE"
        .byte STRING_CMD_END

    // A2D0
    string_2:
        .text "DO YOU CHALLENGE THIS FOE?"
        .byte STRING_CMD_END

    // A2EB
    string_3:
        .text "YOU HAVE MOVED YOUR LIMIT"
        .byte STRING_CMD_END

    // A305
    string_4:
        .text "THE SQUARE AHEAD IS OCCUPIED"
        .byte STRING_CMD_END

    // A322
    string_6:
        .text "THE LIGHT SIDE WINS"
        .byte STRING_CMD_END

    // A336
    string_7:
        .text "THE DARK SIDE WINS"
        .byte STRING_CMD_END

    // A349
    string_8:
        .text "IT IS A TIE"
        .byte STRING_CMD_END

    // A355
    string_9:
        .text "THE FLOW OF TIME IS REVERSED"
        .byte STRING_CMD_END

    // A372
    string_10:
        .text "WHICH ICON WILL YOU HEAL?"
        .byte STRING_CMD_END

    // A38C
    string_5:
        .text "IT IS DONE"
        .byte STRING_CMD_END

    // A397
    string_11:
        .text "WHICH ICON WILL YOU TELEPORT?"
        .byte STRING_CMD_END

    // A3B5
    string_12:
        .text "WHERE WILL YOU TELEPORT IT?"
        .byte STRING_CMD_END

    // A3D1
    string_13:
        .text @"CHOOSE AN ICON TO TRANSPOSE"
        .byte STRING_CMD_END

    // A3ED
    string_14:
        .text "EXCHANGE IT WITH WHICH ICON?"
        .byte STRING_CMD_END

    // A40A
    string_15:
        .text "WHAT ICON WILL YOU REVIVE?"
        .byte STRING_CMD_END

    // A425
    string_16:
        .text "PLACE IT WITHIN THE CHARMED SQUARE"
        .byte STRING_CMD_END

    // A448
    string_17:
        .text "WHICH FOE WILL YOU IMPRISON?"
        .byte STRING_CMD_END

    // A465
    string_18:
        .text "ALAS, MASTER, THERE IS NO OPENING IN THECHARMED SQUARE. CONJURE ANOTHER SPELL"
        .byte STRING_CMD_END

    // A4B3
    string_25:
        .text "SEND IT TO THE TARGET"
        .byte STRING_CMD_END

    // A4C9
    string_53:
        .text "THAT SPELL WOULD BE WASTED AT THIS TIME"
        .byte STRING_CMD_END

    // A4F0
    string_54:
        .text "SELECT A SPELL"
        .byte STRING_CMD_END

    // A500
    string_19:
        .text "HAPPILY, MASTER, ALL YOUR ICONS LIVE.   PLEASE CONJURE A DIFFERENT SPELL"
        .byte STRING_CMD_END

    // A549
    string_20:
        .text "ALAS, THIS ICON IS IMPRISONED"
        .byte STRING_CMD_END

    // A567
    string_21:
        .text "AN AIR"
        .byte STRING_CMD_END

    // A56E
    string_22:
        .text "A FIRE"
        .byte STRING_CMD_END

    // A575
    string_24:
        .text "A WATER"
        .byte STRING_CMD_END

    // A57D
    string_23:
        .text "AN EARTH"
        .byte STRING_CMD_END

    // A586
    string_26:
        .text "THE WIZARD"
        .byte STRING_CMD_END

    // A591
    string_27:
        .text "THE SORCERESS"
        .byte STRING_CMD_END

    // A59F
    string_0:
        .text "OH, WOE! YOUR SPELLS ARE GONE!"
        .byte STRING_CMD_END

    //A5BE
    string_28:
        .text "UNICORN (GROUND 4)"
        .byte STRING_CMD_END

    // A5D1
    string_29:
        .text "WIZARD (TELEPORT 3)"
        .byte STRING_CMD_END

    // A5E5
    string_30:
        .text "ARCHER (GROUND 3)"
        .byte STRING_CMD_END

    // A5F7
    string_31:
        .text "GOLEM (GROUND 3)"
        .byte STRING_CMD_END

    // A608
    string_32:
        .text "VALKYRIE (FLY 3)"
        .byte STRING_CMD_END

    // A619
    string_33:
        .text "DJINNI (FLY 4)"
        .byte STRING_CMD_END

    // A628
    string_34:
        .text "PHOENIX (FLY 5)"
        .byte STRING_CMD_END

    // A638
    string_35:
        .text "KNIGHT (GROUND 3)"
        .byte STRING_CMD_END

    // A64A
    string_36:
        .text "BASILISK (GROUND 3)"
        .byte STRING_CMD_END

    // A65E
    string_37:
        .text "SORCERESS (TELEPORT 3)"
        .byte STRING_CMD_END

    // A675
    string_38:
        .text "MANTICORE (GROUND 3)"
        .byte STRING_CMD_END

    // A68A
    string_39:
        .text "TROLL (GROUND 3)"
        .byte STRING_CMD_END

    // A69B
    string_40:
        .text "SHAPESHIFTER (FLY 5)"
        .byte STRING_CMD_END

    // A6B0
    string_41:
        .text "DRAGON (FLY 4)"
        .byte STRING_CMD_END

    // A6BF
    string_42:
        .text "BANSHEE (FLY 3)"
        .byte STRING_CMD_END

    // A6CF
    string_43:
        .text "GOBLIN (GROUND 3)"
        .byte STRING_CMD_END

    // A6E1
    string_44:
        .text "TELEPORT"
        .byte STRING_CMD_END

    // A6EA
    string_45:
        .text "HEAL"
        .byte STRING_CMD_END

    // A6EF
    string_46:
        .text "SHIFT TIME"
        .byte STRING_CMD_END

    // A6FA
    string_47:
        .text "EXCHANGE"
        .byte STRING_CMD_END

    // A703
    string_48:
        .text "SUMMON ELEMENTAL"
        .byte STRING_CMD_END

    // A714
    string_49:
        .text "REVIVE"
        .byte STRING_CMD_END

    // A71B
    string_50:
        .text "IMPRISON"
        .byte STRING_CMD_END

    // A724
    string_51:
        .text "CEASE CONJURING"
        .byte STRING_CMD_END

    // A734
    string_52:
        .text "POWER POINTS ARE PROOF AGAINST MAGIC"
        .byte STRING_CMD_END

    // A759
    string_55:
        .text "COMPUTER "
        .byte STRING_CMD_END

    // A763
    string_56:
        .text "LIGHT "
        .byte STRING_CMD_END

    // A76A
    string_57:
        .text "TWO-PLAYER "
        .byte STRING_CMD_END

    // A776
    string_58:
        .text "FIRST"
        .byte STRING_CMD_END

    // A77C
    string_59:
        .text "DARK "
        .byte STRING_CMD_END

    // A782
    string_60:
        .text "WHEN READY"
        .byte STRING_CMD_END

    // A78D
    string_61:
        .text " PRESS "
        .byte STRING_CMD_END

    // A795
    string_62:
        .text "SPELL IS CANCELED. CHOOSE ANOTHER"
        .byte STRING_CMD_END

    // A7B7
    string_63:
        .text "THE GAME IS ENDED..."
        .byte STRING_CMD_END

    // A7CC
    string_64:
        .text "IT IS A STALEMATE"
        .byte STRING_CMD_END

    // A7DE
    string_65:
        .text " ELEMENTAL APPEARS!"
        .byte STRING_CMD_END

    // A7F2
    string_66:
        .text " CONJURES A SPELL!"
        .byte STRING_CMD_END

    //A805
    string_67:
        .text @"PRESS\$00RUN\$00KEY\$00TO\$00CONTINUE"
        .byte STRING_CMD_END

    // A81F
    string_68:
        .text "F7"
        .byte STRING_CMD_END

    // A822
    string_69:
        .text "F5: "
        .byte STRING_CMD_END

    // A827
    string_70:
        .text "F3: "
        .byte STRING_CMD_END
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment DynamicData

// BCCB
countdown_timer: .byte // Countdown timer (~4s tick) used to automate actions after timer expires (eg start game)

// BD14
// Set to 0 to render all occupied squares, $80 to disable rendering characters and $01-$79 to render a specified
// cell only.
flag__render_square_control: .byte $00

// BD4E
render_sqaure_piece_offset: .byte $00 // Set flag to #$80+ to inhibit piece draw or piece offset to draw the piece

// BF44
magic_square_counter: .byte $00 // Current magic square (1-5) being rendered

.namespace piece {
    // BF29
    offset: .byte $00, $00, $00, $00 // Character piece offset used to determine which sprite to copy

    // BF2D
    type: .byte $00, $00, $00, $00 // Type of board piece (See `Character piece types` constants)
}

.namespace sprite {
    // BCD4
    copy_source_lo_ptr: .byte $00, $00, $00, $00 // Low byte pointer to sprite frame source data

    // BCD8
    copy_source_hi_ptr: .byte $00, $00, $00, $00 // High byte pointer to sprite frame source data

    // BCDF
    copy_length: .byte $00 // Number of bytes to copy for the given sprite

    // BF49
    flag__copy_animation_group: .byte $00 // Set #$80 to copy individual character frame in to graphical memory
}

.namespace sound {
    // BF12
    phrase_lo_ptr: .byte $00, $00 // Lo byte pointer to sound phrase for current piece

    // BF14
    phrase_hi_ptr: .byte $00, $00 // Hi byte pointer to sound phrase for current piece
}
