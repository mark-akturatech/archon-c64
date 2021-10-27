.filenamespace board

//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used for rendering the game board.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

.segment Common

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
    lda flag__current_player
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
    lda board_data.square_color_data__background,x
    sta BGCOL0,x
    dex
    bpl !loop-
    lda board_data.square_color_data__background
    sta EXTCOL
    //
    lda #$08 // Number of rows (0 based, so 9)
    sta main.temp.data__curr_row
    // Draw each board row.
draw_row:
    lda #$08 // Number of columns (0 based, so 9)
    sta main.temp.data__curr_column
    ldy main.temp.data__curr_row
    //
    lda board_data.row_screen_offset_lo_ptr,y
    sta FREEZP+2 // Screen offset
    sta VARPNT // Color memory offset
    lda board_data.row_screen_offset_hi_ptr,y
    sta FREEZP+3
    clc
    adc main.screen.color_mem_offset
    sta VARPNT+1
    //
    lda board_data.row_occupancy_lo_ptr,y
    sta FREEZP // Square occupancy
    lda board_data.row_occupancy_hi_ptr,y
    sta FREEZP+1
    //
    lda board_data.row_color_lo_ptr,y
    sta CURLIN // Square color
    lda board_data.row_color_hi_ptr,y
    sta CURLIN+1
    //
draw_square:
    ldy main.temp.data__curr_column
    // 90BD  2C 14 BD   bit  WBD14
    // 90C0  70 3E      bvs  W9100
    // 90C2  10 15      bpl  W90D9
    // 90C4  A9 80      lda  #$80
    // 90C6  8D 4E BD   sta  WBD4E
    // 90C9  AD 28 BF   lda  temp_data__current_board_col
    // 90CC  CD 31 BF   cmp  temp_data__curr_column
    // 90CF  D0 28      bne  W90F9
    // 90D1  AD 26 BF   lda  temp_data__current_board_row
    // 90D4  CD 30 BF   cmp  temp_data__curr_line
    // 90D7  D0 20      bne  W90F9
    // W90D9:
    // 90D9  B1 FB      lda  (io_FREEZP),y
    // 90DB  30 04      bmi  W90E1
    // 90DD  AA         tax
    // 90DE  BD FF 8A   lda  W8AFF,x
    // W90E1:
    // 90E1  8D 4E BD   sta  WBD4E
    // 90E4  30 13      bmi  W90F9
    // 90E6  A2 06      ldx  #$06
    // 90E8  B1 39      lda  (io_CURLIN),y
    // 90EA  29 7F      and  #$7F
    // W90EC:
    // 90EC  18         clc
    // 90ED  6D 4E BD   adc  WBD4E
    // 90F0  CA         dex
    // 90F1  D0 F9      bne  W90EC
    // 90F3  8D 1A BF   sta  temp_data__curr_color
    // 90F6  4C 00 91   jmp  W9100
    //
    // Draw the square. Squares are 2x2 characters. The start is calculated as follows:
    // - offset = row offset + (current column * 2) + current column
    // We call `render_sqaure_row` which draws 2 characters. We then increase the offset by 40 (moves to next line)
    // and call `render_sqaure_row` again to draw the next two characters.
    lda (CURLIN),y
    and #$7F
    sta main.temp.data__curr_color
    lda (CURLIN),y
    bmi !next+
    lda board_data.square_color_data__square+1
    bpl !skip+
!next:
    lda curr_color_phase
!skip:
    ora #$08 // Derive square color
    sta main.temp.data__current_square_color_code
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

// 9139
// Draws 3 characters of the current row.
draw_sqaure_part:
    lda #$03
    sta main.temp.data__counter
!loop:
    lda main.temp.data__curr_color
    sta (FREEZP+2),y
    lda (VARPNT),y
    and #$F0
    ora  main.temp.data__current_square_color_code
    sta (VARPNT),y
    iny
//     lda WBD4E
//     bmi W9155
//     inc temp_data__curr_color
// W9155:
    dec main.temp.data__counter
    bne !loop-
    rts

// 916E
// Draws a border around the board.
draw_border:
    .const BORDER_CHARACTER = $C0
    // Draw top border.
    lda board_data.row_screen_offset_lo_ptr
    sec
    sbc #(CHARS_PER_SCREEN_ROW + 1) // 1 row and 1 character before start of board
    sta FREEZP+2 // Screen offset
    sta FORPNT // Color memory offset
    lda board_data.row_screen_offset_hi_ptr
    sbc #$00
    sta FREEZP+3
    clc
    adc main.screen.color_mem_offset
    sta FORPNT+1
    ldy #(9*3 + 1) // 9 squares (3 characters per square) + 1 character each side of board (0 based)
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
    ldx #(9*2) //  9 squares (2 characters per square)
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
    ldy #(9*3 + 1) // 9 squares (3 characters per square) + 1 character each side of board (0 based)
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

// 927A
draw_magic_squares:
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace board_data {
    .const NUM_SQAURES_PER_ROW = 9
    .const ROW_START_OFFSET = $7e
    .const ROWS_PER_SQUARE = 2

    // 0B5D
    .enum { DARK = $00, LITE = $60, VARY = $E0 }
    sqaure_colors: // Board sqaure colors
        .byte DARK, LITE, DARK, VARY, VARY, VARY, LITE, DARK, LITE
        .byte LITE, DARK, VARY, LITE, VARY, DARK, VARY, LITE, DARK
        .byte DARK, VARY, LITE, DARK, VARY, LITE, DARK, VARY, LITE
        .byte VARY, LITE, DARK, LITE, VARY, DARK, LITE, DARK, VARY
        .byte LITE, VARY, VARY, VARY, VARY, VARY, VARY, VARY, DARK
        .byte VARY, LITE, DARK, LITE, VARY, DARK, LITE, DARK, VARY
        .byte DARK, VARY, LITE, DARK, VARY, LITE, DARK, VARY, LITE
        .byte LITE, DARK, VARY, LITE, VARY, DARK, VARY, LITE, DARK
        .byte DARK, LITE, DARK, VARY, VARY, VARY, LITE, DARK, LITE

    // 8BD2
    color_phase_data: // Colors used for each board game phase
        .byte BLACK, BLUE, RED, PURPLE, GREEN, YELLOW, CYAN, WHITE

    // 906F
    square_color_data__piece: // Board piece colors
        .byte YELLOW, LIGHT_BLUE

    // 9071
    square_color_data__square: // Board sqaure colors
        .byte BLACK, WHITE

    // 9073
    square_color_data__background: // Board background colors used when rendering the player board
        .byte BLACK, YELLOW, LIGHT_BLUE

    // BEAE
    row_screen_offset_lo_ptr: // Low byte screen memory offset of start of each board row
        .fill NUM_SQAURES_PER_ROW, <(ROW_START_OFFSET + i * ROWS_PER_SQUARE * CHARS_PER_SCREEN_ROW)

    // BEB7
    row_screen_offset_hi_ptr: // High byte screen memory offset of start of each board row
        .fill NUM_SQAURES_PER_ROW, >(SCNMEM + ROW_START_OFFSET + i * ROWS_PER_SQUARE * CHARS_PER_SCREEN_ROW)

    // BEC0
    row_occupancy_lo_ptr: // Low byte memory offset of square occupancy data for each board row
        .fill NUM_SQAURES_PER_ROW, <(square_occupant_data + i * NUM_SQAURES_PER_ROW)

    // BEC9
    row_occupancy_hi_ptr: // High byte memory offset of square occupancy data for each board row
        .fill NUM_SQAURES_PER_ROW, >(square_occupant_data + i * NUM_SQAURES_PER_ROW)

    // BED2
    row_color_lo_ptr: // Low byte memory offset of sqaure color data for each board row
        .fill NUM_SQAURES_PER_ROW, <(sqaure_colors + i * NUM_SQAURES_PER_ROW)

    // BEDB
    row_color_hi_ptr: // High byte memory offset of sqaure color data for each board row
        .fill NUM_SQAURES_PER_ROW, >(sqaure_colors + i * NUM_SQAURES_PER_ROW)
}
//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC2
flag__first_player: .byte $00 // Is positive for light, negative for dark

// BCC6
flag__current_player: .byte $00 // Is positive for light, negative for dark

// BD11
curr_color_phase: .byte $00 // Current board color phase (colors phase between light and dark as time progresses)

// BD7C
square_occupant_data: .fill 9*9, $00 // Board square occupant data (#$80 for no occupant)
