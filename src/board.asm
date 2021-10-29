.filenamespace board

//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used for rendering the game board.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

.segment Common

// 6422
// Converts a board row and column coordinate to a corresponding sprite screen position.
// Requires:
// - A Register: Board column
// - Y Register: Board row
// - X Register: Sprite number
// Sets `main.sprite.curr_x_pos,x` and `main.sprite.curr_y_pos,x` with the calculated position for all sprites except
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
    sta main.sprite.curr_x_pos,x
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
    sta main.sprite.curr_y_pos,x
!next:
    tay
    pla
    rts

// 6509
// Writes a predefined text message to the board text area.
// Requires:
// - A regsiter set with the text message offset.
write_text:
    asl
    tay
    lda screen.message_ptr,y
    sta FREEZP
    lda screen.message_ptr+1,y
    sta FREEZP+1
    ldy #$00
!loop:
    lda (io_FREEZP),y
    bpl !next
    rts
!next:
    // Convert petscii to correct game character map offset.
    and #$3F
    clc
    adc #$C0 
    sta (SCNMEM+23*CHARS_PER_SCREEN_ROW),x
    inx
    iny
    jmp loop

// 8965
// Adds a piece to the board matrix.
// Requires the board row and column to be set in the temp data.
add_piece_to_matrix:
    ldy main.temp.data__current_board_row
    lda board_data.row_occupancy_lo_ptr,y
    sta OLDLIN
    lda board_data.row_occupancy_hi_ptr,y
    sta OLDLIN+1
    //
    ldy main.temp.data__current_board_col
    lda main.temp.data__piece_type
    sta (OLDLIN),y
    rts

// 8D80
// Places a sprite at a given location and enables the sprite.
// The following prerequisites are required:
// - The sprite location is set in `main_sprite_curr_x_pos` and `main_sprite_curr_y_pos`.
// - X register is loaded with the sprite number to be enabled.
// - Y register is loaded with 2 * the sprite number to be enabled.
// The Y position is offset by 50 and X position is doubled and then offset by 24.
render_sprite:
    lda main.sprite.curr_y_pos,x
    clc
    adc #$32
    sta SP0Y,y
    //
    lda main.sprite.curr_x_pos,x
    clc
    adc main.sprite.curr_x_pos,x
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
    // 90F3  8D 1A BF   sta  temp_data__curr_board_piece
    // 90F6  4C 00 91   jmp  W9100
    //
    // Draw the square. Squares are 2x2 characters. The start is calculated as follows:
    // - offset = row offset + (current column * 2) + current column
    // We call `render_sqaure_row` which draws 2 characters. We then increase the offset by 40 (moves to next line)
    // and call `render_sqaure_row` again to draw the next two characters.
    lda (CURLIN),y
    and #$7F
    sta main.temp.data__curr_board_piece
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
    lda main.temp.data__curr_board_piece
    sta (FREEZP+2),y
    lda (VARPNT),y
    and #$F0
    ora  main.temp.data__current_square_color_code
    sta (VARPNT),y
    iny
//     lda WBD4E <-- this must be TRUE for draw piece
//     bmi W9155
//     inc main.temp.data__curr_board_piece // THIS DREW PIECES!!!!!!!!!!!!
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
// Create the sprite used to indicate a magic board square.
// The sprite is stored in sprite offset 48.
create_magic_square_sprite:
    lda main.sprite._48_memory_ptr
    sta FREEZP+2
    lda main.sprite._48_memory_ptr+1
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
    cpy #$05                         // Total number of magic sqaures
    bcc !next+
    ldy #$00
!next:
    .const SPRITE_NUMBER=7
    sty magic_square_counter
    lda sprite.magic_square_x_pos,y
    sta main.sprite.curr_x_pos+SPRITE_NUMBER
    lda sprite.magic_square_y_pos,y
    sta main.sprite.curr_y_pos+SPRITE_NUMBER
    //
    ldx #SPRITE_NUMBER
    lda main.sprite._48_screen_ptr
    sta SPTMEM+SPRITE_NUMBER
    ldy #(SPRITE_NUMBER*2)
    jmp render_sprite


// 9352
// Clear text area underneath the board and reset the color to white.
clear_text_area:
    ldx #(CHARS_PER_SCREEN_ROW*2-1) // Two rows of text
!loop:
    lda #$00
    sta (SCNMEM+23*CHARS_PER_SCREEN_ROW),x // Start at 23rd text row
    lda (COLRAM+23*CHARS_PER_SCREEN_ROW),x
    and #$F0
    ora #$01
    sta (COLRAM+23*CHARS_PER_SCREEN_ROW),x
    dex
    bpl !loop-
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

.namespace sprite {
    // 929B
    magic_sqauare_data: // Sprite data used to create the magic square icon
        .byte $00, $00, $00, $00, $00, $18, $24, $5A, $5A, $5A, $24, $18

    // 92E1
    magic_square_x_pos: .byte $4A, $1A, $4A, $4A, $7A // Sprite X position of each magic square

    // 92E6
    magic_square_y_pos: .byte $17, $57, $57, $97, $57 // Sprite Y position of each magic square
}

.namespace screen {
    // A21E
    message_ptr: // Pointer to start predefined text message. Messages are FF terminated.
        .word string_1,  string_2,  string_3,  string_4,  string_5,  string_6,  string_7,  string_8
        .word string_9,  string_10, string_11, string_12, string_13, string_14, string_15, string_16
        .word string_17, string_18, string_19, string_20, string_21, string_22, string_23, string_24
        .word string_25, string_26, string_27, string_28, string_29, string_30, string_31, string_32
        .word string_33, string_34, string_35, string_36, string_37, string_38, string_39, string_40
        .word string_41, string_42, string_43, string_44, string_45, string_46, string_47, string_48
        .word string_49, string_50, string_51, string_52, string_53, string_54, string_55, string_56
        .word string_57, string_58, string_59, string_60, string_61, string_62, string_63, string_64
        .word string_65, string_66, string_67, string_68, string_69, string_70, string_71

    // A2AC
    string_2: .text @"ALAS, MASTER, THIS ICON CANNOT MOVE\$ff"

    // A2D0
    string_3: .text @"DO YOU CHALLENGE THIS FOE?\$ff"

    // A2EB
    string_4: .text @"YOU HAVE MOVED YOUR LIMIT\$ff"

    // A305
    string_5: .text @"THE SQUARE AHEAD IS OCCUPIED\$ff"

    // A322
    string_7: .text @"THE LIGHT SIDE WINS\$ff"

    // A336
    string_8: .text @"THE DARK SIDE WINS\$ff"

    // A349
    string_9: .text @"IT IS A TIE\$ff"

    // A355
    string_10: .text @"THE FLOW OF TIME IS REVERSED\$ff"

    // A372
    string_11: .text @"WHICH ICON WILL YOU HEAL?\$ff"

    // A38C
    string_6: .text @"IT IS DONE\$ff"

    // A397
    string_12: .text @"WHICH ICON WILL YOU TELEPORT?\$ff"

    // A3B5
    string_13: .text @"WHERE WILL YOU TELEPORT IT?\$ff"

    // A3D1
    string_14: .text @"CHOOSE AN ICON TO TRANSPOSE\$ff"

    // A3ED
    string_15: .text @"EXCHANGE IT WITH WHICH ICON?\$ff"

    // A40A
    string_16: .text @"WHAT ICON WILL YOU REVIVE?\$ff"

    // A425
    string_17: .text @"PLACE IT WITHIN THE CHARMED SQUARE\$ff"

    // A448
    string_18: .text @"WHICH FOE WILL YOU IMPRISON?\$ff"

    // A465
    string_19: .text @"ALAS, MASTER, THERE IS NO OPENING IN THECHARMED SQUARE. CONJURE ANOTHER SPELL\$ff"

    // A4B3
    string_26: .text @"SEND IT TO THE TARGET\$ff"

    // A4C9
    string_54: .text @"THAT SPELL WOULD BE WASTED AT THIS TIME\$ff"

    // A4F0
    string_55: .text @"SELECT A SPELL\$ff"

    // A500
    string_20: .text @"HAPPILY, MASTER, ALL YOUR ICONS LIVE.   PLEASE CONJURE A DIFFERENT SPELL\$ff"

    // A549
    string_21: .text @"ALAS, THIS ICON IS IMPRISONED\$ff"

    // A567
    string_22: .text @"AN AIR\$ff"

    // A56E
    string_23: .text @"A FIRE\$ff"

    // A575
    string_25: .text @"A WATER\$ff"

    // A57D
    string_24: .text @"AN EARTH\$ff"

    // A586
    string_27: .text @"THE WIZARD\$ff"

    // A591
    string_28: .text @"THE SORCERESS\$ff"

    // A59F
    string_1: .text @"OH, WOE! YOUR SPELLS ARE GONE!\$ff"

    //A5BE
    string_29: .text @"UNICORN (GROUND 4)\$ff"

    // A5D1
    string_30: .text @"WIZARD (TELEPORT 3)\$ff"

    // A5E5
    string_31: .text @"ARCHER (GROUND 3)\$ff"

    // A5F7
    string_32: .text @"GOLEM (GROUND 3)\$ff"

    // A608
    string_33: .text @"VALKYRIE (FLY 3)\$ff"

    // A619
    string_34: .text @"DJINNI (FLY 4)\$ff"

    // A628
    string_35: .text @"PHOENIX (FLY 5)\$ff"

    // A638
    string_36: .text @"KNIGHT (GROUND 3)\$ff"

    // A64A
    string_37: .text @"BASILISK (GROUND 3)\$ff"

    // A65E
    string_38: .text @"SORCERESS (TELEPORT 3)\$ff"

    // A675
    string_39: .text @"MANTICORE (GROUND 3)\$ff"

    // A68A
    string_40: .text @"TROLL (GROUND 3)\$ff"

    // A69B
    string_41: .text @"SHAPESHIFTER (FLY 5)\$ff"

    // A6B0
    string_42: .text @"DRAGON (FLY 4)\$ff"

    // A6BF
    string_43: .text @"BANSHEE (FLY 3)\$ff"

    // A6CF
    string_44: .text @"GOBLIN (GROUND 3)\$ff"

    // A6E1
    string_45: .text @"TELEPORT\$ff"

    // A6EA
    string_46: .text @"HEAL\$ff"

    // A6EF
    string_47: .text @"SHIFT TIME\$ff"

    // A6FA
    string_48: .text @"EXCHANGE\$ff"

    // A703
    string_49: .text @"SUMMON ELEMENTAL\$ff"

    // A714
    string_50: .text @"REVIVE\$ff"

    // A71B
    string_51: .text @"IMPRISON\$ff"

    // A724
    string_52: .text @"CEASE CONJURING\$ff"

    // A734
    string_53: .text @"POWER POINTS ARE PROOF AGAINST MAGIC\$ff"

    // A759
    string_56: .text @"COMPUTER \$ff"

    // A763
    string_57: .text @"LIGHT \$ff"

    // A76A
    string_58: .text @"TWO-PLAYER \$ff"

    // A776
    string_59: .text @"FIRST\$ff"

    // A77C
    string_60: .text @"DARK \$ff"

    // A782
    string_61: .text @"WHEN READY\$ff"

    // A78D
    string_62: .text @" PRESS \$ff"

    // A795
    string_63: .text @"SPELL IS CANCELED. CHOOSE ANOTHER\$ff"

    // A7B7
    string_64: .text @"THE GAME IS ENDED...\$ff"

    // A7CC
    string_65: .text @"IT IS A STALEMATE\$ff"

    // A7DE
    string_66: .text @" ELEMENTAL APPEARS!\$ff"

    // A7F2
    string_67: .text @" CONJURES A SPELL!\$ff"

    //A805
    string_68: .text @"PRESS\$00RUN\$00KEY\$00TO\$00CONTINUE\$ff"

    // A81F
    string_69: .text @"F7\$ff"

    // A822
    string_70: .text @"F5: \$ff"

    // A827
    string_71: .text @"F3: \$ff"
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

// BF44
magic_square_counter: .byte $00 // Current magic square (1-5) being rendered
