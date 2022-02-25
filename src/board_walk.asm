.filenamespace board_walk
//---------------------------------------------------------------------------------------------------------------------
// Initial board setup animation shown as part of the introduction sequence.
//---------------------------------------------------------------------------------------------------------------------
.segment Intro

// 8E36
// Set the board one icon type at a time. Animate the icon to the initial location and display the icon name and
// number of moves.
entry:
    jsr common.clear_screen
    // Configure graphics area again.
    lda #%0001_0010
    sta VMCSB // $0000-$07FF char memory, $0400-$07FF screen memory
    lda SCROLX
    ora #%0001_0000 // Multicolor bitmap mode off
    sta SCROLX
    // Set interrupt handler to handle animation of the current icon type to the final location.
    // BUG: I guess we should SEI and CLI before updating the interrupt pointers.
    lda #<private.interrupt_handler
    sta main.ptr__raster_interrupt_fn
    lda #>private.interrupt_handler
    sta main.ptr__raster_interrupt_fn+1
    //
    lda #$00
    sta private.idx__icon_location // Default to first icon in the icon location list
    sta SPMC0 // Set sprite second background colour to black
    sta YXPAND // Ensure all icons are not expanded in Y direction
    lda #%1000_0000 
    sta XXPAND // Ensure icons 0-7 are not expanded in X direction
    lda %0111_1111
    sta SPMC // Set multicolor mode for sprites 0-7
    //
    lda #BYTERS_PER_STORED_SPRITE
    sta common.param__sprite_source_len
    // Adds icon types to the board one at a time. Each icon is added by animating it (flying or walking) to the
    // icon's square.
    // The anitmation is performed using sprites that are loaded in to the first four sprite slots for each icon. After
    // the animation is completed, the icon is drawn on to the square using character set dot data (6 characters).
    // The board current player indication (border color) is toggled as each side's icon is loaded.
!icon_loop:
    jsr common.clear_sprites
    jsr board.set_player_color
    jsr board.draw_board
    jsr board.draw_border
    jsr board.create_magic_square_sprite
    //
    // Read icon and location.
    // Each icon is represented as 4 bytes in a table.
    // - Byte 1: Icon type
    // - Byte 2: Number of icons of the type (Only accepts 07, 02, and 01)
    // - Byte 3: Intitial column (00 = A, 01 = B etc)
    // - Byte 4: Row offset (00=1, 01=2 etc). The offset is mirrored if 2 icons (eg 02 = Row 3 and 7). If 7 icons,
    //   row offset is the start row and other icons are added one after the other below it.
    ldx private.idx__icon_location
    lda private.data__icon_location_list,x
    sta common.param__icon_type_list
    lda private.data__icon_location_list+1,x
    sta private.data__num_icons
    lda private.data__icon_location_list+2,x
    sta board.data__curr_board_col
    lda private.data__icon_location_list+3,x
    sta board.data__curr_board_row
    jsr private.add_icon_type_to_board
    //
    lda private.idx__icon_location
    clc
    adc #$04
    cmp #(16*4) // Check if finished (16 icon types * 4 data bytes)
    bcc !next+
    rts
!next:
    sta private.idx__icon_location
    // Toggle current player.
    lda game.flag__is_light_turn
    eor #$FF
    sta game.flag__is_light_turn
    jmp !icon_loop-

//---------------------------------------------------------------------------------------------------------------------
// Private functions.
.namespace private {
    // 8EB0
    // Adds an icon to the board and configures the interrupt handler to walk the icon to the correct location on the
    // board
    // Requires:
    // - `board.data__curr_board_col`: Destination column of piece.
    // - `board.data__curr_board_row`: Starting destination row of piece.
    // - `common.param__icon_type_list`: Type of piece to animation in to destination square.
    // - `data__num_icons`: Number of icons to add to board.
    // Notes:
    // - If number of icons is set to 2, the destination row of the second piece is automatically calculated to be
    //   9 minus the source row.
    // - If number of icons is set to 7, the destination row is incremented for each piece added.
    add_icon_type_to_board:
        // Calculate final location of the sprite so that it stops over the initial square for the icon piece.
        ldx #$04 // Special code used by `convert_coord_sprite_pos` used to not set sprite position registers
        lda board.data__curr_board_col
        ldy board.data__curr_board_row
        jsr board.convert_coord_sprite_pos
        sta data__sprite_final_x_pos
        sty data__sprite_final_y_pos
        lda data__num_icons
        // Add icon types with 7 initial pieces (knights, goblins)
        cmp #$07 // Adding 7 icons 
        bne !next+
        sta board.data__curr_board_row // Start at row 7
    !add_icon:
        jsr board.add_icon_to_matrix
        dec board.data__curr_board_row
        bne !add_icon-
        lda #$01 // Looks like unsed code
        .const SPRITE_HEIGHT=$10
        ldx #SPRITE_HEIGHT // Sets the vertical distance between each sprite (directly under each other)
        stx data__sprite_y_offset
        jmp !add_icon_sprites+
        //
    !next:
        // Add the first icon in the given row/column
        jsr board.add_icon_to_matrix
        //
        // Add icon types with 2 initial pieces. We already added one above, so now we need to calculate the
        // row position by subtracting the starting row from 9 and adding a second icon on the derived row.
        lda data__num_icons
        cmp #$02 // Adding 2 icons?
        bcc !add_icon_sprites+
        // Add 2 icons.
        lda board.data__curr_board_row
        sta cnt__board_row
        lda #(BOARD_NUM_ROWS - 1) // 0 offset
        sec
        sbc board.data__curr_board_row 
        sta board.data__curr_board_row // 2nd icon is will always be in the vertically mirrored row location
        jsr board.add_icon_to_matrix
        // The code below allows us to to set the first icon in the 2 set icon group as either the first or the last
        // row that that the icon will be displayed. For example, we could set the starting row for the Unicorn at
        // either row 6 or row 2 and the mirrored row will be correctly determed. However, the starting row is always
        // stored as the higher row number (6 in the case of Unicorn) and therefore code isn't really needed. The
        // BCS will always fire.
        lda cnt__board_row
        sec
        sbc board.data__curr_board_row
        bcs !next+
        eor #$FF
        adc #$01
    !next:
        // Calculate the sprite offset of the second icon. This is achieved by multiplying the distance between
        // the rows by 16 (height of the sprite). The EOR + 1 is used to ensure the offset is negative if the starting
        // row is higher than the mirrored row.
        asl
        asl
        asl
        asl
        eor #$FF
        adc #$01
        sta data__sprite_y_offset
        //
    !add_icon_sprites:
        // Creates sprites for each icon and animates them walking/flying in to the board position.
        lda #$00 // Starting X position (left side of board)
        ldy #$04 // Starting X offset for alternative icons if displaying 7 icons (so they walk in staggered)
        ldx game.flag__is_light_turn
        bpl !next+ // Start at right side and move to the left for dark player
        lda #$94 // Starting X position (right side of board)
        ldy #-($04)
    !next:
        sty data__sprite_group_piece_x_offset
        sta data__sprite_start_x_pos
        //
        ldx data__num_icons
        dex
        stx data__num_icons_zero_offset
        //
        // Set starting X position for each piece sprite in the icon group.
    !loop:
        lda data__sprite_start_x_pos
        sta common.data__sprite_curr_x_pos_list,x
        dex
        // BUG: The original source code doesn't have the following line. Without the BMI, this causes a random bit
        // of memory to be overwritten if the number of icons being added to the board is odd (well not actually
        // random, is memory at common.data__sprite_curr_x_pos_list + 255 bytes). Seems to be lucky in original source
        // and not cause any issues. But for us, we want the code to be relocatable. Took a while to find and fix this
        // one :(
        bmi !next+
        clc
        adc data__sprite_group_piece_x_offset
        sta common.data__sprite_curr_x_pos_list,x
        dex
        bpl !loop-
    !next:
        // Set the intial Y position of the first 7 sprites to 0. This will hide any sprites that we aren't currently
        // using as the first 7 sprites are configured to all point to the same sprite shape data.
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
        stx common.cnt__sprite_frame_list // Start sprite animation on first frame in sprite group
        ldy common.param__icon_type_list
        lda board.data__piece_icon_offset_list,y
        sta common.param__icon_offset_list
        jsr common.sprite_initialize
        // Configure sprites.
        lda #%1111_1111 // Enable all sprites
        sta SPENA
        lda #1000_0000 // Set sprite 7 expanded, all other normal (sprite 7 is used for magic square)
        sta XXPAND
        lda #%0111_1111 // Enable multicolor more on all sprites except 7
        sta SPMC
        lda #BLACK // Set multicolor background color to black
        sta SPMC0
        //
        // Configure the sprites for each piece
        ldx data__num_icons_zero_offset
    !loop:
        lda SP0COL
        sta SP0COL,x
        lda data__sprite_final_y_pos
        sta common.data__sprite_curr_y_pos_list,x
        clc
        adc data__sprite_y_offset
        sta data__sprite_final_y_pos // Calculated Y offset for next piece
        dex
        bpl !loop-
        //
        // Load sprites in to graphical memory. Add first 4 frames of the sprite icon set.
        lda #FLAG_ENABLE
        sta common.param__is_copy_animation_group
        and game.flag__is_light_turn // Starting frame has +$80 if sprite should be horizontally mirrored (left facing)
        sta common.param__icon_sprite_curr_frame
        // Copy 4 frames and start at sprite block 0 in graphical memory
        lda #$04
        sta common.param__icon_sprite_source_frame_list
        lda common.ptr__sprite_00_mem
        sta FREEZP+2
        sta ptr__sprite_mem_lo // Lo pointer is stored so we can add $40 (64 bytes per sprite) for sprite frame
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
        inc common.param__icon_sprite_curr_frame
        dec common.param__icon_sprite_source_frame_list
        bne !loop-
        //
        // Display icon type name and number of moves.
        jsr board.clear_text_area
        ldy common.param__icon_offset_list
        lda board.ptr__icon_name_string_id_list,y
        .const STRING_START_COL = 10
        ldx #STRING_START_COL
        jsr board.write_text
        //
        // Set icon sound.
        ldx #$00
        jsr board.get_sound_for_icon
        lda board.ptr__player_sound_pattern_lo_list
        sta OLDTXT
        lda board.ptr__player_sound_pattern_hi_list
        sta OLDTXT+1
        lda #FLAG_ENABLE
        sta common.flag__is_player_sound_enabled // Enable icon movement sound on voice 1 only.
        //
        // The method will return if the background interrupt completes (ie piece has reached final location) or a
        // function key or Q is pressed.
        jsr common.wait_for_key_or_task_completion
        rts

    // 8FE6
    // Animate the icon by walking it to the initial board square location.
    interrupt_handler:
        jsr board.draw_magic_square
        lda common.flag__cancel_interrupt_state
        bpl !next+
        jmp common.complete_interrupt
    !next:
        jsr board.play_icon_sound
        // Bit messy - has negative 1 as count is incremented before it is comppared with `data__num_icons_zero_offset`.
        // Could have initialized to 0 and then compared against `data__num_icons` (not zero offset version). Oh well.
        lda #-($01)
        sta cnt__pieces_at_final_location
        // Only update the sprite location on every second interrupt (otherwise they walk too fast).
        lda cnt__sprite_move_delay
        eor #$FF
        sta cnt__sprite_move_delay
        bmi !next+
        jmp common.complete_interrupt
    !next:
        // Set X addend on each move. Is +1 for left to right movement and -1 for right to left movement.
        ldy #$01
        lda game.flag__is_light_turn
        bpl !next+
        ldy #-($01)
    !next:
        sty data__sprite_x_addend
        //
        ldx data__num_icons_zero_offset
        // Only update animation frame on every second position update.
        lda cnt__sprite_frame_list_adv_delay
        eor #$FF
        sta cnt__sprite_frame_list_adv_delay 
        bmi !check_next_pos+
        inc common.cnt__sprite_frame_list
        //
        // Detect if the current sprite is at the final location. Exit when all sprites have reached the location.
    !check_next_pos:
        lda common.data__sprite_curr_x_pos_list,x
        cmp data__sprite_final_x_pos
        bne !skip+
        // Leave sprite in final location and move to next sprite. Increment count of number of pieces that are at the
        // final location.
        inc cnt__pieces_at_final_location 
        jmp !next_sprite+
    !skip:
        // Set sprite horizontal position.
        clc
        adc data__sprite_x_addend
        sta common.data__sprite_curr_x_pos_list,x
        // Set sprite pointer to point to the current sprite animation frame.
        txa
        asl
        tay
        lda common.cnt__sprite_frame_list
        and #$03 // Set animation frame (0 to 3)
        clc
        adc common.ptr__sprite_00_offset
        sta SPTMEM,x
        // 
        jsr board.set_sprite_location
        //
    !next_sprite:
        dex
        bpl !check_next_pos-
        // End current icon type if all sprites at final location.
        ldx data__num_icons_zero_offset
        cpx cnt__pieces_at_final_location
        bne !next+
        lda #FLAG_ENABLE
        sta common.flag__cancel_interrupt_state
    !next:
        jmp common.complete_interrupt
}

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 8DF6
    // Contains data for each board icon (type, number of, column, row offset). The data is represented in the order
    // that the icons are added to the board.
    data__icon_location_list:
        //    Icon type     #  C  R
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

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BCEE
    // Counter before sprite is moved in the horizontal direction.
    cnt__sprite_move_delay: .byte $00

    // BCEF
    // Counter before sprite frame is advanced for sprite movement animation.
    cnt__sprite_frame_list_adv_delay: .byte $00

    // BCFE
    // Count of icon pieces that have reached the board square location.
    cnt__pieces_at_final_location: .byte $00

    // BD17
    // Final X position of animated sprite.
    data__sprite_final_x_pos: .byte $00

    // BD26
    // Number of pieces to render for current icon type (0 offset).
    // Note this is simply `data__num_icons` minus 1. It is used as some comparisons and offsets require a zero offset
    // value.
    data__num_icons_zero_offset: .byte $00

    // BD38
    // Number of pieces to render for current icon type (1 offset).
    data__num_icons: .byte $00

    // BD3A
    // Index in to the icon location list for current icon being rendered on to the board.
    idx__icon_location: .byte $00

    // BD58
    // Sprite X direction adjustment. Is positive number for right direction, negative for left direction.
    data__sprite_x_addend: .byte $00

    // BF1A
    // Pixels to move each sprite in a group of 7 icons so that the icons are offset when they walk on.
    data__sprite_group_piece_x_offset: .byte $00

    // BF1B
    // Starting X position of the first sprite in the current icon group.
    data__sprite_start_x_pos: .byte $00

    // BF23
    // Low byte of current sprite memory location pointer. Used to increment to next sprite pointer location (by adding
    // 64 bytes) when adding chasing icon sprites.
    ptr__sprite_mem_lo: .byte $00

    // BF25
    // Final Y position of animated sprite.
    data__sprite_final_y_pos: .byte $00

    // BF30
    // Current board row.
    cnt__board_row: .byte $00

    // BF3B
    // Calculated Y offset for each sprite.
    data__sprite_y_offset: .byte $00
}
