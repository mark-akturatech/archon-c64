.filenamespace challenge

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for challenge battles.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Game

// 7ACE
entry:
    rts

// 938d
interrupt_handler: // Could be wrong here. This could maybe be challenge handler??
    jmp common.complete_interrupt // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
