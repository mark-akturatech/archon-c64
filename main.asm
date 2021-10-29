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

.file [name="main.prg", segments="Upstart, Main, Common, Intro, BoardWalk, Game, Assets"]
.segmentdef Upstart
.segmentdef Main [startAfter="Upstart"]
.segmentdef Common [startAfter="Main"]
.segmentdef Intro [startAfter="Common"]
.segmentdef BoardWalk [startAfter="Intro"]
.segmentdef Game [startAfter="BoardWalk"]
.segmentdef Assets [startAfter="Game", align=$100]
//
.segmentdef DataStart [startAfter="Assets", virtual]
.segmentdef Data [startAfter="DataStart", virtual]
.segmentdef DataEnd [startAfter="Data", max=$7fff, virtual]

#import "src/common.asm"
#import "src/board.asm"
#import "src/not_original.asm"
#if INCLUDE_INTRO
    #import "src/intro.asm"
    #import "src/board_walk.asm"
#endif
#import "src/game.asm"

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
    // Load in character sets.
    // Character sets are loaded in some of the copy/move routines in 0100-01ff.
    jsr not_original.import_charsets
    jsr not_original.clear_variable_space

    // 6100  A9 00      lda #$00       // TODO: what are these variables
    // 6102  8D C0 BC sta WBCC0
    // 6105  8D C1 BC sta WBCC1      // players -> 2, light, dark
    // 6108  8D C5 BC sta WBCC5
    lda #$55 // Set light as first player
    sta board.flag__first_player
    tsx
    stx stack_ptr_store
    lda #$80
    sta state.flag_play_intro // Non zero to play intro, $00 to skip
    sta state.flag_setup_progress // Flag used by keycheck routine to test for run/stop or Q (if set)
    lda #$03
    sta state.NFI_001
    lda INITIALIZED
    bmi skip_prep
    jsr prep
skip_prep:
    jsr init
restart_game_loop:
    ldx stack_ptr_store
    txs
    // skip 612c to 612f as this resets the stack pointer back after the decryption/move logic has played with it.
    jsr common.stop_sound
    // skip 6133 to 6148 as it clears variable area. this is needed due to app relocating code on load. we don't need
    // this.
    jsr common.clear_screen
    jsr common.clear_sprites
    // skip 6150 to 618A as it moves more stuff around. not too sure why yet.
    // 618B
    lda #>COLRAM
    sec
    sbc #>SCNMEM
    sta screen.color_mem_offset
    // skip 6193 to 6219 as it moves more stuff around. not too sure why yet.
    lda #$80
    sta state.flag_update
    // Clear board square occupancy data.
    ldx #$50 // Empty 81 (9x9 grid) squares
!loop:
    sta board.square_occupant_data,x
    dex
    bpl !loop-
    // 6227  8D 24 BD sta WBD24  // TODO: what are these variables?
    // 622A 8D 25 BD sta WBD25
    lda board.flag__first_player
    sta board.flag__current_player
    // Set default board phase color.
    ldy #$03
    lda board.board_data.color_phase_data,y
    sta board.curr_color_phase
    lda state.flag_play_intro
    beq skip_intro
    jsr play_intro
skip_intro:
    // Configure SID for main game.
    lda #$08
    sta PWHI1
    sta PWHI2
    lda #$40
    sta FRELO3
    lda #$0A
    sta FREHI3
    lda #%1000_0001 // Confiugre voice 3 as noise waveform
    sta VCREG3
    lda #%1000_1111 // Turn off voice 3 and keep full volume on other voices
    sta SIGVOL
    // Set text mode character memory to $0800-$0FFF (+VIC bank offset as set in CI2PRA).
    // Set character dot data to $0400-$07FF (+VIC bank offset as set in CI2PRA).
    lda #%0001_0010
    sta VMCSB
    // Enable multicolor text mode.
    lda SCROLX
    ora #%0001_0000
    sta SCROLX
    //
    lda state.flag_play_intro
    beq skip_board_walk
    jsr board_walk.entry
skip_board_walk:
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
    ldx #$05
!loop:
    lda state.game_fn_ptr,x
    sta STATE_PTR,x
    dex
    bpl !loop-
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
    lda VICIRQ
    and #%0000_0001
    beq !next+
    sta VICIRQ
    jmp (interrupt.system_fn_ptr)
!next:
    jmp (interrupt.raster_fn_ptr)

// 8010
play_game:
    jmp (STATE_PTR)

// 8013
play_board_setup:
    jmp (STATE_PTR+2)

// 8016
play_intro:
    jmp (STATE_PTR+4)

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace state {
    // 4760
    game_fn_ptr: // Pointer to each main game function (intro, board, game)
        .word game.entry // TODO: this could be wrong
#if INCLUDE_INTRO
        .word board_walk.entry // TODO: this could be wrong
        .word intro.entry
#else
        .word not_original.empty_sub
        .word not_original.empty_sub
#endif
}

.namespace math {
    // 8DC3
    pow2: .fill 8, pow(2, i) // Pre-calculated powers of 2
}

.namespace sprite {
    // 8DBF
    _00_screen_ptr: .byte (VICGOFF / BYTES_PER_SPRITE) + 00 // Sprite 0 screen pointer

    // 8DC0
    _24_screen_ptr: .byte (VICGOFF / BYTES_PER_SPRITE) + 24 // Sprite 24 screen pointer

    // 8DC1
    _48_screen_ptr: .byte (VICGOFF / BYTES_PER_SPRITE) + 48 // Sprite 48 screen pointer

    // 8DC2
    _56_screen_ptr: .byte (VICGOFF / BYTES_PER_SPRITE) + 56 // Sprite 56 screen pointer

    // 8DCB
    _00_memory_ptr: // Pointer to sprite 0 graphic memory area
        .byte <(GRPMEM + 00 * BYTES_PER_SPRITE), >(GRPMEM + 00 * BYTES_PER_SPRITE)

    // 8DCD
    _24_memory_ptr: // Pointer to sprite 24 (dec) graphic memory area
        .byte <(GRPMEM + 24 * BYTES_PER_SPRITE), >(GRPMEM + 24 * BYTES_PER_SPRITE)

    // 8DCF
    _48_memory_ptr: // Pointer to sprite 48 (dec) graphic memory area
        .byte <(GRPMEM + 48 * BYTES_PER_SPRITE), >(GRPMEM + 48 * BYTES_PER_SPRITE)

    // 8DD1
    _56_memory_ptr: // Pointer to sprite 56 (dec) graphic memory area
        .byte <(GRPMEM + 56 * BYTES_PER_SPRITE), >(GRPMEM + 56 * BYTES_PER_SPRITE)
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
    // BCC3 -> seems to be key chjeck state maybe??
    flag_setup_progress: .byte $00 // Game setup state ($80 = intro, $00 = board walk, $ff = options)

    // BCC7
    counter: .byte $00 // State counter (increments after each state change)

    // BCCB
    NFI_001: .byte $00 // TODO: NO IDEA WHAT THIS IS

    // BCD0
    flag_update: .byte $00 // Is set to $80 to indicate that the game state should be changed to the next state

    // BCD1
    flag_play_intro: .byte $00 // Set to $80 to play intro and $00 to skip intro

    // BCD3
    flag_update_on_interrupt: .byte $00 // Is set to non zero if the game state should be updated after next interrupt

    // BD30
    current_fn_ptr: .word $0000 // Pointer to code that will run in the current state
}

.namespace screen {
    // BF19
    color_mem_offset: .byte $00 // Screen offset to color ram
}

.namespace sprite {
    // BD3E
    curr_x_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00 // Current sprite x-position

    // BD46
    curr_y_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00 // Current sprite y-position
}

// Memory addresses used for multiple purposes. Each purpose has it's own label and label description for in-code
// readbility.
.namespace temp {
    // BD38
    data__num_pieces: // Number of baord pieces to render
        .byte $00

    // BF1A
    data__curr_color: // Color of the current intro string being rendered
    data__curr_board_piece: // Index to start of character dot data for current board piece
    data__math_store: // Temporary storage used for math operations
        .byte $00

    // BF1B
    ptr__sprite: // Intro sprite data pointer
        .byte $00

    // BF20
    data__math_store_1: // Temporary storage used for math operations
        .byte $00

    // BF21
    data__math_store_2: // Temporary storage used for math operations
        .byte $00

    // BF21

    // BF22
    flag__sprites_initialized: // Is TRUE if intro character sprites are initialized
         .byte $00

    // BF26
    data__current_board_row: // Board row offset for rendered piece
        .byte $00

    // BF28
    data__current_board_col: // Board column for rendered piece
        .byte $00

    // BF2D
    data__piece_type: // Type of board piece
        .byte $00

    // BF30
    data__curr_line: // Current screen line used while rendering repeated strings in into page
    data__curr_row: // Current board row
        .byte $00

    // BF31
    data__curr_column: // Current board column
        .byte $00

    // BD3A
    data__msg_offset: // Offset of current message being rendered in into page
    data__piece_offset: // Offset of current piece being rendered on to the board
        .byte $00

    // BD7B
    data__counter: // Temporary counter
        .byte $00

    // BF3C
    flag__string_control: // Used to control string rendering in intro page
        .byte $00

    // BF23
    data__sprite_y_direction_offset: // Amount added to y plan to move sprite to the left or right (uses rollover)
        .byte $00

    // BF24
    data__sprite_x_direction_offset: // Amount added to x plan to move sprite to the left or right (uses rollover)
    data__current_square_color_code: // Color code used to render
        .byte $00
}
