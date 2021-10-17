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
    lda LSTX
    cmp #KEY_NONE
    bne process_key
    rts
    // TODO: see 639b
process_key:
    rts

// 677C
// Detect if break/q key is pressed.
check_stop_keypess: 
    // go to next state of ESC
    jsr STOP
    beq !next+
    cmp #KEY_Q 
    bne !return+
    // Wait for key to be released.
!loop: 
    jsr STOP
    cmp #KEY_Q
    beq !loop-
    //... TODO: jump to options state - JSR $63F3; JMP $612C. see 678c
    rts // todo remove
!next:
    lda state.new
    eor #$ff
    sta state.new
!loop:
    jsr STOP
    beq !loop-
!return:

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
    // sta  WBF08,x                      // TODO
    // sta  WBF0B,x                      // TODO
    dex                               
    bpl  !loop-                        
    rts     

// 8DD3
// Clear the video graphics area.
clear_sprites:
    lda #<GRPMEM
    sta FREEZP+2
    lda #>GRPMEM
    sta FREEZP+3
    ldx #$10
    lda #$00
    tay
!loop:
    sta (FREEZP+2), y
    iny
    bne !loop-
    inc FREEZP+3
    dex 
    bne !loop-
    // reset sprite positions
    ldx #$07
    sta MSIGX
!loop:
    sta SP0X, x
    dex
    bpl !loop-
    rts

// 905C
// Busy wait for STOP, game options (function keys) or Q keypress or game state change.
wait_for_key:
    lda #$00
    sta state.current
!loop:
    jsr check_option_keypress
    jsr check_stop_keypess
    lda state.current
    beq !loop-
    jmp stop_sound

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

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

.namespace sound {
    // A0AB
    voice_io_addr: .word FRELO1, FRELO2, FRELO3 // address offsets for each SID voice control address
}

.namespace state {
    // BCC7
    counter: .byte $00 // state counter (increments after each state change)

    // BCD0
    current: .byte $00 // current game state

    // BCD3 
    new: .byte $00 // new game state (set to trigger a state change to this new state)

    // BD30
    function_ptr: .word $0000 // pointer to code that will run in the current state
}
