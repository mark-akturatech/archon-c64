.filenamespace common

//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used by various pages and game states.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

.segment Common

// 638E
// Complete the current interrupt by restoring the registers pushed on to the stack by the interrupt.
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
    lda  LSTX
    cmp  #KEY_NONE
    bne  process_key
    rts
    // TODO: see 639b
process_key:
    rts

// 677C
// Detect if break/q key is pressed.
check_stop_keypess: 
    // go to next state of ESC
    jsr  STOP
    beq  !next+
    cmp  #KEY_Q 
    bne  !return+
    // Wait for key to be released.
!loop: 
    jsr  STOP
    cmp  #KEY_Q
    beq  !loop-
    //... TODO: jump to options state - JSR $63F3; JMP $612C. see 678c
    rts // todo remove
// 6792
!next:
    lda  main.state.new
    eor  #$ff
    sta  main.state.new
!loop:
    jsr  STOP
    beq  !loop-
!return:
    rts

// 7FAB
// Stop sound from playing on all 3 voices.
stop_sound:
    ldx  #$01                         
!loop:
    txa                               
    asl                               
    tay                               
    lda  sound.voice_io_addr,y   
    sta  FREEZP+2                  
    lda  sound.voice_io_addr+1,y 
    sta  FREEZP+3                  
    ldy  #$04                         
    lda  #$00                         
    sta  (FREEZP+2),y              
    sta  sound.current_phrase_data_fn_ptr,x 
    sta  sound.new_note_delay,x 
    dex                               
    bpl  !loop-                        
    rts     

// 8DD3
// Clear the video graphics area.
clear_sprites:
    lda  #<GRPMEM
    sta  FREEZP+2
    lda  #>GRPMEM
    sta  FREEZP+3
    ldx  #$10 // 16x256 = 4096kb
    lda  #$00
    tay
!loop:
    sta  (FREEZP+2),y
    iny
    bne  !loop-
    inc  FREEZP+3
    dex 
    bne  !loop-
    // reset sprite positions
    ldx  #$07
    sta  MSIGX
!loop:
    sta  SP0X,x
    dex
    bpl  !loop-
    rts

// 905C
// Busy wait for STOP, game options (function keys) or Q keypress or game state change.
wait_for_key:
    lda  #$00
    sta  main.state.current
!loop:
    jsr  check_option_keypress
    jsr  check_stop_keypess
    lda  main.state.current
    beq  !loop-
    jmp  stop_sound

// 9333
// Clear the video screen area.
// Loads $00 to the video matrix SCNMEM to SCNMEM+$3E7.
clear_screen:
    lda  #<SCNMEM                        
    sta  FREEZP+2                  
    lda  #>SCNMEM                     
    sta  FREEZP+3                  
    ldx  #$03                         
    lda  #$00                         
    tay                               
!loop:
    sta  (FREEZP+2),y              
    iny                               
    bne  !loop-
    inc  FREEZP+3                  
    dex                               
    bne  !loop-                        
!loop:
    sta  (FREEZP+2),y              
    iny                               
    cpy  #$E8                         
    bcc  !loop-
    rts   
   
// AC16
// Read music from the music phrase command list and play notes or execute special commands.
// Commands are separated by notes and begin with a special code as follows:
// - 00: stop current note
// - 01-F9: Plays a note (of given note value)
// - FB: Set delay - next number in phrase is the delay time.
// - FC: Set early filter gate release (release gate but continue delay).
// - FD: Set game state (synch state with certain points in the music).
// - FE: End phrase - move to next phrase in the phrase list.
// - FF: End music.
// See `initialize_music` for further details of how music and phrases are stored.
// Note that this sub is called each time an interrupt occurs. It runs once and processes notes/command on each voice,
// increments the pointer to the next command/note and then exits.
play_music:
    ldx  #$02                         
!loop:
    txa                               
    asl                               
    tay                               
    lda  sound.note_data_fn_ptr,y           
    sta  sound.current_note_data_fn_ptr     
    lda  sound.note_data_fn_ptr+1,y          
    sta  sound.current_note_data_fn_ptr+1
    lda  sound.voice_io_addr,y   
    sta  FREEZP+2                  
    lda  sound.voice_io_addr+1,y        
    sta  FREEZP+3                  
    lda  sound.phrase_data_fn_ptr,y   
    sta  sound.current_phrase_data_fn_ptr                     
    lda  sound.phrase_data_fn_ptr+1,y   
    sta  sound.current_phrase_data_fn_ptr+1
    //
    lda  sound.note_delay_counter,x 
    beq  delay_done
    cmp  #$02                         
    bne  decrease_delay
    // Release note just before delay expires.
    lda  sound.current_control,x
    and  #$FE                         
    ldy  #$04                         
    sta  (FREEZP+2),y              
decrease_delay:
    dec  sound.note_delay_counter,x 
    bne  skip_command                        
delay_done:
    jsr  get_next_command                        
skip_command:
    dex                               
    bpl  !loop-
    rts     

// AC5B
// Reads a command from the current phrase data. Commands can be notes or special commands. See `play_music` for
// details.
.enum {
    CMD_STOP_NOTE=$00, 
    CMD_SET_DELAY=$fb, 
    CMD_RELEASE_NOTE=$fc, 
    CMD_NEXT_STATE=$fd,
    CMD_NEXT_PHRASE=$fe,
    CMD_END=$ff
}
get_next_command:
    jsr get_note
    cmp #CMD_END // Stop voice
    bne !next+
    // Reset voice.
    ldy #$04
    lda #$00
    sta (FREEZP+2),y // FREEZP+2 is ptr to base SID control address for current voice
    rts
!next:
    cmp #CMD_NEXT_PHRASE // Phrase finished - load next phrase
    bne !next+
    jsr get_next_phrase
    jmp get_next_command
!next:
    cmp #CMD_NEXT_STATE // Set next into animation state
    beq set_state
    cmp #CMD_SET_DELAY // Set delay
    beq set_delay
    cmp #CMD_STOP_NOTE // Stop note
    beq clear_note
    cmp #CMD_RELEASE_NOTE // Release note
    beq release_note
    // Play note - sets gate filter, loads the command in to voice hi frequency control, reads the next command and
    // then loads that in to the voice lo frequency control.
    pha
    ldy #$04
    lda sound.current_control,x
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
    lda main.state.counter
    inc main.state.counter
    asl
    tay
    lda intro.state.fn_ptr,y
    sta main.state.current_fn_ptr
    lda intro.state.fn_ptr+1,y               
    sta main.state.current_fn_ptr+1
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
    lda sound.current_control,x
    and #%1111_1110 // Start gate release on current note
    sta (FREEZP+2),y
set_note:
    ldy #$04
    lda sound.current_control,x // Set default note control value for voice
    sta (FREEZP+2),y 
!return:
    lda sound.new_note_delay,x
    sta sound.note_delay_counter,x
    rts

// A13E
// Read note from current music loop and increment the note pointer.
get_note: // Get note for current voice and increment note pointer
    ldy #$00
    jmp (sound.current_note_data_fn_ptr)
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
// Read a phrase for the current music loop and increment the phrase pointer.
get_next_phrase: // Get phrase for current voice and increment phrase pointer
    ldy #$00
    jmp (sound.current_phrase_data_fn_ptr)
// ACDFD
get_phrase_V1: // Get phrase for voice 1 and increment phrase pointer
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
get_phrase_V2: // Get phrase for voice 2 and increment phrase pointer
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
get_phrase_V3: // Get phrase for voice 3 and increment phrase pointer
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
// Initialize music and configure voices.
// Pointers are set to the start of each music phase. A phrase is part of a music sequence for single voice that can be
// repeated if necessary.
// Phrases hold notes, delays and commands for ending the phrase or setting a game state (modify how the intro displays
// matched to a music sequence).
// The method also sets pointers to a list of phrases for each voice. The song loop plays a phrase (terminated by FE)
// and then moves to the next phrase in the phrase list to read which phrase to play next.
// A final FF command tells the music loop that there are no more phrases.
// Super neat and efficient as repeated beats only need to be stored once. NICE!
// Note that this method handles both the intro and outro music. Both pieces start with the same phrases and end with
// the same terminating phrases. The otro just skips all the phrases in the middle. Kind of cheeky.
initialize_music:
    // Full volume.
    lda  #%0000_1111
    sta  SIGVOL

    // Configure music pointers.
    ldy  #$05   
!loop:
#if INCLUDE_GAME
    lda  sound.music_track_flag
    bpl  intro_music
    lda  music.outro_phrase_ptr,y
    jmp  !next+
intro_music:
#endif
#if INCLUDE_INTRO
    lda  music.intro_phrase_ptr,y 
#endif
!next:
    sta  VARTAB,y        
    // Both intro and outro music start with the same initial phrase on all 3 voices.          
    lda  music.initial_phrase_list_ptr,y 
    sta  OLDTXT,y                  
    dey                               
    bpl  !loop-

    // Configure voices.
    ldx  #$02                         
!loop:
    lda  #$00                         
    sta  sound.note_delay_counter,x                      
    txa                               
    asl                               
    tay                               
    lda  sound.voice_io_addr,y   
    sta  FREEZP+2                  
    lda  sound.voice_io_addr+1,y 
    sta  FREEZP+3                  
    ldy  #$06                         
    lda  sound.sustain,x        
    sta  (FREEZP+2),y              
    lda  sound.control,x
    sta  sound.current_control,x        
    dey               
    lda  sound.attack,x         
    sta  (FREEZP+2),y              
    dex                               
    bpl  !loop-
    rts

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

.namespace sound {
    // BD66
    current_note_data_fn_ptr: .word $0000 // Pointer to function to read current note for current voice

    // BF08
    current_phrase_data_fn_ptr: .word $0000 // Pointer to function to read current phrase for current voice

    // BF0B
    new_note_delay: .byte $00, $00, $00 // New note delay timer

    // BF4A
    note_delay_counter: .byte $00, $00, $00 // Current note delay countdown

    // BF4D
    current_control: .byte $00, $00, $00 // Current voice control value

    // BF50
    music_track_flag: .byte $00 // Is 00 for title music and 80 for game end music
}

// BF1B
temp_data_ptr: .byte $00 // Sprite data pointer

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace sound {
    // A0A5
    note_data_fn_ptr: // Pointer to function to get note and incremement note pointer for each voice
        .word get_note_V1, get_note_V2, get_note_V3

    // A0AB
    voice_io_addr: .word FRELO1, FRELO2, FRELO3 // Address offsets for each SID voice control address

    // AD6A
    sustain: .byte $a3, $82, $07 // Voice sustain values

    // AD6D
    control: .byte $21, $21, $21 // Voice sustain values

    // AD70
    attack: .byte $07, $07, $07 // Voice attack values

    // AD7D
    phrase_data_fn_ptr: // Pointer to function to get phrase and incremement note pointer for each voice
        .word get_phrase_V1, get_phrase_V2, get_phrase_V3
}

// 3D40
.namespace music {
    // Music configuration.
    // Music is played by playing notes pointed to by `initial_phrase_list_ptr` on each voice.
    // When the voice phrase list finishes, the music will look at the intro or outro phrase list pointers (
    // `intro_phrase_ptr` or `outro_phrase_ptr`) depending on the track being played. This list will then tell the
    // player which phrase to play next.
    // When the phrase finishes, it looks at the next phrase in the list and continues until a FE command is reached.
#if INCLUDE_INTRO     
    intro_phrase_ptr: // Pointers for intro music phrase list for each voice
        .word intro_phrase_V1_ptr, intro_phrase_V2_ptr, intro_phrase_V3_ptr
#endif
    initial_phrase_list_ptr: // Initial phrases for both intro and outro music
        .word phrase_1, phrase_2, phrase_3
#if INCLUDE_GAME
    outro_phrase_ptr: // Pointers for outro music phrase list for each voice
        .word outro_phrase_V1_ptr, outro_phrase_V2_ptr, outro_phrase_V3_ptr
#endif

    // Music notes and commands.
    phrase_1: // Notes (00 to FA) and commands (FB to FF) for music phrase
        .byte $FB, $07, $11, $C3, $10, $C3, $0F, $D2, $0E, $EF, $11, $C3, $10, $C3, $0F, $D2 
        .byte $0E, $EF, $11, $C3, $10, $C3, $0F, $D2, $0E, $EF, $13, $EF, $15, $1F, $16, $60 
        .byte $17, $B5, $FE
    phrase_2:
        .byte $FB, $38, $00, $FB, $07, $0E, $18, $0D, $4E, $0C, $8F, $0B, $DA, $0B, $30, $0A 
        .byte $8F, $09, $F7, $09, $68, $FE
    phrase_3:
        .byte $FB, $1C, $00, $FB, $07, $0E, $18, $0D, $4E, $0C, $8F, $0B, $DA, $0B, $30, $0A 
        .byte $8F, $09, $F7, $09, $68, $08, $E1, $08, $61, $07, $E9, $07, $77, $FE
#if INCLUDE_INTRO
    phrase_4:
        .byte $FD, $FB, $70, $19, $1E, $FB, $38, $12, $D1, $FB, $1C, $15, $1F, $FB, $09, $12 
        .byte $D1, $11, $C3, $FB, $0A, $0E, $18, $FB, $E0, $1C, $31, $FE          
    phrase_5:
        .byte $FB, $70, $19, $3E, $FB, $38, $12, $E9, $FB, $1C, $15, $3A, $FB, $09, $12, $E9 
        .byte $11, $D9, $FB, $0A, $0E, $2A, $FB, $E0, $1C, $55, $FE               
    phrase_6:
        .byte $FB, $07
    phrase_7:
        .byte $07, $0C, $FC, $0A, $8F, $FC, $0E, $18, $FC, $0A, $8F, $FC, $FE     
    phrase_8:
        .byte $09, $68, $FC, $0E, $18, $FC, $12, $D1, $FC, $0E, $18, $FC, $FE     
    phrase_9:
        .byte $06, $47, $FC, $09, $68, $FC, $0C, $8F, $FC, $09, $68, $FC, $FE     
    phrase_10:
        .byte $FB, $07, $00, $00, $17, $B5, $FC, $1C, $31, $FC, $1F, $A5, $FC, $23, $86, $FC 
        .byte $1F, $A5, $FC, $1C, $31, $FC, $17, $B5, $FC, $1F, $A5, $FC, $17, $B5, $FC, $1C 
        .byte $31, $FC, $17, $B5, $FC, $11, $C3, $FC, $17, $B5, $FC, $0B, $DA, $FC, $11, $C3 
        .byte $FC, $00, $00, $19, $1E, $FC, $1F, $A5, $FC, $23, $86, $FC, $25, $A2, $FC, $23
        .byte $86, $FC, $1F, $A5, $FC, $19, $1E, $FC, $23, $86, $FC, $19, $1E, $FC, $1F, $A5
        .byte $FC, $19, $1E, $FC, $12, $D1, $FC, $19, $1E, $FC, $0C, $8F, $FC, $12, $D1, $FC          
    phrase_11:
        .byte $00, $00, $10, $C3, $11, $C3, $1C, $31, $1A, $9C, $16, $60, $17, $B5, $1A, $9C
        .byte $1C, $31, $1F, $A5, $21, $87, $23, $86, $1C, $31, $FB, $0E, $17, $B5, $FB, $07 
        .byte $FD, $FE
    phrase_12:
        .byte $FB, $07, $00, $00, $17, $D3, $FC, $1C, $55, $FC, $1F, $CD, $FC, $23, $B3, $FC 
        .byte $1F, $CD, $FC, $1C, $55, $FC, $17, $D3, $FC, $1F, $CD, $FC, $17, $D3, $FC, $1C 
        .byte $55, $FC, $17, $D3, $FC, $11, $D9, $FC, $17, $D3, $FC, $0B, $E9, $FC, $11, $D9 
        .byte $FC, $00, $00, $19, $3E, $FC, $1F, $CD, $FC, $23, $B3, $FC, $25, $D2, $FC, $23 
        .byte $B3, $FC, $1F, $CD, $FC, $19, $3E, $FC, $23, $B3, $FC, $19, $3E, $FC, $1F, $CD 
        .byte $FC, $19, $3E, $FC, $12, $E9, $FC, $19, $3E, $FC, $0C, $9F, $FC, $12, $E9, $FC 
    phrase_13:
        .byte $00, $00, $10, $D8, $11, $D9, $1C, $55, $1A, $BE, $16, $7C, $17, $D3, $1A, $BE 
        .byte $1C, $55, $1F, $CD, $21, $B1, $23, $86, $1C, $55, $FB, $0E, $17, $D3, $FB, $07 
        .byte $FE
    phrase_14:
        .byte $FB, $07                    
    phrase_15:
        .byte $05, $ED, $FC, $08, $E1, $FC, $0B, $DA, $FC, $08, $E1, $FC, $FE     
    phrase_16:
        .byte $06, $47, $FC, $09, $68, $FC, $0C, $8F, $FC, $09, $68, $FC, $FE     
    phrase_17:
        .byte $05, $ED, $FC, $08, $E1, $FC, $0B, $DA, $FC, $08, $E1, $FC, $FE     
    phrase_18:
        .byte $07, $E9, $FC, $0B, $DA, $FC, $0F, $D2, $FC, $0B, $DA, $FC, $FE     
#endif
    phrase_19:
        .byte $FB, $70, $19, $1E, $FF
    phrase_20:
        .byte $FB, $70, $0A, $8F, $FD, $FF
    phrase_21:
        .byte $FB, $70, $07, $0C, $FF

    // Music phraseology.
#if INCLUDE_INTRO 
    intro_phrase_V1_ptr: // Intro music voice 1 phrase list
        .word phrase_4, phrase_4, phrase_10, phrase_11, phrase_1
#endif
    outro_phrase_V1_ptr:
        .word phrase_19 // Outro music voice 1 phrase list
#if INCLUDE_INTRO          
    intro_phrase_V2_ptr: // Intro music voice 2 phrase list
        .word phrase_5, phrase_5, phrase_12, phrase_13, phrase_2
#endif
    outro_phrase_V2_ptr:
        .word phrase_21 // Outro music voice 2 phrase list
#if INCLUDE_INTRO      
    intro_phrase_V3_ptr: // Intro music voice 3 phrase list
        .word phrase_6, phrase_7, phrase_7, phrase_7, phrase_8, phrase_8, phrase_9, phrase_9
        .word phrase_6, phrase_7, phrase_7, phrase_7, phrase_8, phrase_8, phrase_9, phrase_9
        .word phrase_14, phrase_15, phrase_15, phrase_15, phrase_16, phrase_16, phrase_16, phrase_16
        .word phrase_17, phrase_17, phrase_18, phrase_18, phrase_3
#endif
    outro_phrase_V3_ptr:
        .word phrase_20 // Outro music voice 3 phrase list
}
