.filenamespace board_walk
//---------------------------------------------------------------------------------------------------------------------
// Initial board setup animation shown as part of the introduction sequence.
//---------------------------------------------------------------------------------------------------------------------
.segment Intro

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
    // Why no SEI and CLI wrapping it?
    lda #<interrupt_handler
    sta main.ptr__raster_interrupt_fn
    lda #>interrupt_handler
    sta main.ptr__raster_interrupt_fn+1
    // Set sprite second colour to black; exand all spites except 7 in X direction and expand only sprite 7 in y
    // direction.
    lda #$00
    sta data__icon_offset
    sta SPMC0
    sta YXPAND
    lda #%1000_0000
    sta XXPAND
    lda %0111_1111
    sta SPMC
    lda #BYTERS_PER_STORED_SPRITE
    sta common.param__sprite_source_size
    // Adds icon types to the board one at a time. Each icon is added by animating it (flying or walking) to the
    // icon's square.
    // The anitmation is performed using sprites that are loaded in to the first four sprite slots for each icon. After
    // the animation is completed, the icon is drawn on to the square using character set dot data (6 characters).
    // The board is redrawn for each icon.
    // The board current player indication (border color) is toggled as each side's icon is loaded.
    // The board is a 9x9 grid.
    // For description purposes, we'll number board squares as A-I across the top starting from left and 1 to 9 on the
    // sides starting at the bottom.
add_icon:
    jsr common.clear_sprites
    jsr board.set_player_color
    jsr board.draw_board
    jsr board.draw_border
    jsr board.create_magic_square_sprite
    ldx data__icon_offset
    // Read icon and location.
    // Each icon is represented as 4 bytes in a table.
    // - Byte 1: Icon type/Sprite offset
    // - Byte 2: Number of icons of the type (Only accepts 07, 02, and 01)
    // - Byte 3: Intitial column (00 = A, 01 = B etc)
    // - Byte 4: Row offset (00=1, 01=2 etc). The offset is mirrored for 2 icons (eg 02 = Row 3 and 7). For 07 icons
    //   row offset is the start row and other icons are adde done after the other below it.
    // There are a total of 16 different icon types.
    lda data__icon_location_list,x
    sta common.data__icon_type
    lda data__icon_location_list+1,x
    sta data__num_icons
    lda data__icon_location_list+2,x
    sta board.data__curr_board_col
    lda data__icon_location_list+3,x
    sta board.data__curr_board_row
    jsr animate_icon
    lda data__icon_offset
    clc
    adc #$04
    cmp #(16*4) // Check if finished (16 icon types * 4 data bytes)
    bcc !next+
    rts
!next:
    sta data__icon_offset
    // Toggle current player.
    lda game.flag__is_light_turn
    eor #$FF
    sta game.flag__is_light_turn
    jmp add_icon

// 8EB0
// Description:
// - Adds an icon to the board.
// Prerequisites:
// - `board.data__curr_board_col`: Destination column of piece
// - `board.data__curr_board_row`: Starting destination row of piece
// - `common.data__icon_type`: Type of piece to animation in to destination square
// - `data__num_icons`: Number of icons to add to board
// Notes:
// - If number of icons is set to 2, the destination row of the second piece is automatically calculated to be 9 minus
//   the source row.
// - If number of icons is set to 7, the destination row is incremented for each piece added.
animate_icon:
    ldx #$04 // Special code used by `convert_coord_sprite_pos` used to not set sprite position registers
    lda board.data__curr_board_col
    ldy board.data__curr_board_row
    jsr board.convert_coord_sprite_pos
    sta data__sprite_final_x_pos
    sty data__sprite_final_y_pos
    lda data__num_icons
    cmp #$07 // Adding 7 icons (knights, goblins)?
    bne !next+
    sta board.data__curr_board_row // Start at row 7
add_7_icons:
    jsr board.add_icon_to_matrix
    dec board.data__curr_board_row
    bne add_7_icons
    lda #$01 // Unused code?
    ldx #$10
    stx data__sprite_y_offset
    jmp add_icon_to_board
!next:
    jsr board.add_icon_to_matrix
    lda data__num_icons
    cmp #$02 // Adding 2 icons?
    bcc add_icon_to_board
    // Add 2 icons.
    lda board.data__curr_board_row
    sta board.data__curr_row
    lda #$08
    sec
    sbc board.data__curr_board_row
    sta board.data__curr_board_row
    jsr board.add_icon_to_matrix
    lda board.data__curr_row
    sec
    sbc board.data__curr_board_row
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
    sta data__sprite_y_offset
    // BF11
add_icon_to_board:
    // Creates sprites for each icon and animates them walking/flying in to the board position.
    lda #$00 // Starting X position
    ldy #$04 // Pixels to move for each alternative icon
    ldx game.flag__is_light_turn
    bpl !next+ // Start at right side and move to the left for player 2
    lda #$94
    ldy #$FC
!next:
    sty data__x_pixels_per_move
    sta pos__curr_sprite_x
    ldx data__num_icons
    dex
    stx ptr__sprite_mem
!loop:
    lda pos__curr_sprite_x
    sta common.pos__sprite_x_list,x
    dex
    // BUG!!: The original source code doesn't have the following line. Without the BMI, this causes a random bit of
    // memory to be overwritten if the number of icons being added to the board is odd (well not actually random, is
    // memory at common.pos__sprite_x_list + 255 bytes). Seems to be lucky in original source and not cause any issues.
    // But for us, we want the code to be relocatable. Took a while to find and fix this one :(
    bmi !next+
    clc
    adc data__x_pixels_per_move
    sta common.pos__sprite_x_list,x
    dex
    bpl !loop-
!next:
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
    stx common.cnt__curr_sprite_frame
    ldy common.data__icon_type
    lda board.data__piece_icon_offset_list,y
    sta common.idx__icon_offset
    jsr common.sprite_initialize
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
    ldx ptr__sprite_mem
!loop:
    lda SP0COL
    sta SP0COL,x
    lda data__sprite_final_y_pos
    sta common.pos__sprite_y_list,x
    clc
    adc data__sprite_y_offset
    sta data__sprite_final_y_pos
    dex
    bpl !loop-
    // Load sprites in to graphical memory. Add first 4 frames of the sprite icon set.
    lda #FLAG_ENABLE
    sta common.param__is_copy_animation_group
    and game.flag__is_light_turn
    sta common.data__icon_set_sprite_frame
    lda #$04
    sta common.param__sprite_source_frame
    lda common.ptr__sprite_00_mem
    sta FREEZP+2
    sta ptr__sprite_mem_lo
    lda common.ptr__sprite_00_mem+1
    sta FREEZP+3
    ldx #$00
!loop:
    jsr common.add_sprite_to_graphics
    lda ptr__sprite_mem_lo
    clc
    adc #BYTES_PER_SPRITE
    sta FREEZP+2
    sta ptr__sprite_mem_lo
    bcc !next+
    inc FREEZP+3
!next:
    inc common.data__icon_set_sprite_frame
    dec common.param__sprite_source_frame
    bne !loop-
    // Display icon name.
    jsr board.clear_text_area
    ldy common.idx__icon_offset
    lda board.ptr__icon_name_string_id_list,y
    ldx #$0A // Column offset 10
    jsr board.write_text
    // Set icon sound.
    ldx #$00
    jsr board.get_sound_for_icon
    lda board.ptr__player_sound_pattern_lo_list
    sta OLDTXT // pointer to sound pattern
    lda board.ptr__player_sound_pattern_hi_list
    sta OLDTXT+1
    // Enable icon plays sound on voice 1 only. Comprises two bytes; one for each player. `common_stop_sound` clears
    // both bytes to 00, so both voices are turned off by default
    lda #FLAG_ENABLE
    sta common.flag__enable_player_sound // Enable voice 1 sound
    jsr common.wait_for_key
    rts

// 8FE6
interrupt_handler:
    jsr board.draw_magic_square
    lda common.flag__enable_next_state
    bpl !next+
    jmp common.complete_interrupt
!next:
    jsr board.play_icon_sound
    // Update sprite frame and position.
    lda #$FF
    sta data__curr_count
    // Only update sprite position on every second
    lda flag__update_sprite_pos
    eor #$FF
    sta flag__update_sprite_pos
    bmi update_sprite
    jmp common.complete_interrupt
update_sprite:
    ldy #$01
    lda game.flag__is_light_turn
    bpl !next+
    ldy #$FF
!next:
    sty data__sprite_x_adj // Set direction
    ldx ptr__sprite_mem
    lda flag__sprite_direction
    eor #$FF
    sta flag__sprite_direction
    bmi check_sprite // Only update animation frame on every second position update
    inc common.cnt__curr_sprite_frame
check_sprite:
    lda common.pos__sprite_x_list,x
    cmp data__sprite_final_x_pos
    bne update_sprite_pos
    inc data__curr_count
    jmp next_sprite
update_sprite_pos:
    clc
    adc data__sprite_x_adj
    sta common.pos__sprite_x_list,x
    txa
    asl
    tay
    lda common.cnt__curr_sprite_frame
    and #$03 // Set animation frame (0 to 3)
    clc
    adc common.ptr__sprite_00_offset
    sta SPTMEM,x
    jsr board.render_sprite_preconf
next_sprite:
    dex
    bpl check_sprite // Set additional sprites
    ldx ptr__sprite_mem
    cpx data__curr_count
    bne !next+
    //
    lda #FLAG_ENABLE
    sta common.flag__enable_next_state
!next:
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// 8DF6
// Contains data for each board icon (type, number of, column, row offset). The data is represented in the order
// that the icons are added to the board.
data__icon_location_list:
    .byte KNIGHT,       7, 1, 1
    .byte GOBLIN,       7, 7, 1
    .byte ARCHER,       2, 1, 8
    .byte MANTICORE,    2, 7, 8
    .byte VALKYRIE,     2, 0, 8
    .byte BANSHEE,      2, 8, 8
    .byte GOLEM,        2, 0, 7
    .byte TROLL,        2, 8, 7
    .byte UNICORN,      2, 0, 6
    .byte BASILISK,     2, 8, 6
    .byte DJINNI,       1, 0, 3
    .byte DRAGON,       1, 8, 5
    .byte PHOENIX,      1, 0, 5
    .byte SHAPESHIFTER, 1, 8, 3
    .byte WIZARD,       1, 0, 4
    .byte SORCERESS,    1, 8, 4

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCEE
// Updates the sprite position
flag__update_sprite_pos: .byte $00

// BCEF
// Alternating icon direction (icons walk one one type at a time, alternating between sides).
flag__sprite_direction: .byte $00

// BCFE
// Temporary counter storage.
data__curr_count: .byte $00

// BD17
// Final X position of animated sprite.
data__sprite_final_x_pos: .byte $00

// BD26
// Current sprite location pointer.
ptr__sprite_mem: .byte $00

// BD38
// Number of board icons to render.
data__num_icons:.byte $00

// BD3A
// Offset of current icon being rendered on to the board.
data__icon_offset: .byte $00

// BD58
// Sprite X direction adjustment. Is positive number for right direction, negative for left direction.
data__sprite_x_adj: .byte $00

// BF1A
// Pixels to move intro sprite for each frame.
data__x_pixels_per_move: .byte $00

// BF1B
// Current X offset of the sprite.
pos__curr_sprite_x: .byte $00

// BF23
// Low byte of current sprite memory location pointer. Used to increment to next sprite pointer location (by adding 64
// bytes) when adding chasing icon sprites.
ptr__sprite_mem_lo: .byte $00

// BF25
// Final Y position of animated sprite.
data__sprite_final_y_pos: .byte $00

// BF3B
// Calculated Y offset for each sprite.
data__sprite_y_offset: .byte $00
