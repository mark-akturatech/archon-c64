.filenamespace common
//---------------------------------------------------------------------------------------------------------------------
// Common routines used by intro, board and battle arena states.
//---------------------------------------------------------------------------------------------------------------------
.segment Common

// 638E
// Description:
// - Complete the current interrupt by restoring the registers pushed on to the stack by the
complete_interrupt:
    pla
    tay
    pla
    tax
    pla
    rti

// 6394
// Detect keypress and trigger action based on key
// This function is called during intro, board config and options game states. it allows escape to cancel current state
// and function keys to set game options. eg pressing F1 toggles number of players. You can select this option in
// any of the non game states. if the game state is not in options state, then the game will jump directly to the
// options state.
check_option_keypress:
    lda LSTX
    cmp #KEY_NONE
    bne process_key
    rts
process_key:
    cmp #KEY_F7
    bne !next+
    // Start game.
    jsr advance_intro_state
    lda #FLAG_DISABLE
    sta board.countdown_timer
    sta flag__pregame_state
    lda flag__ai_player_selection
    sta game.flag__ai_player_ctl
    jmp main.game_loop
!next:
    cmp #KEY_F5
    bne !next+
    // Toggle first player.
    lda game.data__curr_player_color
    eor #$FF
    sta game.data__curr_player_color
    jsr advance_intro_state
    jmp main.game_loop
!next:
    cmp #KEY_F3
    beq set_num_players
    rts
set_num_players:
    // Toggle between two players, player light, player dark
    lda cnt__ai_selection
    clc
    adc #$01 // Not sure why we just don't `inc` here instead of adding
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
    sta game.flag__ai_player_ctl
    sta flag__ai_player_selection
    jsr advance_intro_state
    jmp main.game_loop

// 63F3
// Skip board walk and display game options.
advance_intro_state:
    // Ensure keyboard buffer empty and key released.
    lda LSTX
    cmp #$40
    bne advance_intro_state
    // Advance game state.
    lda #$07 // Load ~30 seconds in to countdown timer
    sta board.countdown_timer
    lda #FLAG_ENABLE
    sta flag__enable_next_state
    // Remove intro interrupt handler.
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
    //
    lda #$FF // Go straight to options
    sta flag__pregame_state
    // Skip intro.
    lda #FLAG_DISABLE
    sta intro.flag__enable
    sta intro.flag__exit_intro
    rts

// 644D
// Description:
// - Determine sprite source data address for a given icon, set the sprite color and direction and enable.
// Prerequisites:
// - X: Sprite number (0 - 4)
// - `idx__icon_offset,x`: contains the sprite group pointer offset (see `ptr__icon_sprite_mem_offset_list` for details).
// - `data__icon_type,x`: contains the sprite icons type.
// Sets:
// - `ptr__sprite_source_lo_list`: Lo pointer to memory containing the sprite definition start address.
// - `ptr__sprite_source_hi_list`: Hi pointer to memory containing the sprite definition start address.
// - `param__sprite_source_frame`: set to #$00 for right facing icons and #$11 for left facing.
// - Sprite + X is enabled and color configured
sprite_initialize:
    lda idx__icon_offset,x
    asl
    tay
    lda ptr__icon_sprite_mem_offset_list,y
    sta ptr__sprite_source_lo_list,x
    lda ptr__icon_sprite_mem_offset_list+1,y
    sta ptr__sprite_source_hi_list,x
    lda data__icon_type,x
    cmp #AIR_ELEMENTAL // Is sprite an elemental?
    bcc !next+
    and #$03
    tay
    lda data__elemental_icon_color_list,y
    bpl intialize_enable_sprite
!next:
    ldy #$00 // Set Y to 0 for light icon, 1 for dark icon
    cmp #MANTICORE // Dark icon
    bcc !next+
    iny
!next:
    lda data__player_icon_color_list,y
intialize_enable_sprite:
    sta SP0COL,x
    lda data__math_pow2,x
    ora SPENA
    sta SPENA
    lda idx__icon_offset,x
    and #$08 // Icons with bit 8 set are dark icons
    beq !next+
    lda #$11 // Left facing icon
!next:
    sta param__sprite_source_frame,x
    rts

// 6490
// Description:
// - Create a time delay by waiting for a number of jiffies.
// Requires:
// - X: number of jiffies (~0.01667s per jiffy) to wait.
// Preserves:
// - Y
// Notes:
// - Wait time can be cancelled by pressing 'Q' or STOP key.
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
// Description:
// - Detect if RUN/STOP or Q key is pressed.
// Sets:
// - `intro.flag__exit_intro` is toggled if RUN/STOP pressed. This will force the intro to exit and the options
//   screen to display.
// Notes:
// - Game is reset if Q key is pressed.
// - Subroutine waits for key to be released before exiting.
check_stop_keypess:
    // go to next state of RUN/STOP
    jsr STOP
    beq !next+
    cmp #KEY_Q
    bne !return+
    // Wait for key to be released.
!loop:
    jsr STOP
    cmp #KEY_Q
    beq !loop-
    jsr advance_intro_state
    jmp main.game_loop
!next:
    lda intro.flag__exit_intro
    eor #$FF
    sta intro.flag__exit_intro
!loop:
    jsr STOP
    beq !loop-
!return:
    rts

// 7FAB
// Description:
// - Stop sound from playing on all 3 voices.
stop_sound:
    ldx #$01
!loop:
    txa
    asl
    tay
    lda ptr__voice_ctl_addr_list,y
    sta FREEZP+2
    lda ptr__voice_ctl_addr_list+1,y
    sta FREEZP+3
    ldy #$04
    lda #$00
    sta (FREEZP+2),y
    sta flag__enable_player_sound,x
    sta data__voice_note_delay,x
    dex
    bpl !loop-
    rts

// 8BDE
// Description:
// - Adds a set of sprites for an icon to the graphics memory.
// Prerequisites:
// - X Register = 0 to copy light player icon frames
// - X Register = 1 to copy dark player icon frames
// - X Register = 2 to copy light player projectile frames
// - X Register = 3 to copy dark player projectile frames
// Notes:
// - Icon frames add 24 sprites as follows:
//  - 4 x East facing icons (4 animation frames)
//  - 4 x South facing icons (4 animation frames)
//  - 4 x North facing icons (4 animation frames)
//  - 5 x Attack frames (north, north east, east, south east, south facing)
//  - 4 x West facing icon frames (mirrored representation of east facing icons)
//  - 3 x West facing attack frames (mirrored east facing icons - north west, west, south west)
// - Projectile frames are frames used to animate the players projectile (or scream/thrust). There are 7 sprites as
//   follows:
//  - 1 x East direction projectile
//  - 1 x North/south direction projectile (same sprite is used for both directions)
//  - 1 x North east direction projectile
//  - 1 x South east direction projectile
//  - 1 x East direction projectile (mirrored copy of east)
//  - 1 x North west direction projectile (mirrored copy of north east)
//  - 1 x South west direction projectile (mirrored copy of south east)
// - Special player pieces Phoneix and Banshee only copy 4 sprites (east, south, north, west).
// - Mirrored sprite sources are not represented in memory. Instead the sprite uses the original version and logic is
//   used to create a mirrored copy.
add_sprite_set_to_graphics:
    txa
    asl
    tay
    lda ptr__sprite_00_mem,y
    sta FREEZP+2
    sta ptr__sprite_mem_lo
    lda ptr__sprite_00_mem+1,y
    sta FREEZP+3
    cpx #$02
    bcc add_icon_frames_to_graphics // Copy icon or projectile frames?
    // Projectile frames.
    txa
    and #$01
    tay
    lda idx__icon_offset,y
    and #$07
    cmp #$06
    bne add_projectile_frames_to_graphics // Banshee/Phoenix?
    lda #$00
    sta data__icon_set_sprite_frame
    jmp add_sprite_to_graphics // Add special full height projectile frames for Banshee and Phoneix icons.
// Copies projectile frames: $11, $12, $13, $14, $11+$80, $13+$80, $14+$80 (80 inverts frame)
add_projectile_frames_to_graphics:
    lda #$11
    sta data__icon_set_sprite_frame
    bne add_individual_frame_to_graphics
// Copies projectile frames: $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$10,$00+$80,$01+$80,
// $02+$80, $03+$83,$0d+$80,$0e+$80,$0f+$80 (80 inverts frame)
add_icon_frames_to_graphics:
    lda #$00
    sta data__icon_set_sprite_frame
add_individual_frame_to_graphics:
    jsr add_sprite_to_graphics
    inc data__icon_set_sprite_frame
    cpx #$02
    bcs check_projectile_frames
    lda data__icon_set_sprite_frame
    bmi check_inverted_icon_frames
    cmp #$11
    bcc add_next_frame_to_graphics
    lda #$80 // Jump from frame 10 to 80 (skip 11 to 7f)
    sta data__icon_set_sprite_frame
    bmi add_next_frame_to_graphics
check_inverted_icon_frames:
    cmp #$84
    bcc add_next_frame_to_graphics
    beq skip_frames_84_to_8C
    cmp #$90
    bcc add_next_frame_to_graphics
    rts // End after copying frame 8f
check_projectile_frames:
    lda data__icon_set_sprite_frame
    bmi check_inverted_projectile_frames
    cmp #$15
    bcc add_next_frame_to_graphics
    lda #$91 // Jump from frame 14 to 91 (skip 15 to 90)
    sta data__icon_set_sprite_frame
    bmi add_next_frame_to_graphics
check_inverted_projectile_frames:
    cmp #$95
    bcc !next+
    rts // End after copying frame 94
!next:
    cmp #$92
    bne add_next_frame_to_graphics
    inc data__icon_set_sprite_frame // Skip frame 92
    jmp add_next_frame_to_graphics
skip_frames_84_to_8C:
    lda #$8D
    sta data__icon_set_sprite_frame
add_next_frame_to_graphics:
    // Incremement frame grpahics pointer to point to next sprite memory location.
    lda ptr__sprite_mem_lo
    clc
    adc #BYTES_PER_SPRITE
    sta ptr__sprite_mem_lo
    sta FREEZP+2
    bcc add_individual_frame_to_graphics
    inc FREEZP+3
    bcs add_individual_frame_to_graphics

// 8C6D
// Copies a sprite frame in to graphical memory.
// Also includes additional functionality to add a mirrored sprite to graphics memory.
add_sprite_to_graphics:
    lda data__icon_set_sprite_frame
    and #$7F // The offset has #$80 if the sprite frame should be inverted on copy
    // Get frame source memory address.
    // This is done by first reading the sprite source offset of the icon set and then adding the frame offset.
    asl
    tay
    lda data__icon_sprite_frame_mem_offset_list,y
    clc
    adc ptr__sprite_source_lo_list,x
    sta FREEZP
    lda ptr__sprite_source_hi_list,x
    adc data__icon_sprite_frame_mem_offset_list+1,y
    sta FREEZP+1
    lda param__is_copy_animation_group // Set to $80+ to copy multiple animation frames for a single piece
    bmi move_sprite
    cpx #$02 // 0 for light icon frames, 1 for dark icon frames, 2 for light bullets, 3 for dark bullets
    bcc move_sprite
    //
    // Copy sprites used for attacks (eg projectiles, clubs, sords, screams, fire etc)
    txa
    // Check if piece is Banshee or Phoenix. Thiese pieces have special non-directional attacks.
    and #$01
    tay
    lda idx__icon_offset,y
    and #$07
    cmp #$06
    bne !next+
    lda #$FF // Banshee and Phoenix only have 4 attack frames (e,s,n,w), so is 64*4 = 255 (0 offset)
    sta param__sprite_source_size
    jmp move_sprite
!next:
    // All other pieces require 7 attack frames (e, n/s, ne, se, w, nw, sw)
    ldy #$00
!loop:
    lda data__icon_set_sprite_frame
    bpl no_invert_attack_frame // +$80 to invert attack frame
    // Inversts 8 bits. eg 1000110 becomes 0110001
    lda #$08
    sta data__temp_storage
    lda (FREEZP),y
    sta data__temp_storage+1
rotate_loop:
    ror data__temp_storage+1
    rol
    dec data__temp_storage
    bne rotate_loop
    beq !next+
no_invert_attack_frame:
    lda (FREEZP),y
!next:
    sta (FREEZP+2),y
    inc FREEZP+2
    inc FREEZP+2
    iny
    cpy param__sprite_source_size
    bcc !loop-
    rts
move_sprite:
    ldy #$00
    lda data__icon_set_sprite_frame
    bmi move_sprite_and_invert
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    cpy param__sprite_source_size
    bcc !loop-
    rts
// Mirror the sprite on copy - used for when sprite is moving in the opposite direction.
move_sprite_and_invert:
    lda #$0A
    sta data__temp_storage // Sprite is inverted in 10 blocks
    tya
    clc
    adc #$02
    tay
    lda (FREEZP),y
    sta data__temp_storage+3
    dey
    lda (FREEZP),y
    sta data__temp_storage+2
    dey
    lda (FREEZP),y
    sta data__temp_storage+1
    lda #$00
    sta data__temp_storage+4
    sta data__temp_storage+5
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
    dec data__temp_storage
    bne !loop-
    sta (FREEZP+2),y
    iny
    lda data__temp_storage+4
    sta (FREEZP+2),y
    iny
    lda data__temp_storage+5
    sta (FREEZP+2),y
    iny
    cpy param__sprite_source_size
    bcc move_sprite_and_invert
    rts
invert_bytes:
    rol data__temp_storage+3
    rol data__temp_storage+2
    rol data__temp_storage+1
    ror
    ror data__temp_storage+4
    ror data__temp_storage+5
    rts

// 8DD3
// Description:
// - Clear the video graphics area and reset sprite positions and sprite configuration.
// Sets:
// - Clears 4kb of graphical memory with 00 bytes.
// - All 8 sprites are reset by setting 00 to sprite position and configuration (color, size etc) bytes.
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
    // reset sprite positions
    ldx #$07
    sta MSIGX
!loop:
    sta SP0X,x
    dex
    bpl !loop-
    rts

// 905C
// Description:
// - Busy wait for STOP, game options (function keys) or Q keypress or game state change.
// Notes:
// - Repeats until `flag__enable_next_state` is set.
wait_for_key:
    lda #FLAG_DISABLE
    sta flag__enable_next_state
!loop:
    jsr check_option_keypress
    jsr check_stop_keypess
    lda flag__enable_next_state
    beq !loop-
    jmp stop_sound

// 91E7
// Description:
// - Clear sprite position 56 and 57 in graphics memory.
// Sets:
// - Clears the 56th and 57th sprite position graphical memory (with 00).
clear_mem_sprite_56_57:
    lda ptr__sprite_56_mem
    sta FREEZP+2
    lda ptr__sprite_56_mem+1
    sta FREEZP+3
    lda #$00
    ldy #(BYTES_PER_SPRITE*2)
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 92A7
// Description:
// - Clear sprite position 48 in graphics memory.
// Sets:
// - Clears the 48th sprite position graphical memory (with 00).
clear_mem_sprite_48:
    lda ptr__sprite_48_mem
    sta FREEZP+2
    lda ptr__sprite_48_mem+1
    sta FREEZP+3
    ldy #(BYTES_PER_SPRITE-1)
    lda #$00
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 931F
// Description:
// - Clear sprite position 24 in graphics memory.
// Sets:
// - Clears the 24th sprite position graphical memory (with 00).
clear_mem_sprite_24:
    lda ptr__sprite_24_mem
    sta FREEZP+2
    lda ptr__sprite_24_mem+1
    sta FREEZP+3
    ldy #(BYTES_PER_SPRITE - 1)
    lda #$00
!loop:
    sta (FREEZP+2),y
    dey
    bpl !loop-
    rts

// 9333
// Description:
// - Clear the character graphical area.
// Sets:
// - Loads $00 to the video matrix SCNMEM to SCNMEM+$3E7.
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
    cpy #$E8
    bcc !loop-
    rts

// AC16
// Description:
// - Read music from the music pattern command list and play notes or execute special commands.
// Prerequisites:
// - Pointers to patterns are stored in OLDTXT/OLDTXT+1 for voice 1, OLDTXT+2/OLDTXT+3 for voice 2 and OLDTXT+4/OLDTXT+5
//   for voice 3.
// Notes:
// - Commands are separated by notes and begin with a special code as follows:
//      00: stop current note
//      01-F9: Plays a note (of given note value)
//      FB: Set delay - next number in pattern is the delay time.
//      FC: Set early filter gate release (release gate but continue delay).
//      FD: Set game state (synch state with certain points in the music).
//      FE: End pattern - move to next pattern in the pattern list.
//      FF: End music.
// - See `initialize_music` for further details of how music and patterns are stored.
// - This sub is called each time an interrupt occurs. It runs once and processes notes/command on each voice,
//   increments the pointer to the next command/note and then exits.
play_music:
    ldx #$02
!loop:
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
    lda ptr__voice_pattern_fn_list,y
    sta prt__voice_pattern_data
    lda ptr__voice_pattern_fn_list+1,y
    sta prt__voice_pattern_data+1
    //
    lda cnt__voice_note_delay,x
    beq delay_done
    cmp #$02
    bne decrease_delay
    // Release note just before delay expires.
    lda data__voice_control,x
    and #%1111_1110
    ldy #$04
    sta (FREEZP+2),y
decrease_delay:
    dec cnt__voice_note_delay,x
    bne skip_command
delay_done:
    jsr get_next_command
skip_command:
    dex
    bpl !loop-
    rts

// AC5B
// Reads a command from the current pattern data. Commands can be notes or special commands. See `play_music` for
// details.
get_next_command:
    jsr get_note
    cmp #SOUND_CMD_END // Stop voice
    bne !next+
    // Reset voice.
    ldy #$04
    lda #$00
    sta (FREEZP+2),y // FREEZP+2 is ptr to base SID control address for current voice
    rts
!next:
    cmp #SOUND_CMD_NEXT_PATTERN // Pattern finished - load next pattern
    bne !next+
    jsr get_next_pattern
    jmp get_next_command
!next:
    cmp #SOUND_CMD_NEXT_STATE // Set next into animation state
    beq set_state
    cmp #SOUND_CMD_SET_DELAY // Set delay
    beq set_delay
    cmp #SOUND_CMD_NO_NOTE // Stop note
    beq clear_note
    cmp #SOUND_CMD_RELEASE_NOTE // Release note
    beq release_note
    // Play note - sets gate filter, loads the command in to voice hi frequency control, reads the next command and
    // then loads that in to the voice lo frequency control.
    pha
    ldy #$04
    lda data__voice_control,x
    and #%1111_1110 // Start gate release on current note
    sta (FREEZP+2),y
    ldy #$01
    pla
    sta (FREEZP+2),y
    jsr get_note
    ldy #$00
    sta (FREEZP+2),y
    jmp set_note
set_state:
    lda intro.idx__substate_fn_ptr
    inc intro.idx__substate_fn_ptr
    asl
    tay
    lda intro.ptr__substate_fn_list,y
    sta intro.ptr__substate_fn
    lda intro.ptr__substate_fn_list+1,y
    sta intro.ptr__substate_fn+1
    jmp get_next_command
clear_note:
    ldy #$04
    sta (FREEZP+2),y
    jmp !return+
set_delay:
    jsr get_note
    sta data__voice_note_delay,x
    jmp get_next_command
release_note:
    ldy #$04
    lda data__voice_control,x
    and #%1111_1110 // Start gate release on current note
    sta (FREEZP+2),y
set_note:
    ldy #$04
    lda data__voice_control,x // Set default note control value for voice
    sta (FREEZP+2),y
!return:
    lda data__voice_note_delay,x
    sta cnt__voice_note_delay,x
    rts

// A13E
// Read note from current music loop and increment the note pointer.
get_note: // Get note for current voice and increment note pointer
    ldy #$00
    jmp (prt__voice_note_fn)

// A143
get_note_V1: // Get note for voice 1 and increment note pointer
    lda (OLDTXT),y
    inc OLDTXT
    bne !next+
    inc OLDTXT+1
!next:
    rts

// A14C
get_note_V2: // Get note for voice 2 and increment note pointer
    lda (OLDTXT+2),y
    inc OLDTXT+2
    bne !next-
    inc OLDTXT+3
    rts

// A155
get_note_V3: // Get note for voice 3 and increment note pointer
    lda (OLDTXT+4),y
    inc OLDTXT+4
    bne !next-
    inc OLDTXT+5
    rts

// ACDA
// Read a pattern for the current music loop and increment the pattern pointer.
get_next_pattern: // Get pattern for current voice and increment pattern pointer
    ldy #$00
    jmp (prt__voice_pattern_data)

// ACDFD
get_pattern_V1: // Get pattern for voice 1 and increment pattern pointer
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
get_pattern_V2: // Get pattern for voice 2 and increment pattern pointer
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
get_pattern_V3: // Get pattern for voice 3 and increment pattern pointer
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

// AD1E
// Dscription:
// - Initialize music and configure voices.
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
    // Configure music pointers.
    ldy #$05
!loop:
    lda param__is_play_outro
    bpl intro_music
    lda ptr__outro_voice_init_pattern_list,y
    jmp !next+
intro_music:
    lda ptr__intro_voice_init_pattern_list,y
!next:
    sta VARTAB,y
    // Both intro and outro music start with the same initial pattern on all 3 voices.
    lda ptr__common_voice_init_pattern_list,y
    sta OLDTXT,y
    dey
    bpl !loop-
    // Configure voices.
    ldx #$02
!loop:
    lda #$00
    sta cnt__voice_note_delay,x
    txa
    asl
    tay
    lda ptr__voice_ctl_addr_list,y
    sta FREEZP+2
    lda ptr__voice_ctl_addr_list+1,y
    sta FREEZP+3
    ldy #$06
    lda data__voice_sustain_value_list,x
    sta (FREEZP+2),y
    lda data__voice_control_value_list,x
    sta data__voice_control,x
    dey
    lda data__voice_attack_value_list,x
    sta (FREEZP+2),y
    dex
    bpl !loop-
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// 3D40
// Music is played by playing notes pointed to by `init_pattern_list_ptr` on each voice.
// When the voice pattern list finishes, the music will look at the intro or outro pattern list pointers (
// `intro_pattern_ptr` or `outro_pattern_ptr`) depending on the track being played. This list will then tell the
// player which pattern to play next.
// When the pattern finishes, it looks at the next pattern in the list and continues until a FE command is reached.
//
// NOTE: The music is split in to two parts so that we can fit it within the relocatable resource blocks.
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
    .fillword 13, resources.prt__sprites_icon+i*BYTERS_PER_STORED_SPRITE*15
    // DG
    .fillword 1, resources.prt__sprites_icon+12*BYTERS_PER_STORED_SPRITE*15+1*BYTERS_PER_STORED_SPRITE*10
    // BS, GB
    .fillword 2, resources.prt__sprites_icon+(13+i)*BYTERS_PER_STORED_SPRITE*15+1*BYTERS_PER_STORED_SPRITE*10
    // AE, FE, EE, WE
    .fillword 4, resources.prt__sprites_elemental+i*BYTERS_PER_STORED_SPRITE*15

// 8BDA
// Color of each elemental (air, fire, earth, water).
data__elemental_icon_color_list: .byte LIGHT_GRAY, RED, BROWN, BLUE

// 8DBF
// Sprite 0 screen pointer.
ptr__sprite_00_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+00

// 8DC0
// Sprite 24 screen pointer.
ptr__sprite_24_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+24

// 8DC1
// Sprite 48 screen pointer.
ptr__sprite_48_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+48

// 8DC2
// Sprite 56 screen pointer.
ptr__sprite_56_offset: .byte (VICGOFF/BYTES_PER_SPRITE)+56

// 8DC3
data__math_pow2: .fill 8, pow(2, i) // Pre-calculated powers of 2

// 8DCB
// Pointer to sprite 0 graphic memory area.
ptr__sprite_00_mem: .byte <(GRPMEM+00*BYTES_PER_SPRITE), >(GRPMEM+00*BYTES_PER_SPRITE)

// 8DCD
// Pointer to sprite 24 graphic memory area.
ptr__sprite_24_mem: .byte <(GRPMEM+24*BYTES_PER_SPRITE), >(GRPMEM+24*BYTES_PER_SPRITE)

// 8DCF
// Pointer to sprite 48 graphic memory area.
ptr__sprite_48_mem: .byte <(GRPMEM+48*BYTES_PER_SPRITE), >(GRPMEM+48*BYTES_PER_SPRITE)

// 8DD1
// Pointer to sprite 56 graphic memory area.
ptr__sprite_56_mem: .byte <(GRPMEM+56*BYTES_PER_SPRITE), >(GRPMEM+56*BYTES_PER_SPRITE)

// 8D44
// Memory offset of each sprite frame within a sprite set.
// In description below:
// - m-=movement frame, a-=attack frame, p-=projectile (bullet, sword etc) frame
// - n,s,e,w,ne etc are compass directions, so a-ne means attack to the right and up
// - numbers represent the animation frame. eg movement frames have 4 animations each
data__icon_sprite_frame_mem_offset_list:
        //   m-e1   m-e2   m-e3   m-e4   m-s1   m-s2   m-s3   m-s4
    .word $0000, $0036, $006C, $00A2, $00D8, $010E, $00D8, $0144
        //   m-n1   m-n2   m-n3   m-n4   a-n    a-ne   a-e    a-sw
    .word $017A, $01B0, $017A, $01E6, $021C, $0252, $0288, $02BE
    //    a-s    p-e    p-n    p-ne   p-se
    .word $02F4, $0008, $0000, $0010, $0018

// 906F
// Color of icon based on side (light, dark).
data__player_icon_color_list: .byte YELLOW, LIGHT_BLUE

// A0A5
// Pointer to function to get note and incremement note pointer for each voice
ptr__voice_play_fn_list: .word get_note_V1, get_note_V2, get_note_V3

// A0AB
// Address offsets for each SID voice control address.
ptr__voice_ctl_addr_list: .word FRELO1, FRELO2, FRELO3

// AD6A
// Voice sustain values.
data__voice_sustain_value_list: .byte $a3, $82, $07

// AD6D
// Voice control values.
data__voice_control_value_list: .byte $21, $21, $21

// AD70
// Voice attack values.
data__voice_attack_value_list: .byte $07, $07, $07

// AD7D
// Pointer to function to get pattern and incremement note pointer for each voice.
ptr__voice_pattern_fn_list: .word get_pattern_V1, get_pattern_V2, get_pattern_V3

// BF19
// Screen offset to color ram.
data__color_mem_offset: .byte >(COLRAM-SCNMEM)

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC1
// Temporary AI selection flag. Is incremented when AI option is selected up to $02 before wrapping back to $00.
// Is 0 for none, 1 for computer plays light, 2 for computer plays dark.
cnt__ai_selection: .byte $00

// BCC3
// Pre-game intro state ($80 = intro, $00 = in game, $ff = options).
flag__pregame_state: .byte $00

// BCC5
// The AI selection is used to generate a flag representing the side played by the AI.
// Is positive (55) for light, negative (AA) for dark, ($00) for neither or ($ff) for both.
// Both is selected after a selection timeout.
flag__ai_player_selection: .byte $00

// BCD0
// Is set to $80 to indicate that the game state should be changed to the next state.
flag__enable_next_state: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCD4
// Low byte pointer to sprite frame source data.
ptr__sprite_source_lo_list: .byte $00, $00, $00, $00

// BCD8
// High byte pointer to sprite frame source data.
ptr__sprite_source_hi_list: .byte $00, $00, $00, $00

// BCDF
// Number of bytes to copy for the given sprite.
param__sprite_source_size: .byte $00

// BCE3
// Initial animation for up to 4 sprites.
param__sprite_source_frame: .byte $00, $00, $00, $00

// BCE7
// Current animation frame.
cnt__curr_sprite_frame: .byte $00, $00, $00, $00 // TODO: look at moving this?

// BCE8
// Delay between color changes when color scrolling avatar sprites.
cnt__curr_sprite_delay: .byte $00

// BD3E
// Current sprite x-position.
pos__sprite_x_list: .byte $00, $00, $00, $00, $00, $00, $00, $00 // TODO: look at moving this?

// BD46
// Current sprite y-position.
pos__sprite_y_list: .byte $00, $00, $00, $00, $00, $00, $00, $00 // TODO: look at moving this?

// BD66
// Function pointer to retrieve a note for the current voice.
prt__voice_note_fn: .word $0000

// BF08
// Pointer to function to read current pattern for current voice.
prt__voice_pattern_data: .word $0000

// BF08
// Set to non zero to enable the voice for each player (lo byte is player 1, hi player 2).
flag__enable_player_sound: .byte $00, $00

// BF0B
// New note delay timer.
data__voice_note_delay: .byte $00, $00, $00

// BF1A
// Temporary data storage area used for sprite manipulation.
data__temp_storage: .byte $00, $00, $00, $00, $00, $00

// BF23
// Low byte of current sprite memory location pointer. Used to increment to next sprite pointer location (by adding 64
// bytes) when adding chasing icon sprites.
ptr__sprite_mem_lo: .byte $00

// BF24
// Frame offset of sprite icon set. Add #$80 to invert the frame on copy.
data__icon_set_sprite_frame: .byte $00

// BF29
idx__icon_offset: .byte $00, $00, $00, $00 // Icon sprite group offset used to determine which sprite to copy

// BF2D
data__icon_type: .byte $00, $00, $00, $00 // Type of icon (See `icon types` constants)

// BF49
// Set #$80 to copy individual icon frame in to graphical memory.
param__is_copy_animation_group: .byte $00

// BF4A
// Current note delay countdown.
cnt__voice_note_delay: .byte $00, $00, $00

// BF4D
// Current voice control value.
data__voice_control: .byte $00, $00, $00

// BF50
// Is 00 for title music and 80 for game end music.
param__is_play_outro: .byte $00
