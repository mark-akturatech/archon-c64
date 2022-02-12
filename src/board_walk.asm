.filenamespace board_walk

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for displaying and animating the board setup animations.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

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
    sta main.interrupt.raster_fn_ptr
    lda #>interrupt_handler
    sta main.interrupt.raster_fn_ptr+1
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
    sta board.sprite.copy_length
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
    lda icon.data,x
    sta board.icon.type
    lda icon.data+1,x
    sta data__num_icons
    lda icon.data+2,x
    sta board.data__curr_board_col
    lda icon.data+3,x
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
    lda game.state.flag__is_light_turn
    eor #$FF
    sta game.state.flag__is_light_turn
    jmp add_icon

// 8EB0
// Description:
// - Adds an icon to the board.
// Prerequisites:
// - `board.data__curr_board_col`: Destination column of piece
// - `board.data__curr_board_row`: Starting destination row of piece
// - `board.icon.type`: Type of piece to animation in to destination square
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
    ldx game.state.flag__is_light_turn
    bpl !next+ // Start at right side and move to the left for player 2
    lda #$94
    ldy #$FC
!next:
    sty data__x_pixels_per_move
    sta data__sprite_x_pos
    ldx data__num_icons
    dex
    stx data__curr_sprite_ptr
!loop:
    lda data__sprite_x_pos
    sta common.sprite.curr_x_pos,x
    dex
    clc
    adc data__x_pixels_per_move
    sta common.sprite.curr_x_pos,x
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
    stx common.sprite.curr_animation_frame
    ldy board.icon.type
    lda board.icon.init_matrix,y
    sta board.icon.offset
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
    ldx data__curr_sprite_ptr
!loop:
    lda SP0COL
    sta SP0COL,x
    lda data__sprite_final_y_pos
    sta common.sprite.curr_y_pos,x
    clc
    adc data__sprite_y_offset
    sta data__sprite_final_y_pos
    dex
    bpl !loop-
    // Load sprites in to graphical memory. Add first 4 frames of the sprite icon set.
    lda #FLAG_ENABLE
    sta board.sprite.flag__copy_animation_group
    and game.state.flag__is_light_turn
    sta board.data__icon_set_sprite_frame
    lda #$04
    sta common.sprite.init_animation_frame
    lda common.sprite.mem_ptr_00
    sta FREEZP+2
    sta data__curr_sprite_mem_lo_ptr
    lda common.sprite.mem_ptr_00+1
    sta FREEZP+3
    ldx #$00
!loop:
    jsr board.add_sprite_to_graphics
    lda data__curr_sprite_mem_lo_ptr
    clc
    adc #BYTES_PER_SPRITE
    sta FREEZP+2
    sta data__curr_sprite_mem_lo_ptr
    bcc !next+
    inc FREEZP+3
!next:
    inc board.data__icon_set_sprite_frame
    dec common.sprite.init_animation_frame
    bne !loop-
    // Display icon name.
    jsr board.clear_text_area
    ldy board.icon.offset
    lda board.icon.string_id,y
    ldx #$0A // Column offset 10
    jsr board.write_text
    // Set icon sound.
    ldx #$00
    jsr board.get_sound_for_icon
    lda board.sound.pattern_lo_ptr
    sta OLDTXT // pointer to sound pattern
    lda board.sound.pattern_hi_ptr
    sta OLDTXT+1
    // Enable icon plays sound on voice 1 only. Comprises two bytes; one for each player. `common_stop_sound` clears
    // both bytes to 00, so both voices are turned off by default
    lda #FLAG_ENABLE
    sta common.sound.flag__enable_voice // Enable voice 1 sound
    jsr common.wait_for_key
    rts

// 8FE6
interrupt_handler:
    jsr board.draw_magic_square
    lda main.state.flag__enable_next
    bpl !next+
    jmp common.complete_interrupt
!next:
    jsr board.play_icon_sound
    // Update sprite frame and position.
    lda #$FF
    sta data__curr_count
    // Only update sprite position on every second interrupt.
    lda flag__update_sprite_pos
    eor #$FF
    sta flag__update_sprite_pos
    bmi update_sprite
    jmp common.complete_interrupt
update_sprite:
    ldy #$01
    lda game.state.flag__is_light_turn
    bpl !next+
    ldy #$FF
!next:
    sty data__sprite_x_adj // Set direction
    ldx data__curr_sprite_ptr
    lda flag__sprite_direction
    eor #$FF
    sta flag__sprite_direction
    bmi check_sprite // Only update animation frame on every second position update
    inc common.sprite.curr_animation_frame
check_sprite:
    lda common.sprite.curr_x_pos,x
    cmp data__sprite_final_x_pos
    bne update_sprite_pos
    inc data__curr_count
    jmp next_sprite
update_sprite_pos:
    clc
    adc data__sprite_x_adj
    sta common.sprite.curr_x_pos,x
    txa
    asl
    tay
    lda common.sprite.curr_animation_frame
    and #$03 // Set animation frame (0 to 3)
    clc
    adc common.sprite.offset_00
    sta SPTMEM,x
    jsr board.render_sprite_preconf
next_sprite:
    dex
    bpl check_sprite // Set additional sprites
    ldx data__curr_sprite_ptr
    cpx data__curr_count
    bne !next+
    //
    lda #FLAG_ENABLE
    sta main.state.flag__enable_next
!next:
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace icon {
    // 8DF6
    // Contains data for each board icon (type, number of, column, row offset). The data is represented in the order
    // that the icons are added to the board.
    data:
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
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BD3A
// Offset of current icon being rendered on to the board.
data__icon_offset: .byte $00

// BF3B
// Calculated Y offset for each sprite.
data__sprite_y_offset: .byte $00

// BF25
// Final Y position of animated sprite.
data__sprite_final_y_pos: .byte $00

// BD17
// Final X position of animated sprite.
data__sprite_final_x_pos: .byte $00

// BD58
// Sprite X direction adjustment. Is positive number for right direction, negative for left direction.
data__sprite_x_adj: .byte $00

// BF1B
// Current X offset of the sprite.
data__sprite_x_pos: .byte $00

// BD38
// Number of baord icons to render.
data__num_icons:.byte $00

// BF1A
// Pixels to move intro sprite for each frame.
data__x_pixels_per_move: .byte $00

// BCEE
// Updates the sprite position 
flag__update_sprite_pos: .byte $00

// BCEF
// Alternating icon direction (icons walk one one type at a time, alternating between sides).
flag__sprite_direction: .byte $00

// BD26
// Current sprite location pointer.
data__curr_sprite_ptr: .byte $00

// BF23
// Low byte of current sprite memory location pointer. Used to increment to next sprite pointer location (by adding 64
// bytes) when adding chasing icon sprites.
data__curr_sprite_mem_lo_ptr: .byte $00

// BCFE
// Temporary counter storage.
data__curr_count: .byte $00
