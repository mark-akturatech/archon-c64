.filenamespace main

//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Archon (c) 1983
//
// Reverse engineer of C64 Archon (c) 1983 by Free Fall Associates.
//
// Full resepct to the original authors:
// - Anne Westfall, Jon Freeman, Paul Reiche III
//
// THANK YOU FOR MANY YEARS OF MEMORABLE GAMING. ARCHON ROCKS AND ALWAYS WILL!!!
//---------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.file [name="main.prg", segments="Upstart, Main, Common, Intro, Assets"]

.segmentdef Upstart
.segmentdef Main [startAfter="Upstart"]
.segmentdef Common [startAfter="Main"]
.segmentdef Intro [startAfter="Common"]
.segmentdef Board [startAfter="Intro"]
.segmentdef Game [startAfter="Board"]
.segmentdef Assets [startAfter="Game", align=$100]
//
.segmentdef DataStart [startAfter="Assets", virtual]
.segmentdef Data [startAfter="DataStart", virtual]
.segmentdef DataEnd [startAfter="Data", max=$7fff, virtual]

#import "src/common.asm"
#import "src/not-original.asm"
#if INCLUDE_INTRO 
    #import "src/intro.asm"
    #import "src/board.asm"
#endif
#if INCLUDE_GAME
    #import "src/game.asm"
#endif

//---------------------------------------------------------------------------------------------------------------------
// Basic Upstart
//---------------------------------------------------------------------------------------------------------------------
// create basic program with sys command to execute code
.segment Upstart
BasicUpstart2(entry)

//---------------------------------------------------------------------------------------------------------------------
// Entry
//---------------------------------------------------------------------------------------------------------------------
.segment Main

// 6100
entry:
    // Load in character sets (done in 0x100 copy code in original source).
    not_original: {
        // character sets are loaded in some of the copy/move routines in 0100-01ff
        jsr notOriginal.import_charsets
        jsr notOriginal.clear_variable_space
    }

    // 6100  A9 00      lda  #$00       // TODO: what are these variables           
    // 6102  8D C0 BC   sta  WBCC0                 
    // 6105  8D C1 BC   sta  WBCC1                 
    // 6108  8D C5 BC   sta  WBCC5                 
    // 610B  A9 55      lda  #$55                  
    // 610D  8D C2 BC   sta  WBCC2                 
    tsx
    stx stack_ptr_store
    // 6114  A9 80      lda  #$80      // TODO: what are these variables
    // 6116  8D D1 BC   sta  WBCD1                 
    // 6119  8D C3 BC   sta  WBCC3                 
    // 611C  A9 03      lda  #$03                  
    // 611E  8D CB BC   sta  WBCCB                 
    lda INITIALIZED
    bmi skip_prep
    jsr prep
skip_prep:
    jsr init
    ldx stack_ptr_store
    txs
    // skip 612c to 612f as this resets the stack pointer back after the decryption/move logic has played with it.
    jsr common.stop_sound
    // skip 6133 to 6148 as it clears variable area. this is needed due to app relocating code on load. we don't need
    // this.
    jsr common.clear_screen
    jsr common.clear_sprites
    // skip 6150 to 618A as it moves more stuff around. not too sure why yet.
    lda #>COLRAM
    sec
    sbc #>SCNMEM
    sta screen.color_mem_offset
    // skip 6193 to 6219 as it moves more stuff around. not too sure why yet.
    lda #$80
    sta state.current
    // 621F  A2 50      ldx  #$50               // TODO: what are these variables       
    // W6221:
    // 6221  9D 7C BD   sta  WBD7C,x               
    // 6224  CA         dex                        
    // 6225  10 FA      bpl  W6221                 
    // 6227  8D 24 BD   sta  WBD24                 
    // 622A  8D 25 BD   sta  WBD25                 
    // 622D  AD C2 BC   lda  WBCC2                 
    // W6230:
    // 6230  8D C6 BC   sta  WBCC6                 
    // 6233  A0 03      ldy  #$03                  
    // 6235  B9 D2 8B   lda  W8BD2,y               
    // 6238  8D 11 BD   sta  WBD11                 
    // 623B  AD D1 BC   lda  WBCD1
    jsr play_intro
    rts

// 4700
prep:
    // Indicate that we have initialised the app, so we no don't need to run `prep` again if the app is restarted.
    lda #$80
    sta INITIALIZED
    // Store system interrupt handler pointer so we can call it from our own interrupt handler.
    lda CINV
    sta interrupt.raster_fn_ptr
    lda CINV+1
    sta interrupt.raster_fn_ptr+1
    // skip 4711-475F - moves stuff around. we'll just set any intiial values in our assets segment.
main_prep_game_states:
    // Configure game state function handlers.
    ldx  #$05                         
!loop:
    lda  state.game_fn_ptr,x                      
    sta  STATE_PTR,x                 
    dex                               
    bpl  !loop-
    rts

// 632D
init:
    // Not sure why yet - allows writing of ATTN and TXD on serial port.
    // I think this is done to allow us to use the serial port zero page registers for creating zero page loops maybe.
    lda C2DDRA
    ora #%0000_0011
    sta C2DDRA

    // Set VIC memory bank.
    // Original code uses Bank #1 ($4000-$7FFF).
    //
    // Graphic assets are stores as follows (offsets shown):
    //
    //   0000 -+- intro character set
    //   ...   |
    //   ...   |   0400 -+- screen memory
    //   ...   |   ...   |
    //   ...   |   07ef7 +
    //   ...   |   07ef8 +- sprite location memory
    //   ...   |   ...   |
    //   07ff -+   07eff +
    //   0800 -+- board character set
    //   ...   |
    //   ...   |
    //   0fff -+
    //   1000 -+- sprite memory (or 2000 for bank 0 and 2 as these banks copy the default charset in to 1000)
    //   ...   |
    //   ...   |
    //   2000 -+    
    //
    // As can be seen, the screen memory overlaps the first character set. this is OK as the first character set
    // contains lower case only characters and therefore occupies only half of the memory of a full character set.
    //
    // NOTE:
    // Set the `videoBank` register in the `const.asm` file to set the source video bank. For this relacatable source,
    // we have choses Bank #2 as this gives us more room to store code in the basic area so that we don't need to
    // move code around after load.
    lda CI2PRA
    and #%1111_1100
    ora #VICBANK
    sta CI2PRA

    // Set text mode character memory to $0800-$0FFF (+VIC bank offset as set in CI2PRA).
    // Set character dot data to $0400-$07FF (+VIC bank offset as set in CI2PRA).
    lda #%0001_0010
    sta VMCSB

    // set RAM visible at $A000-$BFFF.
    lda R6510
    and #%1111_1110
    sta R6510

    // Configure interrupt handler routines
    // The interrupt handler calls the standard system interrupt if a raster interrupt is detected. this is used to
    // draw the screen. otherwise it calls a minimlaist interrupt routine presumably for optimization.
    // To set the interrupts, we need to disable interrupts, configure the interrupt call pointers, stop raster scan
    // interrupts and then point the interrupt handler away from the system handler to our new handler. We can then
    // re-enable scan interupts and exit.
    sei
    lda #<common.complete_interrupt
    sta interrupt.system_fn_ptr
    lda #>common.complete_interrupt
    sta interrupt.system_fn_ptr+1
    lda IRQMASK
    and #%0111_1110
    sta IRQMASK
    // Set interrupt handler.
    lda #<interrupt_interceptor
    sta CINV
    sta CBINV
    lda #>interrupt_interceptor
    sta CINV+1
    sta CBINV+1
    // Set raster line used to trigger on raster interrupt.
    // As there are 262 lines, the line number is set by setting the highest bit of $D011 and the 8 bits in $D012.
    lda SCROLY
    and #%0111_1111
    sta SCROLY
    lda #251
    sta RASTER
    // Reenable raster interrupts.
    lda IRQMASK
    ora #%1000_0001
    sta IRQMASK
    cli
    rts

// 637E
// Call our interrupt handlers.
// We call a different handler if the interrupt was triggered by a raster line compare event.
interrupt_interceptor:
    lda  VICIRQ    
    and  #%0000_0001
    beq  !next+
    sta  VICIRQ
    jmp  (interrupt.system_fn_ptr)   
!next:
    jmp  (interrupt.raster_fn_ptr) 

// 8010
play_game:
    jmp  (STATE_PTR)

// 8016
play_board_setup:
    jmp  (STATE_PTR+2)

// 8016
play_intro:
    jmp  (STATE_PTR+4)

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace state {
    // 4760
    game_fn_ptr: // Pointer to each main game function (intro, board, game)
#if INCLUDE_GAME
        .word game.entry // TODO: this could be wrong
#else
        .word notOriginal.empty_sub
#endif
#if INCLUDE_INTRO
        .word board.entry // TODO: this could be wrong
        .word intro.entry
#else
        .word notOriginal.empty_sub
        .word notOriginal.empty_sub
#endif
}

.namespace math {
    // 8DC3
    pow2: .byte $01, $02, $04, $08, $10, $20, $40, $80 // Pre-calculated powers of 2
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC4
stack_ptr_store: .byte $00 

.namespace interrupt {
    // BCCC
    system_fn_ptr: .word $0000 // System interrupt handler function pointer

    // BCCE
    raster_fn_ptr: .word $0000 // Raster interrupt handler function pointer
}

.namespace state {
    // BCC7
    counter: .byte $00 // State counter (increments after each state change)

    // BCD0
    current: .byte $00 // Current game state

    // BCD3 
    new: .byte $00 // New game state (set to trigger a state change to this new state)

    // BD30
    current_fn_ptr: .word $0000 // Pointer to code that will run in the current state
}

.namespace screen {
    // BF19
    color_mem_offset: .byte $00 // Screen offset to color ram
}

// Memory addresses used for multiple purposes. Each purpose has it's own label and label description for in-code
// readbility.
.namespace temp {
    // BF1A
    data__curr_color: // Color of the current intro string being rendered
        .byte $00

    // BF1B
    ptr__sprite: // Intro sprite data pointer
        .byte $00

    // BF22
    flag__sprites_initialized: // Is TRUE if intro character sprites are initialized
         .byte $00
        
    // BF30
    data__curr_line: // Current screen line used while rendering repeated strings in into page
        .byte $00
    
    // BD3A
    data__msg_offset: // Offset of current message being rendered in into page
        .byte $00

    // BF3C
    flag__string_control: // Used to control string rendering in intro page
        .byte $00
}
