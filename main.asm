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
//------------------------------------------------------s---------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.file [name="main.prg", segments="Upstart, Main, Common, Intro, Data, Assets"]

.segmentdef Upstart
.segmentdef Main [startAfter="Upstart"]
.segmentdef Common [startAfter="Main"]
.segmentdef Intro [startAfter="Common"]
.segmentdef Data [startAfter="Intro"]
.segmentdef Assets [startAfter="Data", align=$100]

#import "src/common.asm"
#import "src/unofficial.asm"
#if INCLUDE_INTRO 
    #import "src/intro.asm"
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

// 6126
entry:
    jsr prep
    jsr init
    jsr common.stop_sound
    jsr common.clear_screen
    jsr common.clear_sprites
    not_original: {
        jsr unofficial.import_charsets
    }
#if INCLUDE_INTRO    
    jsr intro.entry
#endif
    rts

// 4700
prep:
    // Store system interrupt handler pointer so we can call it from our own interrupt handler.
    lda CINV
    sta interruptPtr.raster
    lda CINV+1
    sta interruptPtr.raster+1
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
    sta interruptPtr.system
    lda #>common.complete_interrupt
    sta interruptPtr.system+1
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
    // reenable raster interrupts
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
    jmp  (interruptPtr.system)   
!next:
    jmp  (interruptPtr.raster) 

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// interrupt handler pointers
.namespace interruptPtr {
    // BCCC
    system: .word $0000 // system interrupt handler
    // BCCE
    raster: .word $0000 // raster interrupt handler
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace charset {
#if INCLUDE_INTRO    
    intro: .import binary "/assets/charset-intro.bin"
#endif
#if INCLUDE_GAME
    game: .import binary "/assets/charset-game.bin"
#endif
}
