.filenamespace board
//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used for rendering the game board.
//---------------------------------------------------------------------------------------------------------------------
.segment Common

// 62EB
// Description:
// - Gets sound pattern for the current icon.
// Prerequisites:
// - X:
//   $00: Retrieve sound for one player icon only (moving on board)
//   $01: Retrieve sound for two player icons (when in battle)
// - Y: Current player offset (0 for light, 1 for dark, 0 when X is $01)
// Sets:
// - `sound.pattern_lo_ptr`: Lo byte pointer to sound pattern
// - `sound.pattern_hi_ptr`: Hi byte pointer to sound pattern
// Preserves:
// - X
get_sound_for_icon:
    ldy common.icon.offset,x
    lda sound.icon_pattern,y
    tay
    lda prt__sound_icon_effect_list,y
    sta sound.pattern_lo_ptr,x
    lda prt__sound_icon_effect_list+1,y
    sta sound.pattern_hi_ptr,x
    rts

// 62FF
// Description:
// - Detects if the selected square is a magic sqaure.
// Prerequisites:
// - `data__curr_row`: row of the square to test.
// - `data__curr_column`: column of the square to test.
// Sets:
// - `flag__icon_destination_valid`: is $80 if selected square is a magic square.
// Preserves:
// - X, Y
test_magic_square_selected:
    tya
    pha
    lda #(FLAG_ENABLE/2) // Default to no action - used $40 here so can do quick asl to turn in to $80 (flag_enable)
    sta game.flag__icon_destination_valid
    ldy #$04 // 5 magic squares (0 based)
!loop:
    lda data.magic_square_col,y
    cmp data__curr_row
    bne !next+
    lda data.magic_square_row,y
    cmp data__curr_column
    beq magic_square_selected
!next:
    dey
    bpl !loop-
    bmi no_magic_square_selected
magic_square_selected:
    asl game.flag__icon_destination_valid
no_magic_square_selected:
    pla
    tay
    rts

// 6422
// Description:
// - Converts a board row and column coordinate to a corresponding sprite screen position so that the sprite is
//   positioned exactly over the board square.
// Prerequisites:
// - A: Board column
// - Y: Board row
// - X: Sprite number $00 to $07 ($04 is special - see below)
// Sets:
// - `common.sprite.curr_x_pos,x` and `common.sprite.curr_y_pos,x` with the calculated position.
// - A: Sprite X position
// - Y: Sprite Y position
// Notes:
// - If X is set to $04, then the position is not stored in `common.sprite.curr_x_pos,x` and
//   `common.sprite.curr_y_pos,x`.
convert_coord_sprite_pos:
    // Calculate X position.
    pha
    asl
    asl
    asl
    sta data__temp_sprite_x_calc_store
    pla
    asl
    asl
    clc
    adc data__temp_sprite_x_calc_store
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

// 6509
// Description:
// - Writes a text message to the board text area.
// Prerequisites:
// - A: text message offset (see `ptr__txt__game_list` for message order).
// - X: column offset.
// Sets:
// - Screen graphical character memory.
write_text:
    asl
    tay
    lda ptr__txt__game_list,y
    sta FREEZP
    lda ptr__txt__game_list+1,y
    sta FREEZP+1
    ldy #$00
!loop:
    lda (FREEZP),y
    bpl !next+
    rts
!next:
    // Convert petscii to correct character map dot data offset.
    and #$3F
    clc
    adc #$C0
    sta (SCNMEM+23*CHARS_PER_SCREEN_ROW),x
    inx
    iny
    jmp !loop-

// 6529
// Displays the game options at the bottom of the board.
display_options:
    ldx #$01
    lda #STRING_F3
    jsr write_text
    lda common.options.flag__ai_player_ctl
    beq display_two_player
    lda #STRING_COMPUTER
    jsr write_text
    lda #STRING_LIGHT
    ldy common.options.flag__ai_player_ctl
    bpl !next+
    lda #STRING_DARK
    bpl !next+
display_two_player:
    lda #STRING_TWO_PLAYER
!next:
    jsr write_text
    ldx #$1C
    lda #STRING_PRESS
    jsr write_text
    lda #STRING_F7
    jsr write_text
    ldx #$29
    lda #STRING_F5
    jsr write_text
    lda #STRING_LIGHT
    ldy game.state.data__curr_player_color
    bpl !next+
    lda #STRING_DARK
!next:
    jsr write_text
    lda #STRING_FIRST
    jsr write_text
    ldx #$45
    lda #STRING_READY
    jsr write_text
    jmp common.check_option_keypress

// 6C7C
// Description:
// - Fills an array of rows and columns with the coordinates of the squares surrounding the current square.
// Prerequisites:
// - `data__curr_icon_row`: row of source square
// - `data__curr_icon_col`: column of source square
// Sets:
// - `surrounding_square_row`: Contains an array of rows for all 9 squares (including source)
// - `surrounding_square_column`: Contains an array of columns for all 9 squares (including source)
// Notes:
// - The array also includes the source square.
// - Rows and columns may be out of bounds if the source square is on a board edge.
surrounding_squares_coords:
    ldx #$08 // 9 squares (0 offset)
    ldy data__curr_icon_row
    iny
    sty data__curr_row
!row_loop:
    ldy data__curr_icon_col
    iny
    sty data__curr_column
    ldy #$03
!column_loop:
    lda data__curr_row
    sta surrounding_square_row,x
    lda data__curr_column
    sta surrounding_square_column,x
    dex
    bmi !return+
    dec data__curr_column
    dey
    bne !column_loop-
    dec data__curr_row
    jmp !row_loop-
!return:
    rts

// 8965
// Description:
// - Adds an icon to the board matrix.
// Prerequisites:
// - `data__curr_board_row`: Row offset of board square.
// - `data__curr_board_col`: Column offset of board square.
// - `icon.type`: Type of icon to add to the square.
// Sets:
// - `curr_square_occupancy`: Sets appropriate byte within the occupancy array.
add_icon_to_matrix:
    ldy data__curr_board_row
    lda data.row_occupancy_lo_ptr,y
    sta OLDLIN
    lda data.row_occupancy_hi_ptr,y
    sta OLDLIN+1
    //
    ldy data__curr_board_col
    lda common.icon.type
    sta (OLDLIN),y
    rts

// 8D6E
// Description:
// - Places a sprite at a given location and enables the sprite.
// Prerequisites:
// - X: sprite number to be enabled.
// - `common.sprite.curr_x_pos`: Screen X location of the sprite.
// - `common.sprite.curr_y_pos`: Screen Y location of the sprite.
// - `common.sprite.curr_animation_frame`: Current frame number (0 to 4) of animated sprite
// Sets:
// - Enables the sprite and sets X and Y coordinates.
// Notes:
// - So that the X and Y position can fit in a single register, the Y position is offset by 50 (so 0 represents 50,
//   1 = 51 etc) and the X position is halved and then offset by 24 (so 0 is 24, 1 is 26, 2 is 28 etc).
render_sprite:
    txa
    asl
    tay
    lda common.sprite.curr_animation_frame,x
    and #$03 // Ensure sprite number is between 0 and 3 to allow multiple animation frames for each sprite id
    clc
    adc common.sprite.init_animation_frame,x
    adc common.sprite.offset_00,x
    sta SPTMEM,x

// 8D80
// Description:
// - Places a sprite at a given location and enables the sprite.
// Prerequisites:
// - X: sprite number to be enabled.
// - Y: 2 * the sprite number to be enabled.
// - `common.sprite.curr_x_pos`: Screen X location of the sprite.
// - `common.sprite.curr_y_pos`: Screen Y location of the sprite.
// Sets:
// - Enables the sprite and sets X and Y coordinates.
// Notes:
// - So that the X and Y position can fit in a single register, the Y position is offset by 50 (so 0 represents 50,
//   1 = 51 etc) and the X position is halved and then offset by 24 (so 0 is 24, 1 is 26, 2 is 28 etc).
render_sprite_preconf:
    lda common.sprite.curr_y_pos,x
    clc
    adc #$32
    sta SP0Y,y
    //
    lda common.sprite.curr_x_pos,x
    clc
    adc common.sprite.curr_x_pos,x
    sta data__temp_sprite_y_store
    lda #$00
    adc #$00
    sta data__temp_sprite_x_store
    lda data__temp_sprite_y_store
    adc #$18
    sta SP0X,y
    lda data__temp_sprite_x_store
    adc #$00
    beq !next+
    lda MSIGX
    ora common.math.pow2,x
    sta MSIGX
    rts
!next:
    lda common.math.pow2,x
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
    lda #<(CHRMEM2+player_dot_data_offset)
    sta FREEZP+2
    lda #>(CHRMEM2+player_dot_data_offset)
    sta FREEZP+3
    ldy #$07
    lda game.state.flag__is_light_turn
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 9076
// Draws the board squares and renders the occupied characters on the board. The squares are colored according to the
// color matrix and the game current color phase.
// Each square is 3 characters wide and 2 characters high.
draw_board:
    ldx #$02
!loop:
    lda data.square_colors__icon,x
    sta BGCOL0,x
    dex
    bpl !loop-
    lda data.square_colors__icon
    sta EXTCOL
    //
    lda #(BOARD_NUM_ROWS-1) // Number of rows (0 based, so 9)
    sta data__curr_row
    // Draw each board row.
draw_row:
    lda #(BOARD_NUM_COLS-1) // Number of columns (0 based, so 9)
    sta data__curr_column
    ldy data__curr_row
    //
    lda data.row_screen_offset_lo_ptr,y
    sta FREEZP+2 // Screen offset
    sta VARPNT // Color memory offset
    lda data.row_screen_offset_hi_ptr,y
    sta FREEZP+3
    clc
    adc common.screen.color_mem_offset
    sta VARPNT+1
    //
    lda data.row_occupancy_lo_ptr,y
    sta FREEZP // Square occupancy
    lda data.row_occupancy_hi_ptr,y
    sta FREEZP+1
    //
    lda data.row_color_offset_lo_ptr,y
    sta CURLIN // Square color
    lda data.row_color_offset_hi_ptr,y
    sta CURLIN+1
    //
draw_square:
    ldy data__curr_column
    bit flag__render_square_ctl
    bvs render_square // Disable icon render
    bpl render_icon
    // Only render icon for a given row and coloumn.
    lda #FLAG_ENABLE // disable square render (set to icon offset to render an icon)
    sta render_square_icon_offset
    lda data__curr_board_col
    cmp data__curr_column
    bne draw_empty_square
    lda data__curr_board_row
    cmp data__curr_row
    bne draw_empty_square
render_icon:
    lda (FREEZP),y
    bmi !next+ // if $80 (blank)
    tax
    lda icon.init_matrix,x  // Get icon dot data offset
!next:
    sta render_square_icon_offset
    bmi draw_empty_square
    // Here we calculate the icon starting icon. We do this as follows:
    // - Set $60 if the icon has a light or variable color background
    // - Multiply the icon offset by 6 to allow for 6 characters per icon type
    // - Add both together to get the actual icon starting offset
    ldx #$06 // Each icon compriss a block 6 characters (3 x 2)
    lda (CURLIN),y  // Get square background color (will be 0 for dark, 60 for light and variable)
    and #$7F
!loop:
    clc
    adc render_square_icon_offset
    dex
    bne !loop-
    sta data__board_icon_char_offset
    jmp render_square
draw_empty_square:
    lda (CURLIN),y
    and #$7F
    sta data__board_icon_char_offset
render_square:
    // Draw the square. Squares are 2x2 characters. The start is calculated as follows:
    // - offset = row offset + (current column * 2) + current column
    // We call `render_square_row` which draws 2 characters. We then increase the offset by 40 (moves to next line)
    // and call `render_square_row` again to draw the next two characters.
    lda (CURLIN),y
    bmi !next+
    lda data.square_colors__square+1
    bpl !skip+
!next:
    lda game.curr_color_phase
!skip:
    ora #$08 // Derive square color
    sta data__curr_square_color_code
    lda data__curr_column
    asl
    clc
    adc data__curr_column
    tay
    jsr draw_square_part
    lda data__curr_column
    asl
    clc
    adc data__curr_column
    adc #CHARS_PER_SCREEN_ROW
    tay
    jsr draw_square_part
    //
    dec data__curr_column
    bpl draw_square
    dec data__curr_row
    bmi !return+
    jmp draw_row
!return:
    rts
draw_square_part: // Draws 3 characters of the current row.
    lda #$03
    sta data__curr_count
!loop:
    lda data__board_icon_char_offset
    sta (FREEZP+2),y
    lda (VARPNT),y
    and #$F0
    ora data__curr_square_color_code
    sta (VARPNT),y
    iny
    lda render_square_icon_offset
    bmi !next+
    inc data__board_icon_char_offset
!next:
    dec data__curr_count
    bne !loop-
    rts

// 916E
// Draws a border around the board.
draw_border:
    .const BORDER_CHARACTER = $C0
    // Draw top border.
    lda data.row_screen_offset_lo_ptr
    sec
    sbc #(CHARS_PER_SCREEN_ROW+1) // 1 row and 1 character before start of board
    sta FREEZP+2 // Screen offset
    sta FORPNT // Color memory offset
    lda data.row_screen_offset_hi_ptr
    sbc #$00
    sta FREEZP+3
    clc
    adc common.screen.color_mem_offset
    sta FORPNT+1
    ldy #(BOARD_NUM_COLS*3+1) // 9 squares (3 characters per square) + 1 character each side of board (0 based)
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
    ldx #(BOARD_NUM_ROWS*2) // 9 squares (2 characters per square)
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
    ldy #(BOARD_NUM_COLS*3+1) // 9 squares (3 characters per square) + 1 character each side of board (0 based)
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
    lda common.sprite.mem_ptr_56
    sta FREEZP+2 // Sprite location
    sta data__temp_storage
    sta data__temp_storage+1
    lda common.sprite.mem_ptr_56+1
    sta FREEZP+3
    lda #$03 // Number of letters per sprite
    sta data__temp_storage+2
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
    lda #>(CHRMEM2+UPPERCASE_OFFSET)
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
    inc data__temp_storage
    lda data__temp_storage
    sta FREEZP+2
    dec data__temp_storage+2
    bne !next+
    // Sprite full - Move to next sprite.
    lda #$03
    sta data__temp_storage+2
    lda data__temp_storage+1
    clc
    adc #BYTES_PER_SPRITE
    sta FREEZP+2
    sta data__temp_storage
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
    lda #((VICGOFF/BYTES_PER_SPRITE)+56) // Should use common.sprite.offset_56 but source doesn't :(
    sta SPTMEM+2
    lda #((VICGOFF/BYTES_PER_SPRITE)+57)
    sta SPTMEM+3
    rts

// 927A
// Create the sprite used to indicate a magic board square.
// The sprite is stored in sprite offset 48.
create_magic_square_sprite:
    lda common.sprite.mem_ptr_48
    sta FREEZP+2
    lda common.sprite.mem_ptr_48+1
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
    cpy #$05 // Total number of magic squares
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
    lda common.sprite.offset_48
    sta SPTMEM+SPRITE_NUMBER
    ldy #(SPRITE_NUMBER*2)
    jmp render_sprite_preconf


// 92EB
create_selection_square:
    lda common.sprite.mem_ptr_24
    sta FREEZP+2 // Sprite location
    lda common.sprite.mem_ptr_24+1
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
// Description:
// - Clear text area underneath the board and reset the color to white.
// Sets:
// - Clears graphical character memory for rows 23 and 24 (0 offset).
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
// Description:
// - Clear the last text row under the board. Leave's the first text row untouched.
// Sets:
// - Clears graphical character memory for row 24 (0 offset).
// Notes:
// - Does not clear color memory.
clear_last_text_row:
    ldy #(CHARS_PER_SCREEN_ROW-1)
    lda #$00
!loop:
    sta SCNMEM+24*CHARS_PER_SCREEN_ROW,y
    dey
    bpl !loop-
    rts

// A0B1
// Description:
// - Plays an icon movement or attack sound.
// Prerequisites:
// - OLDTXT/OLDTXT+1: Pointer to sound pattern.
// - `common.sound.flag__enable_voice`: $00 to disable sound for light player, $80 to enable sound
// - `common.sound.flag__enable_voice+1`: $00 to disable sound for dark player, $80 to enable sound
// Notes:
// - See `get_note_data` below for special commands within sound pattern.
play_icon_sound:
    ldx #$01
    // Icon sounds can be played on voices 1 and 2 separately. This allows two icon movement sounds to be played at
    // the same time.
    // If 00, then means don't play sound for that icon.
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
    sta common.sound.voice_note_fn_ptr
    lda common.sound.note_data_fn_ptr+1,y
    sta common.sound.voice_note_fn_ptr+1
    lda common.sound.voice_io_addr,y
    sta FREEZP+2 // SID voice address
    lda common.sound.voice_io_addr+1,y
    sta FREEZP+3
get_next_note:
    jsr common.get_note
    cmp #SOUND_CMD_NEXT_PATTERN // Repeat pattern
    beq repeat_pattern
    cmp #SOUND_CMD_END // Finished - turn off sound
    beq stop_sound
    cmp #SOUND_CMD_NO_NOTE // Stop note
    bne get_note_data
    ldy #$04
    sta (FREEZP+2),y
    jmp get_next_note
get_note_data:
    // If the pattern data is not a command (ie FE, FF or 00), then the data represents a note. A note comprises several
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
repeat_pattern:
    txa
    asl
    tay
    lda sound.pattern_lo_ptr,x
    sta OLDTXT,y
    lda sound.pattern_hi_ptr,x
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
    lda common.flag__enable_next_state
    bmi !return+
    jmp (ptr__play_music_fn) // End of game.
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
    .enum { DARK = BOARD_DARK_SQUARE, LITE = BOARD_LIGHT_SQUARE, VARY = BOARD_VARY_SQUARE }
    square_color: // Board square colors
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
    magic_square_col: .byte $00, $04, $04, $04, $08 // Column of each magic square (used with magic_square_row)

    // 6328
    magic_square_row: .byte $04, $00, $04, $08, $04 // Row of each magic square (used with magic_square_col)

    // 8BD2
    color_phase: // Colors used for each board game phase
        .byte BLACK, BLUE, RED, PURPLE, GREEN, YELLOW, CYAN, WHITE

    // 9071
    square_colors__square: // Board square colors
        .byte BLACK, WHITE

    // 9073
    square_colors__icon: // Board background colors used when rendering the player board
        .byte BLACK, YELLOW, LIGHT_BLUE

    // BEAE
    row_screen_offset_lo_ptr: // Low byte screen memory offset of start of each board row
        .fill BOARD_NUM_COLS, <(ROW_START_OFFSET+i*ROWS_PER_SQUARE*CHARS_PER_SCREEN_ROW)

    // BEB7
    row_screen_offset_hi_ptr: // High byte screen memory offset of start of each board row
        .fill BOARD_NUM_COLS, >(SCNMEM+ROW_START_OFFSET+i*ROWS_PER_SQUARE*CHARS_PER_SCREEN_ROW)

    // BED2
    row_color_offset_lo_ptr: // Low byte memory offset of square color data for each board row
        .fill BOARD_NUM_COLS, <(square_color+i*BOARD_NUM_COLS)

    // BEDB
    row_color_offset_hi_ptr: // High byte memory offset of square color data for each board row
        .fill BOARD_NUM_COLS, >(square_color+i*BOARD_NUM_COLS)

    // BEC0
    // Low byte memory offset of square occupancy data for each board row
    row_occupancy_lo_ptr:
        .fill BOARD_NUM_COLS, <(curr_square_occupancy+i*BOARD_NUM_COLS)

    // BEC9
    // High byte memory offset of square occupancy data for each board row
    row_occupancy_hi_ptr:
        .fill BOARD_NUM_COLS, >(curr_square_occupancy+i*BOARD_NUM_COLS)        
}

.namespace sprite {
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
}

.namespace sound {
    // 8BBE
    // Sound pattern used for each icon type. The data is an index to the icon pattern pointer array defined above.
    // Uses icon offset as index.
    icon_pattern:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 06, 08, 08, 00, 02, 02, 10, 08, 20, 08, 06, 00, 02, 04, 02, 08, 02, 02, 00, 04
}

.namespace icon {
    // 8AC7
    // Number of moves of each icon type. Uses icon offset as index. Add +$40 if icon can cast spells. Add +$80 if
    // icon can fly.
    number_moves:
        //    UC, WZ,                            AR, GM, VK,              DJ,              PH,              KN
        .byte 04, 03+ICON_CAN_FLY+ICON_CAN_CAST, 03, 03, 03+ICON_CAN_FLY, 04+ICON_CAN_FLY, 05+ICON_CAN_FLY, 03
        //    BK, SR,                            MC, TL, SS,              DG,              BS,              GB
        .byte 03, 03+ICON_CAN_FLY+ICON_CAN_CAST, 03, 03, 05+ICON_CAN_FLY, 04+ICON_CAN_FLY, 03+ICON_CAN_FLY, 03

    // 8AFF
    // Matrix used to determine offset of each icon type AND determine which pieces occupy which squares on initial
    // setup.
    // This is a little bit odd - the numbers below are indexes used to retrieve an address from
    // `sprite.icon_offset` to determine the source sprite memory address. The `Icon Type` are actually an offset
    // in to this matrix. So Phoenix is ID# 10, which is the 11th (0 offset) byte below which is $06, telling us to
    // read the 6th word of the sprite icon offset to determine the first frame of the Phoenix icon set.
    // NOTE also thought hat certain offsets are relicated. The matrix below also doubles as the intial icon setup
    // with 2 bytes represeting two columns of each row. The setup starts with all the light pieces, then dark.
    init_matrix:
        .byte VALKYRIE_OFFSET, ARCHER_OFFSET, GOLEM_OFFSET, KNIGHT_OFFSET, UNICORN_OFFSET, KNIGHT_OFFSET
        .byte DJINNI_OFFSET, KNIGHT_OFFSET, WIZARD_OFFSET, KNIGHT_OFFSET, PHOENIX_OFFSET, KNIGHT_OFFSET
        .byte UNICORN_OFFSET, KNIGHT_OFFSET, GOLEM_OFFSET, KNIGHT_OFFSET, VALKYRIE_OFFSET, ARCHER_OFFSET
        .byte MANTICORE_OFFSET, BANSHEE_OFFSET, GOBLIN_OFFSET, TROLL_OFFSET, GOBLIN_OFFSET, BASILISK_OFFSET
        .byte GOBLIN_OFFSET, SHAPESHIFTER_OFFSET, GOBLIN_OFFSET, SORCERESS_OFFSET, GOBLIN_OFFSET, DRAGON_OFFSET
        .byte GOBLIN_OFFSET, BASILISK_OFFSET, GOBLIN_OFFSET, TROLL_OFFSET, MANTICORE_OFFSET, BANSHEE_OFFSET
        .byte AIR_ELEMENTAL_OFFSET, FIRE_ELEMENTAL_OFFSET, EARTH_ELEMENTAL_OFFSET, WATER_ELEMENTAL_OFFSET

    // 8B7C
    // The ID of the string used to represent each icon type using icon offset as index.
    // eg UNICORN has 00 offset and it's text representation is STRING_28.
    string_id:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB
        .byte 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43
}

// 8B94
// Points to a list of sounds that can be made for each icon type. The same sounds may be reused by different icon
// types.
prt__sound_icon_effect_list:
    .word resources.snd__effect_walk_large   // 00
    .word resources.snd__effect_fly_01       // 02
    .word resources.snd__effect_fly_02       // 04
    .word resources.snd__effect_walk_quad    // 06
    .word resources.snd__effect_fly_03       // 08
    .word resources.snd__effect_fly_large    // 10
    .word resources.snd__effect_attack_01    // 12
    .word resources.snd__effect_attack_02    // 14
    .word resources.snd__effect_attack_03    // 16
    .word resources.snd__effect_attack_04    // 18
    .word resources.snd__effect_walk_slither // 20

// A21E
// Pointer to start predefined text message. Messages are FF terminated.
ptr__txt__game_list:
    .word resources.txt__game_0,  resources.txt__game_1,  resources.txt__game_2,  resources.txt__game_3
    .word resources.txt__game_4,  resources.txt__game_5,  resources.txt__game_6,  resources.txt__game_7
    .word resources.txt__game_8,  resources.txt__game_9,  resources.txt__game_10, resources.txt__game_11
    .word resources.txt__game_12, resources.txt__game_13, resources.txt__game_14, resources.txt__game_15
    .word resources.txt__game_16, resources.txt__game_17, resources.txt__game_18, resources.txt__game_19
    .word resources.txt__game_20, resources.txt__game_21, resources.txt__game_22, resources.txt__game_23
    .word resources.txt__game_24, resources.txt__game_25, resources.txt__game_26, resources.txt__game_27
    .word resources.txt__game_28, resources.txt__game_29, resources.txt__game_30, resources.txt__game_31
    .word resources.txt__game_32, resources.txt__game_33, resources.txt__game_34, resources.txt__game_35
    .word resources.txt__game_36, resources.txt__game_37, resources.txt__game_38, resources.txt__game_39
    .word resources.txt__game_40, resources.txt__game_41, resources.txt__game_42, resources.txt__game_43
    .word resources.txt__game_44, resources.txt__game_45, resources.txt__game_46, resources.txt__game_47
    .word resources.txt__game_48, resources.txt__game_49, resources.txt__game_50, resources.txt__game_51
    .word resources.txt__game_52, resources.txt__game_53, resources.txt__game_54, resources.txt__game_55
    .word resources.txt__game_56, resources.txt__game_57, resources.txt__game_58, resources.txt__game_59
    .word resources.txt__game_60, resources.txt__game_61, resources.txt__game_62, resources.txt__game_63
    .word resources.txt__game_64, resources.txt__game_65, resources.txt__game_66, resources.txt__game_67
    .word resources.txt__game_68, resources.txt__game_69, resources.txt__game_70


//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCCB
countdown_timer: .byte $00 // Countdown timer (~4s tick) used to automate actions after timer expires (eg start game)

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

.namespace sound {
    // BF12
    pattern_lo_ptr: .byte $00, $00 // Lo byte pointer to sound pattern for current icon

    // BF14
    pattern_hi_ptr: .byte $00, $00 // Hi byte pointer to sound pattern for current icon
}


// BD14
// Set to 0 to render all occupied squares, $80 to disable rendering icons and $01-$79 to render a specified
// square only.
flag__render_square_ctl: .byte $00

// BD4E
render_square_icon_offset: .byte $00 // Set flag to #$80+ to inhibit icon draw or icon offset to draw the icon

// BD7C
// Board square occupant data (#$80 for no occupant).
curr_square_occupancy: .fill BOARD_SIZE, $00

// BE8F
// Array of squares adjacent to the source square.
surrounding_square_row:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00
surrounding_square_column:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00

// BF44
magic_square_counter: .byte $00 // Current magic square (1-5) being rendered

// BF24
// Color code used to render.
data__curr_square_color_code: .byte $00

// BF1A
// Index to character dot data for current board icon part (icons are 6 caharcters).
data__board_icon_char_offset: .byte $00

// BF1A
// Temporary storage of interim calculation used to convert a board position to a sprite location.
data__temp_sprite_x_calc_store: .byte $00

// BD7B
// Temporary counter storage.
data__curr_count: .byte $00

// BF20
// Temporary storage of calculated initial Y position of a newly places sprite.
data__temp_sprite_y_store: .byte $00

// BF21
// Temporary storage of calculated initial X position of a newly places sprite.
data__temp_sprite_x_store: .byte $00

// BF1A
// Temporary data storage area used for creating the icon logo sprite.
data__temp_storage: .byte $00, $00, $00

// BF25
data__curr_icon_row: // Intitial board row of selected icon
    .byte $00

// BF26
data__curr_board_row: // Board row offset for rendered icon
    .byte $00

// BF27
data__curr_icon_col: // Intitial board column of selected icon
    .byte $00

// BF28
data__curr_board_col: // Board column for rendered icon
    .byte $00

// BF30
data__curr_row: // Current board row
    .byte $00

// BF31
data__curr_column: // Current board column
    .byte $00

// BD30
// Points to the music playing function for playing the outro music during an interrupt.
ptr__play_music_fn: .word $0000
