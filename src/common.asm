.filenamespace common
//---------------------------------------------------------------------------------------------------------------------
// Library of code and assets used by the intro, board and battle arean states.
//---------------------------------------------------------------------------------------------------------------------
.segment Common

// 638E
// Restore registers pushed on to the stack at the start of an interrupt and complete the current interrupt.
// This routine is called at the completion of each raster interrupt.
// Requires:
// - A, X and Y: pushed on to the stack (Y first, then X then A)
// Sets:
// - A, X and Y: retrieved from the stack
complete_interrupt:
    pla
    tay
    pla
    tax
    pla
    rti

// 6394
// Sets game options if an option function key is pressed.
// Key are as follows:
// - F3: Cycle AI state (none, AI is light, AI is dark)
// - F5: Light first/Dark First
// - F7: Start game
// Sets:
// - `game.data__ai_player_ctl`: Is positive (55) for AI light, negative (AA) for AI dark, (00) for neither, (FF) or
//    both.
// - `game.data__curr_player_color`: Is positive (55) for light, negative (AA) for dark.
// - `flag__game_loop_state`: Set to 00 to indicate a game start.
// Notes:
// - Calls `reset_options_state` after each option selection. This waits for the key to be released (so options don't
//   advance multiple times by accident) and resets the countdown timer before playing an AI vs AI game if no options
//   selected in a given period.
// - Calls `main.game_state_loop` after each option selection to redraw board with current settings or play the game if
//   `flag__game_loop_state` is disabled.
check_option_keypress:
    lda LSTX
    cmp #KEY_NONE
    bne !check_f7+
    rts
!check_f7:
    cmp #KEY_F7
    bne !check_f5+
    // Start game.
    jsr private.reset_options_state
    lda #FLAG_DISABLE
    sta board.cnt__countdown_timer
    sta flag__game_loop_state
    lda flag__ai_player_selection
    sta game.data__ai_player_ctl
    jmp main.game_state_loop
!check_f5:
    cmp #KEY_F5
    bne !check_f3+
    // Toggle first player.
    lda game.data__curr_player_color
    eor #$FF
    sta game.data__curr_player_color
    jsr private.reset_options_state
    jmp main.game_state_loop
!check_f3:
    cmp #KEY_F3
    beq !skip+
    rts
    // Toggle AI between two players, player light, player dark.
!skip:
    // Cylce from 0 to 3 on each F3 keypress and repeat.
    lda cnt__ai_selection
    clc
    adc #$01
    cmp #$03
    bcc !next+
    lda #$00
!next:
    sta cnt__ai_selection
    cmp #$00
    beq !next+
    // This just gets a flag that is 55 for light, AA for dark and 0 for no AI. The flag has two purposes: we can
    // use beq, bpl, bmi to test the tri-state and also 55 and AA are used to set the color used by the board border
    // to represent the current player.
    lda game.data__curr_player_color
    cmp flag__ai_player_selection
    bne !next+
    eor #$FF
!next:
    sta game.data__ai_player_ctl
    sta flag__ai_player_selection
    jsr private.reset_options_state
    jmp main.game_state_loop

// 644D
// Determine sprite shape data souorce address for a given icon, set the sprite color and direction and enable the
// sprite.
// Requires:
// - X: Sprite number (0 - 3). This routine can be used to initialize up to 4 sprites:
//   - A single sprite is only needed when moving pieces on the board.
//   - 4 sprites a needed within the battle arena (icon and weapon/projectile for each player).
//   - 4 sprites are used during the introduction chase animation.
// - `param__icon_offset_list,x`: contains the sprite group pointer offset (see `ptr__icon_sprite_mem_offset_list` for
//    details) for the selected sprite number.
// - `param__icon_type_list,x`: contains the sprite icon type for the selected sprite number.
// Sets:
// - `ptr__sprite_source_lo_list`: Low pointer of the sprite shape data memory address.
// - `ptr__sprite_source_hi_list`: High pointer of the sprite shape data memory address.
// - `param__icon_sprite_source_frame_list,x`: Set to #$00 for right facing icons and #$11 for left facing for the
//   selected sprite number.
// - Sprite,x is enabled and the color is configured.
initialize_sprite:
    lda param__icon_offset_list,x
    // Get pointer to sprite shape data for the given icon offset.
    asl
    tay
    lda private.ptr__icon_sprite_mem_offset_list,y
    sta ptr__sprite_source_lo_list,x
    lda private.ptr__icon_sprite_mem_offset_list+1,y
    sta ptr__sprite_source_hi_list,x
    // Set special color for elementals, otherwise set the color based on the player (yellow for light, blue for dark).
    lda param__icon_type_list,x
    cmp #AIR_ELEMENTAL // Is sprite an elemental (air elemental is the first elemental type)?
    bcc !set_player_color+
    and #$03 // Convert the elemental to a number from 0 to 3.
    tay
    lda private.data__elemental_icon_color_list,y
    bpl !enable_sprite+
!set_player_color:
    ldy #$00 // Set Y to 0 for light icon, 1 for dark icon
    cmp #MANTICORE // Dark icon (manticore is the first dark icon)
    bcc !next+
    iny
!next:
    lda data__player_icon_color_list,y
    //
!enable_sprite:
    sta SP0COL,x // Set sprite color
    lda data__math_pow2_list,x
    ora SPENA
    sta SPENA // Enable sprite
    // Set initial icon direction. Icon with bit 4 set are all dark player icons. Not sure why we'd use this method
    // here and >= MANTICORE method above, but so be it. This won't work for elementals. Special logic will be needed
    // later to determine the direction of the elemental based upon the current player.
    lda param__icon_offset_list,x
    and #%0000_1000
    beq !next+
    lda #LEFT_FACING_ICON_FRAME
!next:
    sta param__icon_sprite_source_frame_list,x
    rts

// 6490
// Create a time delay by waiting for a specified number of jiffies. A jiffy is approximately 1/60th of a second.
// The time delay can be cancelled by pressing 'Q' however this will restart the game.
// Requires:
// - X: number of jiffies (~0.01667s per jiffy) to wait.
wait_for_jiffy:
    lda TIME+2
!loop:
    cmp TIME+2
    beq !loop-
    jsr check_stop_keypess
    dex
    bne wait_for_jiffy
    rts

// 677C
// Detect if RUN/STOP or Q key is pressed.
// Sets:
// - `flag__is_complete` is toggled if RUN/STOP pressed. This will force the intro to exit and the options
//   screen to display.
// Notes:
// - Game is reset if Q key is pressed.
// - Subroutine waits for key to be released before exiting.
check_stop_keypess:
    // Get state of RUN/STOP. Note this retuns the top line status in A, so we can read if other keys were pressed
    // also (as long as it was on the top line).
    jsr STOP
    beq !run_stop_pressed+
    cmp #KEY_Q
    bne !return+
    // Q Pressed.
!loop:
    // Wait for key to be released.
    jsr STOP
    cmp #KEY_Q
    beq !loop-
    // Restart the game at the options screen.
    jsr private.reset_options_state
    jmp main.game_state_loop
    //
!run_stop_pressed:
    // Toggle introduction complete flag.
    lda flag__is_complete
    eor #$FF
    sta flag__is_complete
    // Wait for key to be released.
!loop:
    jsr STOP
    beq !loop-
!return:
    rts

// 7FAB
// Stop sound from playing on the first 2 voices.
stop_sound:
    ldx #$01 // Voice counter (0 offset)
!loop:
    // Configure loop source address to start of the parameters for the current voice.
    txa
    asl
    tay
    lda ptr__voice_ctl_addr_list,y
    sta FREEZP+2
    lda ptr__voice_ctl_addr_list+1,y
    sta FREEZP+3
    // Clear all voice paramaters.
    ldy #$04 // Voice control register offset
    lda #$00
    sta (FREEZP+2),y // Clear voice control register
    sta flag__is_player_sound_enabled,x // Disable voice for each player (light player voice 1, dark player voice 2)
    sta data__voice_note_delay,x // Reset delay counter
    // Next voice.
    dex
    bpl !loop-
    rts

// 8BDE
// Adds a set of sprites for an icon to the graphics memory. A sprite set may contain all the sprites for animations
// in different directions and the weapons or projectiles thrown by the sprite. The set may also include the icon
// firing animations.
// Requires:
// - X Register:
//   - 0: to copy light player icon frames
//   - 1: to copy dark player icon frames
//   - 2: to copy light player weapon/projectile frames
//   - 3: to copy dark player weapon/projectile frames
// Notes:
// - Icon frames add 24 sprites as follows:
//   - 4 x East facing icons (4 animation frames)
//   - 4 x South facing icons (4 animation frames)
//   - 4 x North facing icons (4 animation frames)
//   - 5 x Attack frames (north, north east, east, south east, south facing)
//   - 4 x West facing icon frames (mirrored representation of east facing icons)
//   - 3 x West facing attack frames (mirrored east facing icons - north west, west, south west)
// - Weapon/Projectile frames are frames used to animate the players weapon or projectile (eg bolt, club or scream).
//   There are 7 sprites as follows:
//   - 1 x East direction weapon/projectile
//   - 1 x North/south direction weapon/projectile (same sprite is used for both directions)
//   - 1 x North east direction weapon/projectile
//   - 1 x South east direction weapon/projectile
//   - 1 x West direction weapon/projectile (mirrored copy of east)
//   - 1 x North west direction weapon/projectile (mirrored copy of north east)
//   - 1 x South west direction weapon/projectile (mirrored copy of south east)
//   - Special player pieces Phoneix and Banshee only copy 4 'transformation' sprites (east, south, north, west). A
//     transformation sprite is a full width/height sprite projected over the top of the icon (eg a fireball for the
//     Phoenix or a surrounding scream field for the Banshee).
// - Mirrored sprite sources are not represented in memory. Instead the sprite uses the original version and logic is
//   used to create a mirrored copy.
add_sprite_set_to_graphics:
    // Set starting sprite location. Is 0, 24, 48 or 56 depending on value of x. This allows icon and weapon/projectile
    // sets to be individually loaded for each player without overwriting previously loaded sprites.
    txa
    asl
    tay
    lda ptr__sprite_mem_list,y
    sta FREEZP+2
    sta private.ptr__sprite_mem_lo
    lda ptr__sprite_mem_list+1,y
    sta FREEZP+3
    //
    cpx #$02
    bcc !add_icons+
    //
    // Weapon/projectile frames.
    // Detect if transormation are being added for Banshee or Phoenix. These are special pieces which use a full
    // height 'projectile' that is displayed over the top of the icon itself. ie the Banshee scream or Phoenix fire.
    txa
    and #$01
    tay
    lda param__icon_offset_list,y
    and #%0000_0111
    cmp #%0000_0110 // The Banshee and Phoenix icon offsets are the only icons with bits 2 and 3 set and bit 0 unset
    bne !add_weapon+
    // Add special full height transformation frames for Banshee and Phoneix icons.
    lda #$00
    sta param__icon_sprite_curr_frame
    jmp add_sprite_to_graphics
!add_weapon:
    // Copies weapon/projectile frames: $11, $12, $13, $14, $11+$80, $13+$80, $14+$80 (80 inverts frame).
    lda #$11
    sta param__icon_sprite_curr_frame
    bne !frame_loop+
    //
    // Icon frames.
!add_icons:
    // Copies icon frames: $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$10,$00+$80,$01+$80,
    // $02+$80, $03+$83,$0d+$80,$0e+$80,$0f+$80 (80 inverts frame).
    lda #$00
    sta param__icon_sprite_curr_frame
    //
    // The following loop has special logic and conditions to create sprites for specific frames. The frames will
    // be incremented or skipped depending upon whether the sprite set is for weapon/projectiles or icons. See the
    // comments above for details of which icons are copied.
    // Note that frames for mirrored directions will use the source frame + $80 to indicate the frame should be
    // horizontally mirrored when created.
!frame_loop:
    jsr add_sprite_to_graphics
    // The logic below just skips sets inverts frames based on hard coded rules to determine the next frame to add to
    // the sprite graphics area. The game and animation logic will switch the active sprite pointer between the frames
    // depending on movement direction and animation state.
    inc param__icon_sprite_curr_frame
    cpx #$02
    bcs !check_weapon+
    lda param__icon_sprite_curr_frame
    bmi !check_inverted_icon+
    cmp #$11
    bcc !next_block+
    lda #$80 // Jump from frame 10 to 80 (skip 11 to 7F)
    sta param__icon_sprite_curr_frame
    bmi !next_block+
!check_inverted_icon:
    cmp #$84
    bcc !next_block+
    beq !skip+ // Skip frames 84 to 8C
    cmp #$90
    bcc !next_block+
    rts // End after copying frame 8F
!check_weapon:
    lda param__icon_sprite_curr_frame
    bmi !check_inverted_weapon+
    cmp #$15
    bcc !next_block+
    lda #$91 // Jump from frame 14 to 91 (skip 15 to 90)
    sta param__icon_sprite_curr_frame
    bmi !next_block+
!check_inverted_weapon:
    cmp #$95
    bcc !next+
    rts // End after copying frame 94
!next:
    cmp #$92
    bne !next_block+
    inc param__icon_sprite_curr_frame // Skip frame 92
    jmp !next_block+
!skip:
    lda #$8D
    sta param__icon_sprite_curr_frame
    //
!next_block:
    // Incremement graphics pointer to point to next sprite memory location ready for storing the next frame.
    lda private.ptr__sprite_mem_lo
    clc
    adc #BYTES_PER_SPRITE
    sta private.ptr__sprite_mem_lo
    sta FREEZP+2
    bcc !frame_loop-
    inc FREEZP+3
    bcs !frame_loop-

// 8C6D
// Copies a sprite frame in to graphics memory.
// So super quick introduction here for sprites. The C64 allows up to 8 sprites to be displayed on the screen at a time.
// The sprites use shape data stored in the graphics memory visible to the VIC-II. See `GRPMEM` in io.asm. 8 single
// byte pointers in the last 8 bytes of screen memory are used to point to a block within the graphical memory. This
// block contains the shape data for that specific sprite. A block is a 64 byte contiguous block of memory starting
// at the graphics memory start address. Since we can access up to FF blocks per sprite pointer, we can therefore
// have up to FF blocks of sprite shape data per sprite. This is however limited by memory in real life.
// Anyway, so the way C64 works is we load a bunch of shape data in to graphics memory (eg sevral sprite shapes for
// different animation frames in each movement direction) and we can swap what is drawn on the screen by updating
// the sprite pointer.
// Requires:
// - `FREEZP+2,+3`: Contains the low byte and high byte of the graphic memory address to copy the frame too.
// - `param__icon_sprite_curr_frame`: Frame to copy in to graphic memory. Will be +$80 to mirror the frame.
// - `param__is_copy_icon_sprites`: Set TRUE to copy icon sprite shape data. Set FALSE to read the type of sprite from
//   the X register (see below).
// - X Register (only used if `param__is_copy_icon_sprites` is not set):
//   - 0 or 1: to copy an icon sprite
//   - 2: to copy all light player weapon/projectile frames (7 frames)
//   - 3: to copy all dark player weapon/projectile frames (7 frames)
// - `param__sprite_source_len`: Number of bytes to copy for each sprite/sprite group. Will be overwritten if copying
//   weapon/projectile frames for Banshee or Phoenix as this are special cases (see comments below).
// Notes:
// - The logic includes functionality to add a mirrored sprite to graphics memory.
add_sprite_to_graphics:
    lda param__icon_sprite_curr_frame
    and #$7F // The offset has #$80 if the sprite frame should be inverted on copy
    //
    // Get frame source memory address.
    // This is done by first reading the sprite source offset of the icon set and then adding the frame offset.
    asl
    tay
    lda private.data__icon_sprite_frame_mem_offset_list,y
    clc
    adc ptr__sprite_source_lo_list,x
    sta FREEZP
    lda ptr__sprite_source_hi_list,x
    adc private.data__icon_sprite_frame_mem_offset_list+1,y
    sta FREEZP+1
    //
    lda param__is_copy_icon_sprites
    bmi !copy_icon+
    cpx #$02 // 0=light icon frames, 1=dark icon frames, 2=light weapon/projectiles, 3=dark weapon/projectiles
    bcc !copy_icon+
    //
    // Copy sprites used for weapon/projectiles (eg bullets, clubs, sords, screams, fire etc).
    txa
    and #$01
    tay // Convert X=02 to Y=00 or X=03 to Y=01
    // Check if piece is Banshee or Phoenix. Thiese pieces have special non-directional attacks.
    lda param__icon_offset_list,y
    and #%0000_0111
    cmp #%0000_0110 // The Banshee and Phoenix icon offsets are the only icons with bits 2 and 3 set and bit 0 unset
    bne !copy_weapon+
    // Banshee and Phoenix only have 4 weapon frames (e,s,n,w), the frames are full width and height sprites (ie 64
    // bytes in size instead of 54 bytes for smaller sprites) so is 64*4 = 256 bytes to copy
    lda #(BYTES_PER_SPRITE*4-1) // 0 offset
    sta param__sprite_source_len
    jmp !copy_icon+
!copy_weapon:
    ldy #$00
!loop:
    lda param__icon_sprite_curr_frame
    bpl !not_mirrored+ // +$80 to invert weapon/projectile frame
    // Mirror 8 bits. eg 10001110 becomes 01110001. 01111000 becomes 00011110 etc.
    // This is achieved by rolling the original value 8 times. Each time we first roll right which shifts the first
    // bit in to the carry flag and shifts the ramining bits to the right by one position. We then roll the accumulator
    // left. This moves all the bits in the accumular left and the adds the carry flag value to the right most bit.
    // This loop is used to horizontally invert a single color sprite.
    lda #$08
    sta private.data__temp_storage
    lda (FREEZP),y
    sta private.data__temp_storage+1
!mirror_bit_loop:
    ror private.data__temp_storage+1
    rol
    dec private.data__temp_storage
    bne !mirror_bit_loop-
    beq !next+
!not_mirrored:
    lda (FREEZP),y
!next:
    sta (FREEZP+2),y
    inc FREEZP+2
    inc FREEZP+2
    iny
    cpy param__sprite_source_len
    bcc !loop-
    rts
    //
    // Copy sprites used for icons.
!copy_icon:
    ldy #$00
    lda param__icon_sprite_curr_frame
    bmi !mirrored_copy+ // +$80 to horizontally mirror the icon
    // Copy the icon byte for byte.
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    cpy param__sprite_source_len
    bcc !loop-
    rts
    // Mirror a multicolor sprite - used for when sprite is moving in the opposite direction.
!mirrored_copy:
    lda #$0A
    sta private.data__temp_storage
    // Sprites are 24x21 bits in size with 2 bits used for each color pair. Each sprite row is therefore represented by
    // 3 bytes. To mirror the sprite, we need to shift each 2 byte pair 12 times with the bits rotated out of each byte
    // added to the next byte in the 3 byte pair. We need to repeat this then for each row.
    tya
    clc
    adc #$02
    tay
    lda (FREEZP),y
    sta private.data__temp_storage+3
    dey
    lda (FREEZP),y
    sta private.data__temp_storage+2
    dey
    lda (FREEZP),y
    sta private.data__temp_storage+1
    lda #$00
    sta private.data__temp_storage+4
    sta private.data__temp_storage+5
!loop:
    // swap the last two bits of the 3 bytes
    jsr private.mirror_bits
    jsr private.mirror_bits
    // The logic below inverts the 2-bit pair rotated to the start of the first byte back so we don't invert the colors
    pha
    and #%1100_0000
    beq !next+
    cmp #%1100_0000
    beq !next+
    pla
    eor #%1100_0000
    jmp !next++
!next:
    pla
!next:
    dec private.data__temp_storage
    bne !loop-
    // Store the rotated bytes and repeat for the remaning rows.
    sta (FREEZP+2),y
    iny
    lda private.data__temp_storage+4
    sta (FREEZP+2),y
    iny
    lda private.data__temp_storage+5
    sta (FREEZP+2),y
    iny
    cpy param__sprite_source_len
    bcc !mirrored_copy-
    rts

// 8DD3
// Clear the video graphics area and reset sprite positions for first 4 sprites.
clear_sprites:
    lda #<GRPMEM
    sta FREEZP+2
    lda #>GRPMEM
    sta FREEZP+3
    ldx #$10 // 16x256 = 4096kb
    lda #$00
    tay
!loop:
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+3
    dex
    bne !loop-
    //
    // reset sprite positions
    ldx #$07
    sta MSIGX
!loop:
    sta SP0X,x
    dex
    bpl !loop-
    rts

// 905C
// Busy wait for STOP, game options (function keys), Q keypress or game state change.
// Notes:
// - Repeats until `flag__cancel_interrupt_state` is set.
// - Resets sound before completion.
wait_for_key_or_task_completion:
    lda #FLAG_DISABLE
    sta flag__cancel_interrupt_state
!loop:
    jsr check_option_keypress
    jsr check_stop_keypess
    lda flag__cancel_interrupt_state
    beq !loop-
    jmp stop_sound

// 931F
// Clear sprite position 24 in graphics memory.
clear_mem_sprite_24:
    lda ptr__sprite_24_mem
    sta FREEZP+2
    lda ptr__sprite_24_mem+1
    sta FREEZP+3
    ldy #(BYTES_PER_SPRITE-1)
    lda #$00
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 92A7
// Clear sprite position 48 in graphics memory.
clear_mem_sprite_48:
    lda ptr__sprite_48_mem
    sta FREEZP+2
    lda ptr__sprite_48_mem+1
    sta FREEZP+3
    ldy #(BYTES_PER_SPRITE-1) // 0 offset
    lda #$00
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 91E7
// Clear sprite position 56 and 57 in graphics memory.
clear_mem_sprite_56_57:
    lda ptr__sprite_56_mem
    sta FREEZP+2
    lda ptr__sprite_56_mem+1
    sta FREEZP+3
    lda #$00
    ldy #(BYTES_PER_SPRITE*2) // BUG: Should be - 1. No big deal... just clears one more byte than we need to.
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 9333
// Clear the screen.
clear_screen:
    lda #<SCNMEM
    sta FREEZP+2
    lda #>SCNMEM
    sta FREEZP+3
    ldx #$03
    lda #$00
    tay
!loop:
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+3
    dex
    bne !loop-
!loop:
    sta (FREEZP+2),y
    iny
    cpy #$E8 // Screen memory ends at +$03E8 (remaining bytes are used for sprite pointers)
    bcc !loop-
    rts

// AC16
// Read music from the music pattern command list and play notes or execute special commands.
// Requires:
// - Pointers to patterns are stored in OLDTXT/OLDTXT+1 for voice 1, OLDTXT+2/OLDTXT+3 for voice 2 and OLDTXT+4/OLDTXT+5
//   for voice 3.
// Notes:
// - Commands are separated by notes and begin with a special code as follows:
//   - 00: stop current note
//   - 01-F9: Play a note (of given note value)
//   - FB: Set delay - next number in pattern is the delay time.
//   - FC: Set early filter gate release (release gate but continue delay).
//   - FD: Set introduction sub-state (synchs state with certain points in the music).
//   - FE: End pattern - move to next pattern in the pattern list.
//   - FF: End music.
// - See `initialize_music` for further details of how music and patterns are stored.
// - This routine is called each time a raster interrupt occurs. It runs once and processes notes/command on each
//   voice, increments the pointer to the next command/note and then exits.
play_music:
    ldx #(NUM_VOICES-1) // 0 offset
!loop:
    // Configure the voice.
    txa
    asl
    tay
    lda ptr__voice_play_fn_list,y
    sta prt__voice_note_fn
    lda ptr__voice_play_fn_list+1,y
    sta prt__voice_note_fn+1
    lda ptr__voice_ctl_addr_list,y
    sta FREEZP+2
    lda ptr__voice_ctl_addr_list+1,y
    sta FREEZP+3
    lda private.ptr__voice_pattern_fn_list,y
    sta private.prt__voice_pattern_data
    lda private.ptr__voice_pattern_fn_list+1,y
    sta private.prt__voice_pattern_data+1
    lda private.cnt__voice_note_delay_list,x
    beq !get_next_note+
    // Wait for note to finish playing and release the note just before delay expires.
    cmp #$02
    bne !delay+
    lda private.data__voice_control_list,x
    and #%1111_1110 // Release
    ldy #$04 // Voice control register
    sta (FREEZP+2),y
!delay:
    dec private.cnt__voice_note_delay_list,x
    bne !return+
!get_next_note:
    jsr private.get_next_pattern_command
!return:
    dex
    bpl !loop-
    rts

// A13E
// Read note from current music loop and increment the note pointer.
get_note:
    ldy #$00
    jmp (prt__voice_note_fn)

// AD1E
// Initialize music and configure voices.
// Sets:
// - Pointers to patterns are stored in OLDTXT/OLDTXT+1 for voice 1, OLDTXT+2/OLDTXT+3 for voice 2 and OLDTXT+4/OLDTXT+5
//   for voice 3.
// Notes:
// - Pointers are set to the start of each music pattern. A pattern is part of a music sequence for single voice that
//   can be repeated if necessary.
// - Patterns hold notes, delays and commands for ending the pattern or setting a game state (modify how the intro
//   displays matched to a music sequence).
// - The method also sets pointers to a list of patterns for each voice. The song loop plays a pattern (terminated by
//   FE) and then moves to the next pattern in the pattern list to read which pattern to play next.
// - A final FF command tells the music loop that there are no more patterns.
// - Super neat and efficient as repeated beats only need to be stored once. NICE!
// - Note that this method handles both the intro and outro music. Both icons start with the same patterns and end with
//   the same terminating patterns. The otro just skips all the patterns in the middle. Kind of cheeky.
initialize_music:
    // Full volume.
    lda #%0000_1111
    sta SIGVOL
    //
    // Configure music pointers.
    ldy #(NUM_VOICES*2-1) // Read high/low bytes of the source pattern for each voice (0 offset)
!loop:
    lda param__is_play_outro
    bpl !intro+
    // Configure outro music phrasing.
    lda private.ptr__outro_voice_init_pattern_list,y
    jmp !next+
!intro:
    // Configure intro music phrasing.
    lda private.ptr__intro_voice_init_pattern_list,y
!next:
    sta VARTAB,y
    // Both intro and outro music start with the same initial pattern on all 3 voices.
    lda private.ptr__common_voice_init_pattern_list,y
    sta OLDTXT,y
    dey
    bpl !loop-
    //
    // Configure voices.
    ldx #(NUM_VOICES-1) // 0 offset
!loop:
    lda #$00
    sta private.cnt__voice_note_delay_list,x // Reset delay counter
    txa
    asl
    tay
    lda ptr__voice_ctl_addr_list,y
    sta FREEZP+2
    lda ptr__voice_ctl_addr_list+1,y
    sta FREEZP+3
    ldy #$06 // Voice sustain
    lda private.data__voice_initial_sustain_value_list,x
    sta (FREEZP+2),y // Set initial sustain value
    lda private.data__voice_initial_control_value_list,x
    sta private.data__voice_control_list,x // Set initial control
    dey
    lda private.data__voice_attack_value_list,x
    sta (FREEZP+2),y // Set initial attack
    dex
    bpl !loop-
    rts

//---------------------------------------------------------------------------------------------------------------------
// Private routines.
.namespace private {
    // 63F3
    // Skip board walk and display game options.
    reset_options_state:
        // Ensure keyboard buffer empty and wait for key to be released.
        lda LSTX
        cmp #%0100_0000 // No key?
        bne reset_options_state
        // Advance game state.
        lda #(30*JIFFIES_PER_SECOND/256)
        sta board.cnt__countdown_timer // Reset auto play to 30 seconds
        lda #FLAG_ENABLE
        sta flag__cancel_interrupt_state // Exit interrupt wait loops
        // Remove intro interrupt handler and switch it for the default 'no-action' handler.
        sei
        lda #<complete_interrupt
        sta main.ptr__raster_interrupt_fn
        lda #>complete_interrupt
        sta main.ptr__raster_interrupt_fn+1
        cli
        // Set text mode character memory to $0800-$0FFF (+VIC bank offset as set in CI2PRA).
        // Set character dot data to $0400-$07FF (+VIC bank offset as set in CI2PRA).
        lda #%0001_0010
        sta VMCSB
        // Stop introduction and display options page.
        lda #FLAG_ENABLE_FF
        sta flag__game_loop_state
        // Stop introduction from being played again on next new game.
        lda #FLAG_DISABLE
        sta intro.flag__is_enabed
        sta flag__is_complete
        rts

    // 8D33
    // Roll bits from 3 bytes. Used by `add_sprite_to_graphics` to mirror a multi-colored sprite. See
    // `add_sprite_to_graphics` for further info.
    mirror_bits:
        rol data__temp_storage+3
        rol data__temp_storage+2
        rol data__temp_storage+1
        ror
        ror data__temp_storage+4
        ror data__temp_storage+5
        rts

    // AC5B
    // Reads a command from the current pattern data. Commands may be notes or special commands. See `play_music` for
    // details.
    get_next_pattern_command:
        jsr get_note
        cmp #SOUND_CMD_END // Stop voice
        bne !next+
        // Reset voice.
        ldy #$04 // Control register
        lda #$00
        sta (FREEZP+2),y // FREEZP+2 is ptr to base SID control address for current voice
        rts
    !next:
        cmp #SOUND_CMD_NEXT_PATTERN // Pattern finished - load next pattern
        bne !next+
        jsr get_pattern
        jmp get_next_pattern_command
    !next:
        cmp #SOUND_CMD_NEXT_STATE // Set next into animation state
        beq !set_state+
        cmp #SOUND_CMD_SET_DELAY // Set delay
        beq !set_delay+
        cmp #SOUND_CMD_NO_NOTE // Stop note
        beq !clear_note+
        cmp #SOUND_CMD_RELEASE_NOTE // Release note
        beq !release_note+
        // Play note - sets gate filter, loads the command in to voice hi frequency control, reads the next command and
        // then loads that in to the voice lo frequency control.
        pha
        ldy #$04
        lda data__voice_control_list,x
        and #%1111_1110 // Start gate release on current note
        sta (FREEZP+2),y
        ldy #$01
        pla
        sta (FREEZP+2),y
        jsr get_note
        ldy #$00
        sta (FREEZP+2),y
        jmp !set_note+
    !set_state:
        // Advance the introduction sub state. This allows states to be times with certain points within the
        // introduction music.
        lda intro.idx__substate_fn_ptr
        inc intro.idx__substate_fn_ptr
        asl
        tay
        lda intro.ptr__substate_fn_list,y
        sta intro.ptr__substate_fn
        lda intro.ptr__substate_fn_list+1,y
        sta intro.ptr__substate_fn+1
        jmp get_next_pattern_command
    !clear_note:
        ldy #$04
        sta (FREEZP+2),y
        jmp !return+
    !set_delay:
        jsr get_note
        sta data__voice_note_delay,x
        jmp get_next_pattern_command
    !release_note:
        ldy #$04
        lda data__voice_control_list,x
        and #%1111_1110 // Start gate release on current note
        sta (FREEZP+2),y
    !set_note:
        ldy #$04
        lda data__voice_control_list,x // Set default note control value for voice
        sta (FREEZP+2),y
    !return:
        lda data__voice_note_delay,x
        sta cnt__voice_note_delay_list,x
        rts

    // A143
    // Get note for voice 1 and increment note pointer.
    get_note_v1:
        lda (OLDTXT),y
        inc OLDTXT
        bne !next+
        inc OLDTXT+1
    !next:
        rts

    // A14C
    // Get note for voice 2 and increment note pointer.
    get_note_v2:
        lda (OLDTXT+2),y
        inc OLDTXT+2
        bne !next-
        inc OLDTXT+3
        rts

    // A155
    // Get note for voice 3 and increment note pointer.
    get_note_v3:
        lda (OLDTXT+4),y
        inc OLDTXT+4
        bne !next-
        inc OLDTXT+5
        rts

    // ACDA
    // Read a pattern for the current music loop and increment the pattern pointer.
    get_pattern:
        ldy #$00
        jmp (prt__voice_pattern_data)

    // ACDF
    // Get pattern for voice 1 and increment pattern pointer.
    get_pattern_v1:
        lda (VARTAB),y
        sta OLDTXT
        iny
        lda (VARTAB),y
        sta OLDTXT+1
        lda VARTAB
        clc
        adc #$02
        sta VARTAB
        bcc !return+
        inc VARTAB+1
    !return:
        rts

    // ACF4
    // Get pattern for voice 2 and increment pattern pointer.
    get_pattern_v2:
        lda (VARTAB+2),y
        sta OLDTXT+2
        iny
        lda (VARTAB+2),y
        sta OLDTXT+3
        lda VARTAB+2
        clc
        adc #$02
        sta VARTAB+2
        bcc !return-
        inc VARTAB+3
        rts

    // AD09
    // Get pattern for voice 3 and increment pattern pointer.
    get_pattern_v3:
        lda (VARTAB+4),y
        sta OLDTXT+4
        iny
        lda (VARTAB+4),y
        sta OLDTXT+5
        lda VARTAB+4
        clc
        adc #$02
        sta VARTAB+4
        bcc !return-
        inc VARTAB+5
    !return:
        rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// 8DBF
// List of sprite graphics block pointers.
ptr__sprite_offset_list:
ptr__sprite_00_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+00 // Sprite 0 screen pointer
ptr__sprite_24_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+24 // Sprite 24 screen pointer
ptr__sprite_48_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+48 // Sprite 48 screen pointer
ptr__sprite_56_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+56 // Sprite 56 screen pointer

// 8DC3
// Pre-calculated powers of 2.
data__math_pow2_list: .fill 8, pow(2, i)

// 8DCB
// List of pointer to sprite graphics block memory.
ptr__sprite_mem_list:
ptr__sprite_00_mem: .word GRPMEM+00*BYTES_PER_SPRITE // Pointer to sprite 0 graphic memory area
ptr__sprite_24_mem: .word GRPMEM+24*BYTES_PER_SPRITE // Pointer to sprite 24 graphic memory area
ptr__sprite_48_mem: .word GRPMEM+48*BYTES_PER_SPRITE // Pointer to sprite 48 graphic memory area
ptr__sprite_56_mem: .word GRPMEM+56*BYTES_PER_SPRITE // Pointer to sprite 56 graphic memory area

// 906F
// Color of icon for each player side (light, dark).
data__player_icon_color_list: .byte YELLOW, LIGHT_BLUE

// A0A5
// Pointer to routine to read notes for each voice.
ptr__voice_play_fn_list: .word private.get_note_v1, private.get_note_v2, private.get_note_v3

// A0AB
// Address offsets for the starting SID address for each voice.
ptr__voice_ctl_addr_list: .word FRELO1, FRELO2, FRELO3

// BF19
// Screen offset to color ram.
data__color_mem_offset: .byte >(COLRAM-SCNMEM)

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 3D40
    // Music is played by playing notes within the pattern referenced by `init_pattern_list_ptr` for each voice.
    // When the voice pattern finishes, the play routine will look at the intro or outro pattern list pointers
    // (`intro_pattern_ptr` or `outro_pattern_ptr`) depending on the track being played and will select the next
    // patten to play. This continues until a termination command is read.
    // Note that the same pattern may be played multiple times during the piece.
    //
    // Pointers for intro music pattern list for each voice.
    ptr__intro_voice_init_pattern_list:
        .word ptr__intro_voice1_pattern_list, ptr__intro_voice2_pattern_list, ptr__intro_voice3_pattern_list
    //
    // Initial patterns for both intro and outro music.
    // After this pattern is played, the music will continue to play the intro or outro patters as required.
    ptr__common_voice_init_pattern_list:
        .word resources.snd__music_1, resources.snd__music_2, resources.snd__music_3
    //
    // Pointers for outro music pattern list for each voice.
    ptr__outro_voice_init_pattern_list:
        .word ptr__outro_voice1_pattern_list, ptr__outro_voice2_pattern_list, ptr__outro_voice3_pattern_list

    // Music patternology.
    // Intro music voice 1 pattern list.
    ptr__intro_voice1_pattern_list:
        .word resources.snd__music_4, resources.snd__music_4, resources.snd__music_10, resources.snd__music_11
        .word resources.snd__music_1
    // Outro music voice 1 pattern list.
    ptr__outro_voice1_pattern_list:
        .word resources.snd__music_19
    // Intro music voice 2 pattern list.
    ptr__intro_voice2_pattern_list:
        .word resources.snd__music_5, resources.snd__music_5, resources.snd__music_12, resources.snd__music_13
        .word resources.snd__music_2
    ptr__outro_voice2_pattern_list:
    // Outro music voice 2 pattern list.
        .word resources.snd__music_21
    // Intro music voice 3 pattern list.
    ptr__intro_voice3_pattern_list:
        .word resources.snd__music_6, resources.snd__music_7, resources.snd__music_7, resources.snd__music_7
        .word resources.snd__music_8, resources.snd__music_8, resources.snd__music_9, resources.snd__music_9
        .word resources.snd__music_6, resources.snd__music_7, resources.snd__music_7, resources.snd__music_7
        .word resources.snd__music_8, resources.snd__music_8, resources.snd__music_9, resources.snd__music_9
        .word resources.snd__music_14, resources.snd__music_15, resources.snd__music_15, resources.snd__music_15
        .word resources.snd__music_16, resources.snd__music_16, resources.snd__music_16, resources.snd__music_16
        .word resources.snd__music_17, resources.snd__music_17, resources.snd__music_18, resources.snd__music_18
        .word resources.snd__music_3
    // Outro music voice 3 pattern list.
    ptr__outro_voice3_pattern_list:
        .word resources.snd__music_20

    // 8B27
    // Source offset of the first frame of each icon sprite. An icon set comprises of multiple sprites (nominally 15)
    // to provide animations for each direction and action. One icon, the Shape Shifter, comprises only 10 sprites
    // though as it doesn't need an attack sprite set as it shape shifts in to the opposing icon when challenging.
    ptr__icon_sprite_mem_offset_list:
        // UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS
        .fillword 13, resources.prt__sprites_icon+i*BYTES_PER_ICON_SPRITE*15
        // DG
        .fillword 1, resources.prt__sprites_icon+12*BYTES_PER_ICON_SPRITE*15+1*BYTES_PER_ICON_SPRITE*10
        // BS, GB
        .fillword 2, resources.prt__sprites_icon+(13+i)*BYTES_PER_ICON_SPRITE*15+1*BYTES_PER_ICON_SPRITE*10
        // AE, FE, EE, WE
        .fillword 4, resources.prt__sprites_elemental+i*BYTES_PER_ICON_SPRITE*15

    // 8BDA
    // Color of each elemental (air, fire, earth, water).
    data__elemental_icon_color_list: .byte LIGHT_GRAY, RED, BROWN, BLUE

    // 8D44
    // Memory offset of each sprite frame within the sprite set.
    // The following terminology is used in descriptions below:
    // - m-=movement frame, a-=attack frame, w-=weapon/projectile (bullet, sword etc) frame
    // - n,s,e,w,ne etc are compass directions, so a-ne means attack to the right and up
    // - numbers represent the animation frame. eg movement frames have 4 animations each
    data__icon_sprite_frame_mem_offset_list:
            //   m-e1   m-e2   m-e3   m-e4   m-s1   m-s2   m-s3   m-s4
        .word $0000, $0036, $006C, $00A2, $00D8, $010E, $00D8, $0144
            //   m-n1   m-n2   m-n3   m-n4   a-n    a-ne   a-e    a-sw
        .word $017A, $01B0, $017A, $01E6, $021C, $0252, $0288, $02BE
        //    a-s    w-e    w-n    w-ne   w-se
        .word $02F4, $0008, $0000, $0010, $0018

    // AD6A
    // Initial voice sustain values.
    data__voice_initial_sustain_value_list: .byte $a3, $82, $07

    // AD6D
    // Initial voice control values.
    data__voice_initial_control_value_list: .byte $21, $21, $21

    // AD70
    // Initial voice attack values.
    data__voice_attack_value_list: .byte $07, $07, $07

    // AD7D
    // Pointer to routine to read the next pattern for each voice.
    ptr__voice_pattern_fn_list: .word get_pattern_v1, get_pattern_v2, get_pattern_v3
}

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC1
// Temporary AI selection counter. The counte ris incremented when AI option is selected up to $02 before wrapping back
// to $00. Is 0 for none, 1 for computer plays light, 2 for computer plays dark.
cnt__ai_selection: .byte $00

// BCC3
// Pre-game intro state ($80 = intro, $00 = in game, $ff = options).
flag__game_loop_state: .byte $00

// BCC5
// The AI selection is used to generate a flag representing the side played by the AI.
// Is positive ($55) for light, negative ($AA) for dark, ($00) for neither or ($ff) for both.
// Both is selected after a selection timeout.
flag__ai_player_selection: .byte $00

// BCD0
// Is set to $80 to indicate that the game state should be changed to the next state.
flag__cancel_interrupt_state: .byte $00

// BCD3
// Is set to non zero to stop the current state and advance the game state to the options screen.
flag__is_complete: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCD4
// Low byte pointer to sprite shape data source data.
ptr__sprite_source_lo_list: .byte $00, $00, $00, $00

// BCD8
// High byte pointer to sprite shape data source data.
ptr__sprite_source_hi_list: .byte $00, $00, $00, $00

// BCDF
// Number of bytes to copy for the given sprite.
param__sprite_source_len: .byte $00

// BCE3
// Initial animation for up to 4 sprites.
param__icon_sprite_source_frame_list: .byte $00, $00, $00, $00

// BD66
// Routine pointer to retrieve a note for the current voice.
prt__voice_note_fn: .word $0000

// BF08
// Set to non zero to enable the voice for each player.
flag__is_player_sound_enabled: .byte $00, $00

// BF0B
// Note delay time.
data__voice_note_delay: .byte $00, $00, $00

// BF24
// Frame offset of sprite icon set. Add #$80 to invert the frame on copy.
param__icon_sprite_curr_frame: .byte $00

// BF29
// Icon sprite group offset used to determine which sprite to copy.
param__icon_offset_list: .byte $00, $00, $00, $00

// BF2D
// Type of icon (See `icon types` constants).
param__icon_type_list: .byte $00, $00, $00, $00

// BF49
// Set TRUE to copy icon sprite shape data or FALSE to copy icon or weapon/projectile sprite data based on value in X
// register.
param__is_copy_icon_sprites: .byte $00

// BF50
// Is FALSE for title music and TRUE for game end music.
param__is_play_outro: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BF08
    // Pointer to routine to read current pattern for current voice.
    prt__voice_pattern_data: .word $0000

    // BF1A
    // Temporary data storage area used for sprite manipulation.
    data__temp_storage: .byte $00, $00, $00, $00, $00, $00

    // BF23
    // Low byte of current sprite memory location pointer. Used to increment to next sprite block pointer location.
    ptr__sprite_mem_lo: .byte $00

    // BF4A
    // Current note delay countdown.
    cnt__voice_note_delay_list: .byte $00, $00, $00

    // BF4D
    // Current voice control value.
    data__voice_control_list: .byte $00, $00, $00
}
