.filenamespace intro
//---------------------------------------------------------------------------------------------------------------------
// Play introduction/title sequence.
//---------------------------------------------------------------------------------------------------------------------
.segment Intro

// A82C
// Here we initialize and configure the intro screen and then scroll through each intro state. Intro states run in
// the backgroun on a raster interrupt. State changes are progressed by special commands in the music pattern data.
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
    lda #%0001_0000 // $0000-$07FF char memory, $0400-$07FF screen memory
    sta VMCSB
    // Configure sprites.
    lda #%0000_1111 // First 4 sprites multicolor; last 4 sprints single color
    sta SPMC
    lda #%1111_0000 // First 4 sprites double width; last 4 sprites single width
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
    sta idx__substate_fn_ptr // Initialize substate to first substate (draw Freefall logo)
    sta EXTCOL // Black border
    sta BGCOL0 // Black background
    // Set multicolor sprite default color.
    lda private.data__logo_sprite_color_list
    sta SPMC0
    sta SPMC1
    // Configure the starting intro state function.
    lda #<private.state__scroll_logos
    sta ptr__substate_fn
    lda #>private.state__scroll_logos
    sta ptr__substate_fn+1
    // Busy wait for break key. Interrupts will play the music and animations and progress through each into state
    // while we wait.
    // This function will also jump directly to the game state on F7 and to the options selection state on F3, F5
    // or Q key.
    jsr common.wait_for_key
    rts

//---------------------------------------------------------------------------------------------------------------------
// Private functions.
.namespace private {
    // AA42
    // Play current intro state interrupt.
    interrupt_handler:
        lda common.flag__enable_next_state
        bpl !next+
        jmp common.complete_interrupt
    !next:
        // The flag will be set to TRUE when the intro is over. This will then cause the interrupt handler to
        // stop playing into interrupts after the current interrupt is completed.
        lda flag__exit_intro
        sta common.flag__enable_next_state
        jsr common.play_music
        // Run background task for the current intro state. eg move the Logo icon up by one pixel to scroll the logo
        // up the screen.
        jmp (ptr__substate_fn)

    // A98F
    // Imports the logo and chase scene icon sprites in to the graphics area.
    import_sprites:
        // Copy in icon frames for chase scene.
        lda #FLAG_ENABLE
        sta common.param__is_copy_animation_group // Copy icon animation frames to animate movement in the chase scene
        lda #BYTERS_PER_STORED_SPRITE
        sta common.param__sprite_source_size
        lda common.ptr__sprite_24_mem
        sta FREEZP+2
        sta ptr__sprite_mem_lo
        lda common.ptr__sprite_24_mem+1
        sta FREEZP+3
        // Manually add 4 sprite froms for each icon.
        .const ICON_ANIMATION_FRAMES = 4 // 4 frames required to show icon movement in one direction
        ldx #(ICON_ANIMATION_FRAMES - 1) // 0 offset
    !icon_loop:
        ldy data__icon_id_list,x
        sty common.param__icon_type_list
        lda board.data__piece_icon_offset_list,y
        sta common.param__icon_offset_list,x
        jsr common.sprite_initialize
        lda flag__is_icon_sprite_mirrored_list,x // Invert frames for icons pointing left
        sta common.param__icon_sprite_curr_frame // Start frames have $80 added to horizontally mirror the sprite
        lda #ICON_ANIMATION_FRAMES
        sta common.param__icon_sprite_source_frame_list
    !frame_loop:
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
        bne !frame_loop-
        // Add remaining icons.
        dex
        bpl !icon_loop-
        // Add Archon and Avatar logo sprites.
        lda common.ptr__sprite_00_mem
        sta FREEZP+2
        lda common.ptr__sprite_00_mem+1
        sta FREEZP+3
        lda #<resources.prt__sprites_logo
        sta FREEZP
        lda #>resources.prt__sprites_logo
        sta FREEZP+1
        ldy #$00 // Copy 7 sprites ($1BF bytes - 4 for Archon logo, 3 for Freefall logo)
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
        // Configure each of the 7 sprites.
        .const NUM_SPRITES = 7
        lda #(VICGOFF/BYTES_PER_SPRITE)+(NUM_SPRITES-1)
        sta ptr__sprite_mem
        ldx #(NUM_SPRITES - 1) // 0 offset
    !loop:
        txa
        asl
        tay
        lda ptr__sprite_mem
        sta SPTMEM,x
        dec ptr__sprite_mem
        lda data__logo_sprite_color_list,x
        sta SP0COL,x
        lda pos__logo_sprite_x_list,x
        sta SP0X,y
        sta common.pos__sprite_x_list,x
        lda pos__logo_sprite_y_list,x
        sta SP0Y,y
        sta common.pos__sprite_y_list,x
        dex
        bpl !loop-
        // Final y-pos of Archon title sprites afters scroll from bottom of screen.
        lda #$45
        sta data__sprite_final_y_pos_list
        // Final y-pos of Freefall logo sprites afters scroll from top of screen.
        lda #$DA
        sta data__sprite_final_y_pos_list+1
        rts

    // AACF
    // Initiates the draw text routine by selecting a color and text offset. The routine then calls a method to write
    // the text to the screen.
    // Requires:
    // - `param__string_idx`: Contains the string ID offset to display
    // Notes:
    // - The message offset is used to read the string memory location from `ptr__txt__intro_list` (message offset is
    //   multiplied by 2 as 2 bytes are required to store the message location).
    // - The message offset is used to read the string color from `data__string_color_list`.
    screen_draw_text:
        ldy param__string_idx
        lda data__string_color_list,y
        sta data__curr_color
        tya
        asl
        tay
        lda ptr__txt__intro_list,y
        sta FREEZP
        lda ptr__txt__intro_list+1,y
        sta FREEZP+1
        ldy #$00
        jmp screen_calc_start_addr

    // AAEA
    // Write characters and colors to the screen.
    // Requires:
    // - FREEZP/FREEZP+1: Pointer to string data. The string data starts with a column offset and ends with $FF.
    // - FREEZP+2/FREEZP+3: Pointer to screen character memory.
    // - FORPNT/FORPNT+1: Pointer to screen color memory.
    // - `data__curr_color`: Color code used to set the character color.
    // Notes:
    // - Calls `screen_calc_start_addr` to determine screen character and color memory on new line command.
    // - Strings are defined as follows:
    //  - A $80 byte in the string represents a 'next line'.
    //  - A screen row and colum offset must follow a $80 command.
    //  - The string is terminated with a $ff byte.
    //  - Spaces are represented as $00.
    screen_write_chars:
        ldy #$00
    !loop:
        lda (FREEZP),y
        inc FREEZP
        bne !next+
        inc FREEZP+1
    !next:
        cmp #STRING_CMD_NEWLINE
        bcc !next+
        beq screen_calc_start_addr
        rts
    !next:
        sta (FREEZP+2),y // Write character to screen
        lda (FORPNT),y
        and #%1111_0000 // Set foreground color (top nibble is background color, bottom nibble is foreground color)
        ora data__curr_color
        sta (FORPNT),y // Set character color
        // Next character.
        inc FORPNT
        inc FREEZP+2
        bne !loop-
        inc FREEZP+3
        inc FORPNT+1
        jmp !loop-

    // AB13
    // Derive the screen starting character offset and color memory offset.
    // Requires:
    // - FREEZP/FREEZP+1 - Pointer to string data. The string data starts with a column offset and ends with FF.
    // - `param__string_pos_ctl_flag`: Row control flag:
    //    $00 - the screen row and column is read from the first byte and second byte in the string
    //    $80 - the screen row is supplied using the X register and column is the first byte in the string
    //    $C0 - the screen column is hard coded to #06 and the screen row is read X register
    // Sets:
    // - FREEZP+2/FREEZP+3 - Pointer to screen character memory.
    // - FORPNT/FORPNT+1 - Pointer to screen color memory.
    // Notes:
    // - Calls `screen_write_chars` to output the characters after the screen location is determined.
    screen_calc_start_addr:
        lda param__string_pos_ctl_flag
        bmi !skip+ // Flag is >= $80
        // Read screen row from string data.
        lda (FREEZP),y
        inc FREEZP
        bne !next+
        inc FREEZP+1
    !next:
        tax
    !skip:
        // Determine start screen and color memory addresses.
        lda #>SCNMEM // Screen memory hi byte
        sta FREEZP+3 // Screen memory pointer
        clc
        adc common.data__color_mem_offset // Derive color memory address
        sta FORPNT+1 // Color memory pointer
        bit param__string_pos_ctl_flag
        bvc !next+ // Flag is $C0 (required for Run/Stop message as this message does not contain row/column data)
        lda #$06 // Hard coded screen column offset
        bne !skip+
    !next:
        lda (FREEZP),y // Get column from string data
        inc FREEZP
        bne !skip+
        inc FREEZP+1
    !skip:
    !loop:
        // Add 40 characters (1 row) to the column value for each row to obtain the starting screen location.
        clc
        adc #CHARS_PER_SCREEN_ROW
        bcc !next+
        inc FREEZP+3
        inc FORPNT+1
    !next:
        dex
        bne !loop-
        sta FREEZP+2
        sta FORPNT
        jmp screen_write_chars

    //-----------------------------------------------------------------------------------------------------------------
    // Intro state logic.

    // AA56
    state__scroll_logos:
        ldx #$01 // process two sprites groups ("Archon" comprises 4 sprites and "Freefall" comprises 3)
    !loop:
        lda common.pos__sprite_y_list+3,x
        cmp data__sprite_final_y_pos_list,x
        beq !next+ // Stop moving if at final position
        bcs !scroll_up+
        // Scroll down Freefall.
        adc #$02 // Scroll down by 2 pixels
        sta common.pos__sprite_y_list+3,x
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
        sta common.pos__sprite_y_list,y
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
        // Disable sprites 5 to 7 (Freefall logo).
        ldx #$04
        lda #%0000_1111
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
        stx data__curr_line
        jsr screen_draw_text
        ldx data__curr_line
        dex
        dec param__string_idx
        ldy param__string_idx
        cpy #$04
        bcs !loop-
        // Re-enable the position flag and draw the last row of text.
        lda #FLAG_DISABLE
        sta param__string_pos_ctl_flag
        jsr screen_draw_text
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
        jsr screen_draw_text
        dec param__string_idx
        bpl !loop-
        // Show press run/stop message.
        lda #$C0 // Manual row/column
        sta param__string_pos_ctl_flag
        lda #$09
        sta param__string_idx
        ldx #$18
        jsr screen_draw_text
        // Bounce the Avatar logo.
        lda #<state__avatar_bounce
        sta ptr__substate_fn
        lda #>state__avatar_bounce
        sta ptr__substate_fn+1
        // Initialize sprite registers used to bounce the logo in the next state.
        lda #$0E
        sta cnt__sprite_x_moves_left
        sta cnt__sprite_y_moves_left
        lda #$FF
        sta flag__sprite_x_direction
        jmp common.complete_interrupt

    // AB83
    // Bounce the Avatar logo in a sawtooth pattern within a defined rectangle on the screen.
    state__avatar_bounce:
        lda #$01 // +1 (down)
        ldy flag__sprite_y_direction
        bpl !next+
        lda #$FF // -1 (up)
    !next:
        sta pos__curr_sprite_y
        //
        lda #$01 // +1 (right)
        ldy flag__sprite_x_direction
        bpl !next+
        lda #$FF // -1 (left)
    !next:
        sta pos__curr_sprite_x
        // Move all 3 sprites that make up the Avatar logo.
        ldx #$03
        ldy #$06
    !loop:
        lda common.pos__sprite_y_list,x
        // Add the direction pointer to the current sprite positions.
        // The direction pointer is 01 for right and FF (which is same as -1 as number overflows and wraps around) for left direction.
        clc
        adc pos__curr_sprite_y
        sta common.pos__sprite_y_list,x
        sta SP0Y,y
        lda common.pos__sprite_x_list,x
        clc
        adc pos__curr_sprite_x
        sta common.pos__sprite_x_list,x
        sta SP0X,y
        dey
        dey
        dex
        bpl !loop-
        // Reset the x and y position and reverse direction.
        dec cnt__sprite_y_moves_left
        bne !next+
        lda #$07
        sta cnt__sprite_y_moves_left
        lda flag__sprite_y_direction
        eor #$FF
        sta flag__sprite_y_direction
    !next:
        dec cnt__sprite_x_moves_left
        bne state__avatar_color_scroll
        lda #$1C
        sta cnt__sprite_x_moves_left
        lda flag__sprite_x_direction
        eor #$FF
        sta flag__sprite_x_direction

    // ABE2
    // Scroll the colors on the Avatar logo.
    // Here we increase the colours ever 8 counts. The Avatar logo is a multi-colour sprite with the sprite split in to
    // even rows of alternating colors (col1, col2, col1, col2 etc). Here we set the first color (anded so it is between
    // 1 and 16) and then we set the second color to first color + 1 (also anded so is between one and 16).
    state__avatar_color_scroll:
        inc private.cnt__curr_sprite_delay
        lda private.cnt__curr_sprite_delay
        and #$07
        bne !return+
        inc common.cnt__curr_sprite_frame
        lda common.cnt__curr_sprite_frame
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
        sta flag__are_sprites_initialized // Set sprites intiialised flag
        // Confifure sprite colors and positions
        ldx #$03
    !loop:
        lda common.pos__sprite_x_list,x
        lsr
        sta common.pos__sprite_x_list,x
        lda data__icon_sprite_color_list,x
        sta SP0COL,x
        dex
        bpl !loop-
        jmp animate_icons

    // ADC2
    // Animate icons by moving them across the screen and displaying animation frames.
    animate_icons:
        ldx #$03
        // Animate on every other frame.
        // The code below just toggles a flag back and forth between the minus state.
        lda private.cnt__curr_sprite_delay
        eor #$FF
        sta private.cnt__curr_sprite_delay
        bmi !return+
        inc common.cnt__curr_sprite_frame // Counter is used to set the animation frame
        //Move icon sprites.
    !loop:
        txa
        asl
        tay
        lda common.pos__sprite_x_list,x
        cmp pos__icon_sprite_final_x_list,x
        beq !next+
        clc
        adc flag__icon_sprite_direction_list,x
        sta common.pos__sprite_x_list,x
        asl // Move by two pixels at a time
        sta SP0X,y
        // C64 requires 9 bits for sprite X position. Therefore sprite is set using sprite X position AND we may need to
        // set the nineth bit in MSIGX (offset bit by spreit enumber).
        bcc !clear_msb+
        lda MSIGX
        ora common.data__math_pow2,x
        sta MSIGX
        jmp !skip+
    !clear_msb:
        lda common.data__math_pow2,x
        eor #$FF
        and MSIGX
        sta MSIGX
        // Set the sprite pointer to point to one of four sprites used for each icon. A different frame is shown on
        // each movement.
    !skip:
        lda common.cnt__curr_sprite_frame
        and #$03 // 1-4 animation frames
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
        sta common.flag__enable_next_state
        jmp common.complete_interrupt
        rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// AD73
// Pointers to intro state animation functions that are executed (one after the other) on an $FD command while playing
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
    ptr__txt__intro_list:
        .word resources.txt__intro_0, resources.txt__intro_1, resources.txt__intro_2, resources.txt__intro_3
        .word resources.txt__intro_4, resources.txt__intro_4, resources.txt__intro_4, resources.txt__intro_4
        .word resources.txt__intro_5, resources.txt__game_67

    // A8B9
    // Color of each string.
    data__string_color_list:
        .byte YELLOW, LIGHT_BLUE, LIGHT_BLUE, WHITE
        .byte DARK_GRAY, GRAY, LIGHT_GRAY, WHITE
        .byte WHITE, ORANGE

    // A97A
    // Initial sprite y-position for intro logo sprites.
    pos__logo_sprite_y_list: .byte $ff, $ff, $ff, $ff, $30, $30, $30

    // A981
    // Initial sprite x-position for intro logo sprites.
    pos__logo_sprite_x_list: .byte $84, $9c, $b4, $cc, $6c, $9c, $cc

    // A988
    // Initial color of intro logo sprites.
    data__logo_sprite_color_list: .byte YELLOW, YELLOW, YELLOW, YELLOW, WHITE, WHITE, WHITE

    // ADAA:
    // Icon IDs of pieces used in chase scene.
    data__icon_id_list: .byte GOBLIN, GOLEM, TROLL, KNIGHT

    // ADAE:
    // Direction flags of intro sprites ($80=invert direction).
    flag__is_icon_sprite_mirrored_list: .byte FLAG_DISABLE, FLAG_DISABLE, FLAG_ENABLE, FLAG_ENABLE

    // ADB2
    // Direction of each icon sprite (FF=left, 01=right).
    flag__icon_sprite_direction_list: .byte $FF, $FF, $01, $01

    // ADB6
    // End position of each intro icon sprite.
    pos__icon_sprite_final_x_list: .byte $00, $00, $AC, $AC

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
// Index for current introduction sub-state function pointer.
idx__substate_fn_ptr: .byte $00

// BCD1
// Set to $80 to play intro and $00 to skip intro.
flag__enable: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCD3
// Is set to non zero to stop the current intro and advance the game state to the options screen.
flag__exit_intro: .byte $00

// BD30
// Pointer to code for the current intro substate (eg bounce logo, chase icons, display text etc).
ptr__substate_fn: .word $0000

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BCE8
    // Delay between color changes when color scrolling avatar sprites.
    cnt__curr_sprite_delay: .byte $00

    // BCE9
    // Number of moves left in y plane in current direction (will reverse direction on 0).
    cnt__sprite_y_moves_left: .byte $00

    // BCEA
    // Number of moves left in x plane in current direction (will reverse direction on 0).
    cnt__sprite_x_moves_left: .byte $00
    
    // BD0D
    // Is positive number for right direction, negative for left direction.
    flag__sprite_x_direction: .byte $00

    // BD15
    // Final set position of sprites after completion of animation.
    data__sprite_final_y_pos_list: .byte $00, $00

    // BD3A
    // Offset of current intro message being rendered.
    param__string_idx: .byte $00

    // BD59
    // Is positive number for down direction, negative for up direction.
    flag__sprite_y_direction: .byte $00

    // BF1A
    // Color of the current intro string being rendered.
    data__curr_color: .byte $00

    // BF1B
    // Current sprite location pointer.
    ptr__sprite_mem: .byte $00

    // BF22
    // Is TRUE if intro icon sprites are initialized.
    flag__are_sprites_initialized: .byte $00

    // BF23
    // Current sprite Y position of bouncing Archon sprite.
    pos__curr_sprite_y: .byte $00

    // BF23
    // Low byte of current sprite memory location pointer. Used to increment to next sprite pointer location (by adding 64
    // bytes) when adding chasing icon sprites.
    ptr__sprite_mem_lo: .byte $00

    // BF24
    // Current sprite X position of bouncing Archon sprite.
    pos__curr_sprite_x: .byte $00

    // BF30
    // Current screen line used while rendering repeated strings.
    data__curr_line: .byte $00

    // BF3C
    // Used to control string rendering ($00 = read row/column fro first bytes of string, $80 = row supplied in x, $C0 =
    // column is #06 and row supplied in x).
    param__string_pos_ctl_flag: .byte $00
}
