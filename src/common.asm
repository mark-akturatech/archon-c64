.filenamespace common

//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used by intro and game states.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

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
    lda options.flag__ai_player_ctl
    sta game.state.flag__ai_player_ctl
    jmp main.restart_game_loop
!next:
    cmp #KEY_F5
    bne !next+
    // Toggle first player.
    lda game.state.flag__is_first_player_light
    eor #$FF
    sta game.state.flag__is_first_player_light
    jsr advance_intro_state
    jmp main.restart_game_loop
!next:
    cmp #KEY_F3
    beq set_num_players
    rts
set_num_players:
    // Toggle between two players, player light, player dark
    lda options.cnt__ai_player_selection
    clc
    adc #$01 // Not sure why we just don't `inc` here instead of adding
    cmp #$03
    bcc !next+
    lda #$00
!next:
    sta options.cnt__ai_player_selection
    cmp #$00
    beq !next+
    // This just gets a flag that is 55 for light, AA for dark and 0 for no AI. The flag has two purposes: we can
    // use beq, bpl, bmi to test the tri-state and also 55 and AA are used to set the color used by the board border
    // to represent the current player.
    lda game.state.flag__is_first_player_light
    cmp options.flag__ai_player_ctl
    bne !next+
    eor #$FF
!next:
    sta game.state.flag__ai_player_ctl
    sta options.flag__ai_player_ctl
    jsr advance_intro_state
    jmp main.restart_game_loop

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
#if INCLUDE_INTRO    
    lda #FLAG_DISABLE
    sta intro.flag__enable
    sta intro.flag__exit_intro
#endif
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
    jmp main.restart_game_loop
!next:
#if INCLUDE_INTRO
    lda intro.flag__exit_intro
    eor #$FF
    sta intro.flag__exit_intro
#endif
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
    lda sound.voice_io_addr,y
    sta FREEZP+2
    lda sound.voice_io_addr+1,y
    sta FREEZP+3
    ldy #$04
    lda #$00
    sta (FREEZP+2),y
    sta sound.flag__enable_voice,x
    sta sound.new_note_delay,x
    dex
    bpl !loop-
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
    lda sprite.mem_ptr_56
    sta FREEZP+2
    lda sprite.mem_ptr_56+1
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
    lda sprite.mem_ptr_48
    sta FREEZP+2
    lda sprite.mem_ptr_48+1
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
    lda sprite.mem_ptr_24
    sta FREEZP+2
    lda sprite.mem_ptr_24+1
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
    lda sound.note_data_fn_ptr,y
    sta sound.voice_note_fn_ptr
    lda sound.note_data_fn_ptr+1,y
    sta sound.voice_note_fn_ptr+1
    lda sound.voice_io_addr,y
    sta FREEZP+2
    lda sound.voice_io_addr+1,y
    sta FREEZP+3
    lda sound.pattern_data_fn_ptr,y
    sta sound.curr_pattern_data_fn_ptr
    lda sound.pattern_data_fn_ptr+1,y
    sta sound.curr_pattern_data_fn_ptr+1
    //
    lda sound.note_delay_counter,x
    beq delay_done
    cmp #$02
    bne decrease_delay
    // Release note just before delay expires.
    lda sound.curr_voice_ctl,x
    and #%1111_1110
    ldy #$04
    sta (FREEZP+2),y
decrease_delay:
    dec sound.note_delay_counter,x
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
    lda sound.curr_voice_ctl,x
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
#if INCLUDE_INTRO
    lda intro.idx__substate_fn_ptr
    inc intro.idx__substate_fn_ptr
    asl
    tay
    lda intro.ptr__substate_fn_list,y
    sta intro.ptr__substate_fn
    lda intro.ptr__substate_fn_list+1,y
    sta intro.ptr__substate_fn+1
#else
    lda #FLAG_ENABLE
    sta common.flag__enable_next_state
#endif
    jmp get_next_command
clear_note:
    ldy #$04
    sta (FREEZP+2),y
    jmp !return+
set_delay:
    jsr get_note
    sta sound.new_note_delay,x
    jmp get_next_command
release_note:
    ldy #$04
    lda sound.curr_voice_ctl,x
    and #%1111_1110 // Start gate release on current note
    sta (FREEZP+2),y
set_note:
    ldy #$04
    lda sound.curr_voice_ctl,x // Set default note control value for voice
    sta (FREEZP+2),y
!return:
    lda sound.new_note_delay,x
    sta sound.note_delay_counter,x
    rts

// A13E
// Read note from current music loop and increment the note pointer.
get_note: // Get note for current voice and increment note pointer
    ldy #$00
    jmp (sound.voice_note_fn_ptr)

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
    jmp (sound.curr_pattern_data_fn_ptr)

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
    lda sound.flag__play_outro
    bpl intro_music
    lda resources.music.outro_pattern_ptr,y
    jmp !next+
intro_music:
#if INCLUDE_INTRO
    lda resources.music.intro_pattern_ptr,y
#endif
!next:
    sta VARTAB,y
    // Both intro and outro music start with the same initial pattern on all 3 voices.
    lda resources.music.init_pattern_list_ptr,y
    sta OLDTXT,y
    dey
    bpl !loop-
    // Configure voices.
    ldx #$02
!loop:
    lda #$00
    sta sound.note_delay_counter,x
    txa
    asl
    tay
    lda sound.voice_io_addr,y
    sta FREEZP+2
    lda sound.voice_io_addr+1,y
    sta FREEZP+3
    ldy #$06
    lda sound.sustain,x
    sta (FREEZP+2),y
    lda sound.control,x
    sta sound.curr_voice_ctl,x
    dey
    lda sound.attack,x
    sta (FREEZP+2),y
    dex
    bpl !loop-
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace math {
    // 8DC3
    pow2: .fill 8, pow(2, i) // Pre-calculated powers of 2
}

.namespace sprite {
    // 8DBF
    offset_00: .byte (VICGOFF/BYTES_PER_SPRITE)+00 // Sprite 0 screen pointer

    // 8DC0
    offset_24: .byte (VICGOFF/BYTES_PER_SPRITE)+24 // Sprite 24 screen pointer

    // 8DC1
    offset_48: .byte (VICGOFF/BYTES_PER_SPRITE)+48 // Sprite 48 screen pointer

    // 8DC2
    offset_56: .byte (VICGOFF/BYTES_PER_SPRITE)+56 // Sprite 56 screen pointer

    // 8DCB
    mem_ptr_00: // Pointer to sprite 0 graphic memory area
        .byte <(GRPMEM+00*BYTES_PER_SPRITE), >(GRPMEM+00*BYTES_PER_SPRITE)

    // 8DCD
    mem_ptr_24: // Pointer to sprite 24 (dec) graphic memory area
        .byte <(GRPMEM+24*BYTES_PER_SPRITE), >(GRPMEM+24*BYTES_PER_SPRITE)

    // 8DCF
    mem_ptr_48: // Pointer to sprite 48 (dec) graphic memory area
        .byte <(GRPMEM+48*BYTES_PER_SPRITE), >(GRPMEM+48*BYTES_PER_SPRITE)

    // 8DD1
    mem_ptr_56: // Pointer to sprite 56 (dec) graphic memory area
        .byte <(GRPMEM+56*BYTES_PER_SPRITE), >(GRPMEM+56*BYTES_PER_SPRITE)
}

.namespace screen {
    // BF19
    color_mem_offset: .byte >(COLRAM-SCNMEM) // Screen offset to color ram
}

.namespace sound {
    // A0A5
    note_data_fn_ptr: // Pointer to function to get note and incremement note pointer for each voice
        .word get_note_V1, get_note_V2, get_note_V3

    // A0AB
    voice_io_addr: .word FRELO1, FRELO2, FRELO3 // Address offsets for each SID voice control address

    // AD6A
    sustain: .byte $a3, $82, $07 // Voice sustain values

    // AD6D
    control: .byte $21, $21, $21 // Voice control values

    // AD70
    attack: .byte $07, $07, $07 // Voice attack values

    // AD7D
    pattern_data_fn_ptr: // Pointer to function to get pattern and incremement note pointer for each voice
        .word get_pattern_V1, get_pattern_V2, get_pattern_V3
}

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

.namespace options {
    // BCC1
    // Temporary AI selection flag. Is incremented when AI option is selected up to $02 before wrapping back to $00.
    // Is 0 for none, 1 for computer plays light, 2 for computer plays dark.
    cnt__ai_player_selection: .byte $00

    // BCC5
    // The AI selection is used to generate a flag representing the side played by the AI.
    // Is positive (55) for light, negative (AA) for dark, ($00) for neither or ($ff) for both.
    // Both is selected after a selection timeout.
    flag__ai_player_ctl: .byte $00
}

// BCD0
// Is set to $80 to indicate that the game state should be changed to the next state.
flag__enable_next_state: .byte $00
    
// BCC3
// Pre-game intro state ($80 = intro, $00 = in game, $ff = options).
flag__pregame_state: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

.namespace sprite {
    // BCE3
    init_animation_frame: .byte $00, $00, $00, $00 // Initial animation for up to 4 sprites

    // BCE7
    // Current animation frame.
    curr_animation_frame: .byte $00

    // BCE8
    // Delay between color changes when color scrolling avatar sprites
    animation_delay: .byte $00

    // BCE9
    // Number of moves left in y plane in current direction (will reverse direction on 0)
    y_move_counter: .byte $00

    // BCEA
    // Number of moves left in x plane in current direction (will reverse direction on 0)
    x_move_counter: .byte $00

    // BD15
    // Final set position of sprites after completion of animation.
    final_y_pos: .byte $00, $00

    // BD3E
    // Current sprite x-position.
    curr_x_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00

    // BD46
    // Current sprite y-position.
    curr_y_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00
}

.namespace sound {
    // BD66
    // Function pointer to retrieve a note for the current voice. 
    voice_note_fn_ptr: .word $0000

    // BF08
    // Pointer to function to read current pattern for current voice.
    curr_pattern_data_fn_ptr: .word $0000
    
    // BF08
    // Set to non zero to enable the voice for each player (lo byte is player 1, hi player 2).
    flag__enable_voice: .byte $00, $00

    // BF0B
    // New note delay timer.
    new_note_delay: .byte $00, $00, $00

    // BF4A
    // Current note delay countdown.
    note_delay_counter: .byte $00, $00, $00

    // BF4D
    // Current voice control value.
    curr_voice_ctl: .byte $00, $00, $00

    // BF50
    // Is 00 for title music and 80 for game end music.
    flag__play_outro: .byte $00
}
