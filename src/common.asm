.filenamespace common

//---------------------------------------------------------------------------------------------------------------------
// Contains common routines used by various pages and game states.
//---------------------------------------------------------------------------------------------------------------------
#importonce
#import "src/io.asm"
#import "src/const.asm"

.segment Common

// Complete the current interrupt by restoring the registers pushed on to the stack by the interrupt.
complete_interrupt: //638E
    pla
    tay
    pla
    tax
    pla
    rti

// Stop sound from playing on all 3 voices.
stop_sound: // 7FAB
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

// Clear the video graphics area.
clear_sprites: // 8DD3
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

// Clear the video screen area.
// Loads $00 to the video matrix SCNMEM to SCNMEM+$3E7.
clear_screen: // 9333
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
