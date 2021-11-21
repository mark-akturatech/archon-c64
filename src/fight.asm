.filenamespace fight

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for playiong the game.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Game

// 7ACE
entry:
    rts

// 938d
interrupt_handler: // Could be wrong here. This could maybe be fight handler??
    jmp common.complete_interrupt // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
