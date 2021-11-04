.filenamespace main

//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Archon (c) 1983
//
// Reverse engineer of C64 Archon (c) 1983 by Free Fall Associates.
//
// Full resepct to the awesome authors:
// - Anne Westfall, Jon Freeman, Paul Reiche III
//
// THANK YOU FOR MANY YEARS OF MEMORABLE GAMING. ARCHON ROCKS AND ALWAYS WILL!!!
//---------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// Notes:
// - This is not a byte for byte memory replication. The code is fully relocatable and pays no heed to original
//   memory locations. Original memory locations are provided as comments above each variable, constant or method
//   for reference.
// - The source does not include any original logic that moves code or data around. The code below has been
//   developed so that it all loads entirely in place. This is to aide radability and also alows easy addition or
//   modification of code.
// - The source uses screen memory bank at $4000 and has logic to move code and data from this area. Here we use
//   the $8000 bank so that the code can all remain in place. However, to make enough room, we have hard coded the
//   character dot data to load directly in to the required memory location.
// - The source uses the same data memory addresses for different purposes. For example `BF24` may store the current
//   color phase, a sprite animation frame or a sprite x position offset. To simplify code readability, we have
//   added multiple lables to the same memory address. 
//   TODO: MIGHT MAKE THESE SEPARATE MEMORY IF WE HAVE ENOUGH SPACE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//---------------------------------------------------------------------------------------------------------------------
// Memory map
//---------------------------------------------------------------------------------------------------------------------
// Starts at $0801

.segmentdef Upstart
.segmentdef Main [startAfter="Upstart"]
.segmentdef Common [startAfter="Main"]
.segmentdef Intro [startAfter="Common"]
.segmentdef Game [startAfter="Intro"]
.segmentdef Assets [startAfter="Game", max=$7FFF]
//
.segmentdef ScreenMemory [start=$8000, max=$BFFF] // Graphic bank 2
//
.segmentdef Data [start=$C000, virtual] // Data set once on game initialization
.segmentdef DynamicDataStart [startAfter="Data", virtual] // Data that is reset on each game state change
.segmentdef DynamicData [startAfter="DynamicDataStart", virtual]
.segmentdef DynamicDataEnd [startAfter="DynamicData", max=$CFFF, virtual]

//---------------------------------------------------------------------------------------------------------------------
// Output File
//---------------------------------------------------------------------------------------------------------------------
// Save all segments to a prg file except the virtual data segments.

.file [name="main.prg", segments="Upstart, Main, Common, Intro, Game, Assets, ScreenMemory"]

//---------------------------------------------------------------------------------------------------------------------
// Source Files
//---------------------------------------------------------------------------------------------------------------------
// The source code is split in to the following files:
// - Main: Main game loop
// - Common: Library of subroutines and assets used by various game states
// - board: Subroutines and assets used to render the game board
// - intro: Subroutines and assets used by the intro page (eg the dancing logo page)
// - board_walk: Subroutines and assets used during the introduction to walk pieces on to the board
// - game: Subroutines and assets used during main game play
// - fight: Subroutines and assets used during fighting game play
// Additionally, two constant files are used:
// - io: contains standard C64 memory and IO addresses using "MAPPING THE Commodore 64" constants names
// - const: contains game specific constants

#import "src/io.asm"
#import "src/const.asm"
#import "src/common.asm"
#import "src/board.asm"
#if INCLUDE_INTRO
    #import "src/intro.asm"
    #import "src/board_walk.asm"
#endif
#import "src/game.asm"

//---------------------------------------------------------------------------------------------------------------------
// Basic Upstart
//---------------------------------------------------------------------------------------------------------------------
.segment Upstart

BasicUpstart2(entry)

//---------------------------------------------------------------------------------------------------------------------
// Entry
//---------------------------------------------------------------------------------------------------------------------
.segment Main

// 6100
entry:
    // 6100  A9 00      lda #$00       // TODO: what are these variables
    // 6102  8D C0 BC sta WBCC0 // not dynamic!
    // 6105  8D C1 BC sta WBCC1      // players -> 2, light, dark
    // 6108  8D C5 BC sta WBCC5
    lda #$55 // Set light as first player
    sta game.state.flag__is_first_player_light
    tsx
    stx stack_ptr_store
    lda #FLAG_ENABLE
    sta flag__enable_intro // Non zero to play intro, $00 to skip
    sta curr_pre_game_progress // Flag used by keycheck routine to test for run/stop or Q (if set)
    // lda #$03
    // sta WBCCB
    lda flag__is_initialized
    bmi skip_prep
    jsr prep
skip_prep:
    jsr init
restart_game_loop:
    ldx stack_ptr_store
    txs
    jsr common.stop_sound
    // Clears variable storage area.
    lda #<dynamic_data_start
    sta FREEZP+2
    lda #>dynamic_data_start
    sta FREEZP+3
    ldx #>((dynamic_data_end + $0100) - dynamic_data_start) // Number of blocks to clear + 1
    lda #$00
    tay
!loop:
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+3
    dex
    bne !loop-
    //
    jsr common.clear_screen
    jsr common.clear_sprites
    // Set the initial strength of each piece.
    ldx #(BOARD_INITIAL_NUM_PIECES - 1) // total number of pieces (0 offset)
!loop:
    ldy board.piece.initial_matrix,x
    lda board.piece.inital_strength,y
    sta game.curr_piece_strength,x
    dex
    bpl !loop-
    // skip 618B to 6219 as this just configures pointers to various constant areas - like pointers to each board row
    // tile color scheme or row occupancy. we have instead included these as constants using compiler directives as it
    // is much more readable.
    lda #FLAG_ENABLE
    sta interrupt.flag__enable
    // Clear board square occupancy data.
    ldx #(BOARD_NUM_COLS * BOARD_NUM_ROWS - 1) // Empty (9x9 grid) squares (0 offset)
!loop:
    sta game.curr_square_occupancy,x
    dex
    bpl !loop-
    // 6227  8D 24 BD sta WBD24  // TODO: what are these variables?
    // 622A 8D 25 BD sta WBD25
    lda game.state.flag__is_first_player_light
    sta game.state.flag__is_curr_player_light
    // Set default board phase color.
    ldy #$03
    lda board.data.color_phase,y
    sta game.curr_color_phase
    lda flag__enable_intro
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
#if INCLUDE_INTRO
    lda flag__enable_intro
    beq skip_board_walk
    jsr board_walk.entry
#endif
skip_board_walk:
    rts

// 4700
prep:
    // Indicate that we have initialised the app, so we no don't need to run `prep` again if the app is restarted.
    lda #FLAG_ENABLE
    sta flag__is_initialized
    // Store system interrupt handler pointer so we can call it from our own interrupt handler.
    lda CINV
    sta interrupt.raster_fn_ptr
    lda CINV+1
    sta interrupt.raster_fn_ptr+1
    // skip 4711-4765 - moves stuff around. we'll just set any intiial values in our assets segment.
main_prep_game_states:
    // Configure game state function handlers.
    ldx #$05
!loop:
    lda state.game_fn_ptr,x
    sta state.curr_game_fn_ptr,x
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
    jmp (state.curr_game_fn_ptr)

// 8013
play_board_setup:
    jmp (state.curr_game_fn_ptr+2)

// 8016
play_intro:
    jmp (state.curr_game_fn_ptr+4)

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
// Assets are constant data, initialized variables and resources that are included in the prg file.
.segment Assets

// 02A7
flag__is_initialized: .byte FLAG_DISABLE // 00 for uninitialized, $80 for initialized

.namespace screen {
    // BF19
    color_mem_offset: .byte >(COLRAM-SCNMEM) // Screen offset to color ram
}

.namespace state {
    // 4760
    game_fn_ptr: // Pointer to each main game function (intro, board, game)
        .word game.entry // TODO: this could be wrong
        .word game.entry // TODO: this could be wrong
#if INCLUDE_INTRO
        .word intro.entry
#else
        .word game.entry
#endif
}

.namespace math {
    // 8DC3
    pow2: .fill 8, pow(2, i) // Pre-calculated powers of 2
}

.namespace sprite {
    // 8DBF
    offset_00: .byte (VICGOFF / BYTES_PER_SPRITE) + 00 // Sprite 0 screen pointer

    // 8DC0
    offset_24: .byte (VICGOFF / BYTES_PER_SPRITE) + 24 // Sprite 24 screen pointer

    // 8DC1
    offset_48: .byte (VICGOFF / BYTES_PER_SPRITE) + 48 // Sprite 48 screen pointer

    // 8DC2
    offset_56: .byte (VICGOFF / BYTES_PER_SPRITE) + 56 // Sprite 56 screen pointer

    // 8DCB
    mem_ptr_00: // Pointer to sprite 0 graphic memory area
        .byte <(GRPMEM + 00 * BYTES_PER_SPRITE), >(GRPMEM + 00 * BYTES_PER_SPRITE)

    // 8DCD
    mem_ptr_24: // Pointer to sprite 24 (dec) graphic memory area
        .byte <(GRPMEM + 24 * BYTES_PER_SPRITE), >(GRPMEM + 24 * BYTES_PER_SPRITE)

    // 8DCF
    mem_ptr_48: // Pointer to sprite 48 (dec) graphic memory area
        .byte <(GRPMEM + 48 * BYTES_PER_SPRITE), >(GRPMEM + 48 * BYTES_PER_SPRITE)

    // 8DD1
    mem_ptr_56: // Pointer to sprite 56 (dec) graphic memory area
        .byte <(GRPMEM + 56 * BYTES_PER_SPRITE), >(GRPMEM + 56 * BYTES_PER_SPRITE)
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
// Load the character set directly in to graphic memory bank 2.
.segment ScreenMemory

#if INCLUDE_INTRO
    * = CHRMEM1
    .import binary "/assets/charset-intro.bin"
#endif

* = CHRMEM2
.import binary "/assets/charset-game.bin"

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// Data in this area are not cleared on state change.
.segment Data

// BCC4
stack_ptr_store: .byte $00 // Stored stack pointer so that stack is reset on each state update

// BCD1
flag__enable_intro: .byte $00 // Set to $80 to play intro and $00 to skip intro

// BCC3
curr_pre_game_progress: .byte $00 // Game intro state ($80 = intro, $00 = board walk, $ff = options)

.namespace interrupt {
    // BCCC
    system_fn_ptr: .word $0000 // System interrupt handler function pointer

    // BCCE
    raster_fn_ptr: .word $0000 // Raster interrupt handler function pointer

    // BCD0
    flag__enable: .byte $00 // Is set to $80 to indicate that the game state should be changed to the next state
}

.namespace state {
    // 0334
    curr_game_fn_ptr: .word $0000, $0000, $0000 // Pointers used to jump to various game states (intro, board, play)

    // BCC7
    counter: .byte $00 // State counter (increments after each state change)
}

//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
.segment DynamicDataStart
    dynamic_data_start:

.segment DynamicData

.namespace interrupt {
    // BCD3
    flag__enable_next: .byte $00 // Is set to non zero if the game state should be updated after next interrupt
}

.namespace state {
    // BD30
    curr_fn_ptr: .word $0000 // Pointer to code that will run in the current state
}

// Memory addresses used for multiple purposes. Each purpose has it's own label and label description for in-code
// readbility.
.namespace temp {
    // BCE3
    flag__is_piece_mirrored:
    data__frame_count:
        .byte $00
        .byte $00, $00, $00 // Default direction of character peice (> 0 for inverted)

    // BCEE
    flag__alternating_state: // Alternating state flag (alternates between 00 and FF)
        .byte $00

    // BCFE
    data__curr_sprite_count: // Current animated sprite counter (used to animate multiple sprites)
        .byte $00

    // BCEF
    flag__alternating_state_1: // Alternating state flag (alternates between 00 and FF)
        .byte $00

    // BD0D
    data__sprite_x_direction_offset_1: // Amount added to x plan to move sprite to the left or right (uses rollover)
        .byte $00

    // BD17
    data__sprite_final_x_pos: // Final X position of animated sprite
        .byte $00

    // BD26
    data__sprite_count: // Current sprite counter
        .byte $00

    // BD38
    data__num_pieces: // Number of baord pieces to render
        .byte $00

    // BF1A
    data__curr_color: // Color of the current intro string being rendered
    data__board_piece_char_offset: // Index to character dot data for current board piece part
    data__math_store: // Temporary storage used for math operations
    data__curr_count: // Temporary storage used to keep track of a counter
    data__x_pixels_per_move: // Pixels to move intro sprite for each frame
        .byte $00

    // BF1B
    ptr__sprite: // Intro sprite data pointer
    data__curr_x_pos: // Current calculated sprite X position
    data__temp_store: // Temporary data storage area
        .byte $00
        .byte $00
        .byte $00
        .byte $00
        .byte $00

    // BF20
    data__math_store_1: // Temporary storage used for math operations
        .byte $00

    // BF21
    data__math_store_2: // Temporary storage used for math operations
        .byte $00

    // BF22
    flag__are_sprites_initialized: // Is TRUE if intro character sprites are initialized
         .byte $00

    // BF25
    data__sprite_final_y_pos: // Final Y position of animated sprite
        .byte $00

    // BF26
    data__curr_board_row: // Board row offset for rendered piece
        .byte $00

    // BF28
    data__curr_board_col: // Board column for rendered piece
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

    // BF3B
    data__sprite_y_offset: // Calculated Y offset for each sprite in walk in intro
        .byte $00

    // BF3C
    flag__string_pos_control: // Used to control string rendering in intro page
        .byte $00

    // BF23
    data__sprite_y_direction_offset: // Amount added to y plan to move sprite to the left or right (uses rollover)
    data__temp_store_1: // Temporary data storage
        .byte $00

    // BF24
    data__sprite_x_direction_offset: // Amount added to x plan to move sprite to the left or right (uses rollover)
    data__curr_square_color_code: // Color code used to render
    data__character_sprite_frame: // Frame offset of sprite character set. Add #$80 to invert the frame on copy.
        .byte $00
}

.segment DynamicDataEnd
    dynamic_data_end:
