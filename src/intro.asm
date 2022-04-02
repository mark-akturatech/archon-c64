.filenamespace intro
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used by the introduction.
//---------------------------------------------------------------------------------------------------------------------
.segment Intro

// A82C
// Here we initialize and configure the intro screen and then scroll through each intro state. Intro states run in
// the background on a raster interrupt. State changes are progressed by special commands in the music pattern data.
// A state is a related group of actions - such as scrolling the Freefall and Archon logos in to view or displaying
// the author list or animating the Archon logo bounce movement.
// The intro ends when the RUN/STOP, Q, F3, F5 or F7 key is pressed.
// RUN/STOP will jump to the board walk animation. F7 will start the game immediately with default options (two player,
// light first). F3 and F5 will toggle the approporiate selection and jump directly to the options page.
entry:
    jsr common.clear_sprites
    jsr private.import_sprites
    jsr common.initialize_music
    // Configure screen.
    lda SCROLX
    and #%1110_1111 // Multicolor bitmap mode off
    sta SCROLX
    lda #%0001_0000 // +$0000-$07FF char memory, +$0400-$07FF screen memory
    sta VMCSB
    // Configure sprites.
    lda #%0000_1111 // First 4 sprites multicolor; last 4 sprites single color
    sta SPMC
    lda #%1111_0000 // First 4 sprites single width; last 4 sprites double width
    sta XXPAND
    lda #%1111_1111 // Enable all sprites
    sta SPENA
    // Set interrupt handler.
    sei
    lda #<private.interrupt_handler
    sta main.ptr__raster_interrupt_fn
    lda #>private.interrupt_handler
    sta main.ptr__raster_interrupt_fn+1
    cli
    lda #$00
    sta idx__substate_fn_ptr // Initialize to first substate (draw Freefall logo)
    sta EXTCOL // Black border
    sta BGCOL0 // Black background
    // Set multicolor sprite color.
    lda private.data__logo_sprite_color_list
    sta SPMC0
    sta SPMC1
    // Configure the starting intro state routine.
    lda #<private.state__scroll_logos
    sta ptr__substate_fn
    lda #>private.state__scroll_logos
    sta ptr__substate_fn+1
    // Busy wait for break key. Interrupts will play the music and animations and progress through each into state
    // while we wait.
    // This routine will also jump directly to the game state on F7 and to the options selection state on F3, F5
    // or Q key.
    jsr common.wait_for_key_or_task_completion
    rts

//---------------------------------------------------------------------------------------------------------------------
// Private routines.
.namespace private {
    // AA42
    // Handle raster interrupt.
    // Keep playing music and continue animating the current introduction state until the
    // `flag__cancel_interrupt_state` is set.
    interrupt_handler:
        lda common.flag__cancel_interrupt_state
        bpl !next+
        jmp common.complete_interrupt
    !next:
        // The flag will be set to TRUE when the intro is over. This will then cause the interrupt handler to
        // stop playing into interrupts after the current interrupt is completed.
        lda common.flag__is_complete
        sta common.flag__cancel_interrupt_state
        jsr common.play_music
        // Run background task for the current intro state. eg move the Logo icon up by one pixel to scroll the logo
        // up the screen.
        jmp (ptr__substate_fn)

    // A98F
    // Imports the logos and chase scene icon sprites in to the graphics area.
    import_sprites:
        // Copy in icon frames for the chase scene.
        lda #FLAG_ENABLE
        sta common.param__is_copy_icon_sprites
        lda #BYTERS_PER_ICON_SPRITE
        sta common.param__sprite_source_len
        lda common.ptr__sprite_24_mem
        sta FREEZP+2
        sta ptr__sprite_mem_lo
        lda common.ptr__sprite_24_mem+1
        sta FREEZP+3
        //
        // Add 4 sprite frames for each chase icon. The chase icons are 2 sets of icons at that chase each other off
        // the screen at the end of the introduction.
        .const NUMBER_CHASE_ICONS = 4
        ldx #(NUMBER_CHASE_ICONS-1) // 0 offset
    !icon_loop:
        ldy data__icon_list,x // Get offset of icons that will be chasing each other
        sty common.param__icon_type_list
        lda board.data__piece_icon_offset_list,y
        sta common.param__icon_offset_list,x
        jsr common.initialize_sprite // Create a sprite for each icon
        lda flag__is_icon_sprite_mirrored_list,x // Invert frames for icons pointing left
        sta common.param__icon_sprite_curr_frame // Start frames have $80 added to horizontally mirror the sprite
        .const ICON_ANIMATION_FRAMES = 4 // 4 frames required to show icon movement in one direction
        lda #ICON_ANIMATION_FRAMES
        sta common.param__icon_sprite_source_frame_list
    !frame_loop:
        jsr common.add_sprite_to_graphics
        // Move to next sprite block in graphics memory.
        lda ptr__sprite_mem_lo
        clc
        adc #BYTES_PER_SPRITE
        sta FREEZP+2
        sta ptr__sprite_mem_lo
        bcc !next+
        inc FREEZP+3
    !next:
        // Add next frame.
        inc common.param__icon_sprite_curr_frame
        dec common.param__icon_sprite_source_frame_list
        bne !frame_loop-
        // Add remaining icons.
        dex
        bpl !icon_loop-
        //
        // Add Archon and Avatar logo sprites.
        lda common.ptr__sprite_00_mem
        sta FREEZP+2
        lda common.ptr__sprite_00_mem+1
        sta FREEZP+3
        lda #<resources.prt__sprites_logo
        sta FREEZP
        lda #>resources.prt__sprites_logo
        sta FREEZP+1
        ldy #$00 // Copy 7 sprites ($1C0 bytes - 4 for Archon logo, 3 for Freefall logo)
    !loop: // Copy first 256 bytes
        lda (FREEZP),y
        sta (FREEZP+2),y
        iny
        bne !loop-
        inc FREEZP+1
        inc FREEZP+3
    !loop: // Copy remaining bytes
        lda (FREEZP),y
        sta (FREEZP+2),y
        iny
        cpy #$C0
        bcc !loop-
        //
        // Configure each of the 7 sprites.
        .const NUM_SPRITES = 7
        lda #((VICGOFF/BYTES_PER_SPRITE)+NUM_SPRITES-1) // 0 offset
        sta idx__sprite_shape_block
        ldx #(NUM_SPRITES-1) // 0 offset
    !loop:
        txa
        asl
        tay
        // Set sprite pointer.
        lda idx__sprite_shape_block
        sta SPTMEM,x
        dec idx__sprite_shape_block
        // Configure sprite color.
        lda data__logo_sprite_color_list,x
        sta SP0COL,x
        // Configure sprite starting location.
        lda data__logo_sprite_start_x_pos_list,x
        sta SP0X,y
        sta board.data__sprite_curr_x_pos_list,x
        lda data__logo_sprite_start_y_pos_list,x
        sta SP0Y,y
        sta board.data__sprite_curr_y_pos_list,x
        dex
        bpl !loop-
        //
        // Set the final y-pos of logo sprites when they scroll in to position. Not sure why these are hard coded
        // when the starting positions weren't.
        lda #$45
        sta data__sprite_final_y_pos_list // Archon logo
        lda #$DA
        sta data__sprite_final_y_pos_list+1 // Freefal logo
        rts

    // AACF
    // Writes a text message to the board text area.
    // Requires:
    // - `param__string_idx`: text message offset (see `txt__string_list` for message order).
    // Notes:
    // - The string color will be read from the `data__string_color_list`.
    write_text:
        ldy param__string_idx
        // Set color.
        lda data__string_color_list,y
        sta param__curr_string_color
        // Set memory addres of start of string.
        tya
        asl
        tay
        lda txt__string_list,y
        sta FREEZP
        lda txt__string_list+1,y
        sta FREEZP+1
        // Derive the start row and column from the first 2-bytes in the string data and then display the string.
        ldy #$00
        jmp get_text_location

    // AB13
    // Derive the screen starting character offset and color memory offset and out put the text to that location.
    // Requires:
    // - FREEZP/FREEZP+1 - Pointer to string data. The string data starts with a column offset and ends with FF.
    // - `param__string_pos_ctl_flag`: Row control flag:
    //    $00 - the screen row and column will be read from the first byte and second byte in the string.
    //    $80 - the screen row is supplied using the X register and column is the first byte in the string.
    //    $C0 - the screen column is hard coded to #06 and the screen row is read X register.
    // Sets:
    // - FREEZP+2/FREEZP+3 - Pointer to screen character memory.
    // - FORPNT/FORPNT+1 - Pointer to screen color memory.
    // Notes:
    // - Calls `write_screen_chars` to output the characters after the screen location is determined.
    get_text_location:
        lda param__string_pos_ctl_flag
        bmi !x_has_row+ // Flag is >= $80
        // Read screen row from string data.
        lda (FREEZP),y
        inc FREEZP
        bne !next+
        inc FREEZP+1
    !next:
        tax
    !x_has_row:
        // Determine start screen and color memory addresses.
        lda #>SCNMEM // Screen memory high byte
        sta FREEZP+3 // Screen memory pointer
        clc
        adc common.data__color_mem_offset // Derive color memory address
        sta FORPNT+1 // Color memory pointer
        //
        bit param__string_pos_ctl_flag
        bvc !read_col+ // Flag is $C0 (required for Run/Stop message as this message does not contain row/column data)
        lda #$06 // Hard coded screen column offset
        bne !skip+
    !read_col:
        lda (FREEZP),y // Get column from string data
        inc FREEZP
        bne !skip+
        inc FREEZP+1
        //
    !skip:
    !loop:
        // Add 40 characters (1 row) to the column value for each row to obtain the starting screen location.
        clc
        adc #NUM_SCREEN_COLUMNS
        bcc !next+
        inc FREEZP+3
        inc FORPNT+1
    !next:
        dex
        bne !loop-
        sta FREEZP+2
        sta FORPNT
        //
        // Output the string.
        jmp write_screen_chars

    // AAEA
    // Write characters and color to the screen and color memory.
    // Requires:
    // - FREEZP/FREEZP+1: Pointer to string data containing the character data.
    // - FREEZP+2/FREEZP+3: Pointer to screen character memory.
    // - FORPNT/FORPNT+1: Pointer to screen color memory.
    // - `param__curr_string_color`: Color code used to set the character color.
    // Notes:
    // - Calls `get_text_location` to determine screen character and color memory on new line command.
    // - Strings are defined as follows:
    //  - A $80 byte in the string represents a 'next line'.
    //  - A screen row and column offset must follow a $80 command.
    //  - The string is terminated with a $ff byte.
    //  - Spaces are represented as $00.
    write_screen_chars:
        ldy #$00
    !loop:
        lda (FREEZP),y
        inc FREEZP
        bne !next+
        inc FREEZP+1
    !next:
        cmp #STRING_CMD_NEWLINE
        bcc !char_data+
        beq get_text_location // Get location of new line and output the string
        rts // Exit if STRING_CMD_END (ie >$80)
    !char_data:
        sta (FREEZP+2),y // Write character to screen
        lda (FORPNT),y
        and #%1111_0000 // Set foreground color (top nibble is background color, bottom nibble is foreground color)
        ora param__curr_string_color
        sta (FORPNT),y // Set character color
        // Next character.
        inc FORPNT
        inc FREEZP+2
        bne !loop-
        inc FREEZP+3
        inc FORPNT+1
        jmp !loop-

    //-----------------------------------------------------------------------------------------------------------------
    // Intro state logic.

    // AA56
    state__scroll_logos:
        .const NUMBER_LOGOS = 2
        ldx #(NUMBER_LOGOS-1) // "Archon" and "Freefall" (0 offset)
    !loop:
        lda board.data__sprite_curr_y_pos_list+3,x
        cmp data__sprite_final_y_pos_list,x
        beq !next+ // Stop moving if logo at final position
        bcs !scroll_up+
        // Scroll down Freefall.
        adc #$02 // Scroll down by 2 pixels
        sta board.data__sprite_curr_y_pos_list+3,x
        ldy #$04
    !move_loop:
        sta SP4Y,y // Move sprites 5 to 7
        dey
        dey
        bpl !move_loop-
        bmi !next+
        // Scroll up Archon.
    !scroll_up:
        sbc #$02 // Scroll up by 2 pixels
        ldy #$03
    !update_pos:
        sta board.data__sprite_curr_y_pos_list,y
        dey
        bpl !update_pos-
        ldy #$06
    !move_loop:
        sta SP0Y,y // Move sprites 1 to 4
        dey
        dey
        bpl !move_loop-
    !next:
        dex
        bpl !loop-
        jmp common.complete_interrupt

    // AA8B
    state__draw_freefall_logo:
        lda #FLAG_ENABLE
        sta param__string_pos_ctl_flag
        // Disable sprites 5 to 7 (Freefall logo). The sprite is replaced with text.
        ldx #$04
        lda #EMPTY_SPRITE_BLOCK
    !loop:
        sta SPTMEM,x
        inx
        cpx #$08
        bcc !loop-
        // Replace Freefall logo with text.
        // Here we start with the 8th string index which is the bottom of the freefall logo. We then decrease down
        // to 4. This displays Freefall logo with 3 repeated "ghost" halves above it.
        ldx #$16
        ldy #$08
        sty param__string_idx
    !loop:
        stx cnt__screen_row
        jsr write_text
        ldx cnt__screen_row
        dex
        dec param__string_idx
        ldy param__string_idx
        cpy #$04
        bcs !loop-
        // Re-enable the position flag and draw the last row of text.
        lda #FLAG_DISABLE
        sta param__string_pos_ctl_flag
        jsr write_text
        //
        // Set to pointer next string to display in next state.
        dec param__string_idx
        //
        // Start scrolling Avatar logo colors.
        lda #<state__avatar_color_scroll
        sta ptr__substate_fn
        lda #>state__avatar_color_scroll
        sta ptr__substate_fn+1
        jmp common.complete_interrupt

    // AB4F
    state__show_authors:
        jsr common.clear_screen
        // Display author names.
    !loop:
        jsr write_text
        dec param__string_idx
        bpl !loop-
        // Show press run/stop message.
        lda #$C0 // Manual row/column
        sta param__string_pos_ctl_flag
        lda #$09
        sta param__string_idx
        ldx #$18
        jsr write_text
        // Bounce the Avatar logo.
        lda #<state__avatar_bounce
        sta ptr__substate_fn
        lda #>state__avatar_bounce
        sta ptr__substate_fn+1
        // Initialize sprite registers used to bounce the logo in the next state.
        lda #$0E
        sta cnt__sprite_x_moves_remaining
        sta cnt__sprite_y_moves_remaining
        lda #FLAG_ENABLE_FF
        sta flag__is_sprite_direction_right
        jmp common.complete_interrupt

    // AB83
    // Bounce the Avatar logo in a sawtooth pattern within a defined rectangle on the screen.
    state__avatar_bounce:
        lda #$01 // Down
        ldy flag__is_sprite_direction_up
        bpl !next+
        lda #-($01) // Up
    !next:
        sta data__sprite_curr_y_pos
        //
        lda #$01 // Right
        ldy flag__is_sprite_direction_right
        bpl !next+
        lda #-($01) // Left
    !next:
        sta data__sprite_curr_x_pos
        // Move all 3 sprites that make up the Avatar logo.
        ldx #$03
        ldy #$06
    !loop:
        lda board.data__sprite_curr_y_pos_list,x
        // Add the direction pointer to the current sprite positions.
        // The direction pointer is 01 for right and FF (which is same as -1 as number overflows and wraps around) for
        // left direction.
        clc
        adc data__sprite_curr_y_pos
        sta board.data__sprite_curr_y_pos_list,x
        sta SP0Y,y
        lda board.data__sprite_curr_x_pos_list,x
        clc
        adc data__sprite_curr_x_pos
        sta board.data__sprite_curr_x_pos_list,x
        sta SP0X,y
        dey
        dey
        dex
        bpl !loop-
        // Reset the x and y position and reverse direction.
        dec cnt__sprite_y_moves_remaining
        bne !next+
        lda #$07
        sta cnt__sprite_y_moves_remaining
        lda flag__is_sprite_direction_up
        eor #$FF
        sta flag__is_sprite_direction_up
    !next:
        dec cnt__sprite_x_moves_remaining
        bne state__avatar_color_scroll
        lda #$1C
        sta cnt__sprite_x_moves_remaining
        lda flag__is_sprite_direction_right
        eor #$FF
        sta flag__is_sprite_direction_right
        // ...
    // ABE2
    // Scroll the colors on the Avatar logo.
    // Here we increase the colours ever 8 counts. The Avatar logo is a multi-colour sprite with the sprite split in to
    // even rows of alternating colors (col1, col2, col1, col2 etc). We set the first color (anded so it is between 1
    // and 16) and then we set the second color to first color + 1 (also anded so is between one and 16).
    state__avatar_color_scroll:
        inc cnt__sprite_delay
        lda cnt__sprite_delay
        and #$07
        bne !return+
        inc board.cnt__sprite_frame_list
        lda board.cnt__sprite_frame_list
        and #$0F
        sta SPMC0
        clc
        adc #$01
        and #$0F
        sta SPMC1 // C64 uses a global multi-color registers that are used for all sprites
        adc #$01
        and #$0F
        // The avatar logo comprises 3 sprites, so set all to the same color.
        ldy #$03
    !loop:
        sta SP0COL,y
        dey
        bpl !loop-
    !return:
        jmp common.complete_interrupt

    // AD83
    // Show 4 icons chasing each other off the screen.
    state__chase_scene:
        lda flag__are_sprites_initialized
        bpl !skip+ // Initialise sprites on first run only
        jmp animate_icons
    !skip:
        lda #BLACK
        sta SPMC0 // Set sprite multicolor (icon border) to black
        lda #FLAG_ENABLE
        sta flag__are_sprites_initialized
        // Configure sprite colors and initial positions.
        ldx #(NUMBER_CHASE_ICONS-1) // 0 offset
    !loop:
        // The Archon logo is comprised 4 sprites next to each other. Here we take the final Archon logo location (which
        // should be in the middle of the screen) for each of the 4 sprites and replace the sprites with icons. The
        // icons are double width, so we need to halve the X location used by the Archon sprites.
        lda board.data__sprite_curr_x_pos_list,x
        lsr
        sta board.data__sprite_curr_x_pos_list,x
        // Set icon colors.
        lda data__icon_sprite_color_list,x
        sta SP0COL,x
        dex
        bpl !loop-
        jmp animate_icons

    // ADC2
    // Animate icons by moving them across the screen and displaying animation frames.
    animate_icons:
        ldx #(NUMBER_CHASE_ICONS-1) // 0 offset
        // Animate on every other frame.
        lda cnt__sprite_delay
        eor #$FF
        sta cnt__sprite_delay
        bmi !return+
        //
        inc board.cnt__sprite_frame_list // Counter is used to set the animation frame
        //Move icon sprites.
    !loop:
        txa
        asl
        tay
        lda board.data__sprite_curr_x_pos_list,x
        cmp data__icon_sprite_final_x_pos_list,x
        beq !next+ // Current icon is at the final location
        clc
        adc data__icon_sprite_direction_addend,x // Left direction for first 2 icons, right for last 2
        sta board.data__sprite_curr_x_pos_list,x
        asl // Move by two pixels at a time
        sta SP0X,y
        // C64 requires 9 bits for sprite X position. Therefore sprite is set using sprite X position AND we may need to
        // set the nineth bit in MSIGX (offset bit by sprite number).
        bcc !clear_msb+
        lda MSIGX
        ora common.data__math_pow2_list,x
        sta MSIGX
        jmp !skip+
    !clear_msb:
        lda common.data__math_pow2_list,x
        eor #$FF
        and MSIGX
        sta MSIGX
        // Set the sprite pointer to point to one of four sprites used for each icon. A different frame is shown on
        // each movement.
    !skip:
        lda board.cnt__sprite_frame_list
        and #(ICON_ANIMATION_FRAMES-1) // 0 offset
        clc
        adc ptr__icon_sprite_mem_list,x
        sta SPTMEM,x
    !next:
        dex
        bpl !loop-
    !return:
        jmp common.complete_interrupt

    // AC0E
    // Complete the current game state and move on.
    state__end_intro:
        lda #FLAG_ENABLE
        sta common.flag__cancel_interrupt_state
        jmp common.complete_interrupt
        rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// AD73
// Pointers to intro state animation routines that are executed (one after the other) on an $FD command while playing
// music.
ptr__substate_fn_list:
    .word private.state__draw_freefall_logo, private.state__show_authors
    .word private.state__avatar_bounce, private.state__chase_scene
    .word private.state__end_intro

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // A8A5
    // Pointer to string data for each string.
    txt__string_list:
        .word resources.txt__intro_authors, resources.txt__intro_empty
        .word resources.txt__intro_ea, resources.txt__intro_a_game
        .word resources.txt__intro_freefall_top, resources.txt__intro_freefall_top
        .word resources.txt__intro_freefall_top, resources.txt__intro_freefall_top
        .word resources.txt__intro_freefall_bottom, resources.txt__game_option_press_run

    // A8B9
    // Color of each string.
    data__string_color_list:
        .byte YELLOW, LIGHT_BLUE, LIGHT_BLUE, WHITE
        .byte DARK_GRAY, GRAY, LIGHT_GRAY, WHITE
        .byte WHITE, ORANGE

    // A97A
    // Initial sprite y-position for intro logo sprites.
    data__logo_sprite_start_y_pos_list: .byte $ff, $ff, $ff, $ff, $30, $30, $30

    // A981
    // Initial sprite x-position for intro logo sprites.
    data__logo_sprite_start_x_pos_list: .byte $84, $9c, $b4, $cc, $6c, $9c, $cc

    // A988
    // Initial color of intro logo sprites.
    data__logo_sprite_color_list: .byte YELLOW, YELLOW, YELLOW, YELLOW, WHITE, WHITE, WHITE

    // ADAA:
    // Icon IDs of pieces used in chase scene.
    data__icon_list: .byte GOBLIN, GOLEM, TROLL, KNIGHT

    // ADAE:
    // Direction flags of intro sprites ($80=invert direction).
    flag__is_icon_sprite_mirrored_list: .byte FLAG_DISABLE, FLAG_DISABLE, FLAG_ENABLE, FLAG_ENABLE

    // ADB2
    // Direction of each icon sprite (FF=left, 01=right).
    data__icon_sprite_direction_addend: .byte -($01), -($01), $01, $01

    // ADB6
    // End position of each intro icon sprite.
    data__icon_sprite_final_x_pos_list: .byte $00, $00, $AC, $AC

    // ADBA
    // Screen pointer sprite offsets for each icon.
    ptr__icon_sprite_mem_list:
        .byte (VICGOFF/BYTES_PER_SPRITE)+24
        .byte (VICGOFF/BYTES_PER_SPRITE)+28
        .byte (VICGOFF/BYTES_PER_SPRITE)+32
        .byte (VICGOFF/BYTES_PER_SPRITE)+36

    // ADBE
    // Initial color of chase scene icon sprites.
    data__icon_sprite_color_list: .byte YELLOW, LIGHT_BLUE, YELLOW, LIGHT_BLUE
}

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC7
// Index for current introduction sub-state routine pointer.
idx__substate_fn_ptr: .byte $00

// BCD1
// Set to $80 to play intro and $00 to skip intro.
flag__is_enabed: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BD30
// Pointer to code for the current intro substate (eg bounce logo, chase icons, display text etc).
ptr__substate_fn: .word $0000

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BCE8
    // Delay between color changes when color scrolling avatar sprites or delay before moving sprite in chase scene.
    cnt__sprite_delay: .byte $00

    // BCE9
    // Number of moves left in y plane in current direction (will reverse direction on 0) when bouncing logo.
    cnt__sprite_y_moves_remaining: .byte $00

    // BCEA
    // Number of moves left in x plane in current direction (will reverse direction on 0) when bouncing logo.
    cnt__sprite_x_moves_remaining: .byte $00

    // BD0D
    // Is TRUE if the bouncing Archon sprite direction is currently moving right.
    flag__is_sprite_direction_right: .byte $00

    // BD15
    // Final set position of sprites after completion of animation.
    data__sprite_final_y_pos_list: .byte $00, $00

    // BD3A
    // Offset of current intro message being rendered.
    param__string_idx: .byte $00

    // BD59
    // Is TRUE if the bouncing Archon sprite direction is currently moving up.
    flag__is_sprite_direction_up: .byte $00

    // BF1A
    // Color of the current intro string being rendered.
    param__curr_string_color: .byte $00

    // BF1B
    // Current sprite block location index. Holds the value used to tell VIC-II which block within the graphic display
    // area holds the current sprite shape data.
    idx__sprite_shape_block: .byte $00

    // BF22
    // Is TRUE if intro icon sprites are initialized.
    flag__are_sprites_initialized: .byte $00

    // BF23
    // Current sprite Y position of bouncing Archon sprite.
    data__sprite_curr_y_pos: .byte $00

    // BF23
    // Low byte of current sprite memory location pointer. Used to increment to next sprite pointer location (by
    // adding 64 bytes) when adding chasing icon sprites.
    ptr__sprite_mem_lo: .byte $00

    // BF24
    // Current sprite X position of bouncing Archon sprite.
    data__sprite_curr_x_pos: .byte $00

    // BF30
    // Current screen line used while rendering repeated strings.
    cnt__screen_row: .byte $00

    // BF3C
    // Used to control string rendering ($00 = read row/column fro first bytes of string, $80 = row supplied in x, $C0 =
    // column is #06 and row supplied in x).
    param__string_pos_ctl_flag: .byte $00
}
