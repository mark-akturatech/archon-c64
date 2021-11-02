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
// - This is not a byte for byte memory replication. The source is fully relocatable and pays no heed to original
//   memory locations. Original memory locations are provided as comments above each variable, constant or method
//   for reference.
// - The source does not include any original logic that moves code or data around. The source code below has been
//   developed so that it all loads entirely in place. This is to aide radability and also alows easy addition or
//   modification of code.
// - The source uses screen memory bank at $4000 and has logic to move code and data from this area. Here we use
//   the $8000 bank so that the code can all remain in place. However, to make enough room, we have hard coded the
//   character dot dat to load directly in to the required memory location.
// - The source uses the same data memory addresses for different purposes. For example `BF24` may store the current
//   color phase, a sprite animation frame or a sprite x position offset. To simplify code readability, we may have
//   added multiple lables to the same memory address. TODO: MIGHT MAKE THESE SEPARATE MEMORY IF WE HAVE ENOUGH SPACE!!

#import "src/io.asm"
#import "src/const.asm"

.file [name="main.prg", segments="Upstart, Main, Common, Intro, Game, Assets, ScreenMemory"]

.segmentdef Upstart
.segmentdef Main [startAfter="Upstart"]
.segmentdef Common [startAfter="Main"]
.segmentdef Intro [startAfter="Common"]
.segmentdef Game [startAfter="Intro"]
.segmentdef Assets [startAfter="Game", max=$7FFF]
//
.segmentdef ScreenMemory [start=$8000]
//
.segmentdef Data [start=$C000, max=$CFFF, virtual] // Data set once on game initialization
.segmentdef DynamicDataStart [startAfter="Data", virtual] // Data that is reset on each game state change
.segmentdef DynamicData [startAfter="DynamicDataStart", virtual]
.segmentdef DynamicDataEnd [startAfter="DynamicData",  virtual]

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

// create basic program with sys command to execute code
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
    sta game_state.flag__first_player
    tsx
    stx stack_ptr_store
    lda #$80
    sta state.flag_play_intro // Non zero to play intro, $00 to skip
    sta state.flag_setup_progress // Flag used by keycheck routine to test for run/stop or Q (if set)
    // lda #$03
    // sta WBCCB
    lda initialized_flag
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
    // 6150  A2 23      ldx  #$23 // TODO: why copy the setup matrix? OH - is this the location of each piece as game progresses. I reckon so.
    // W6152:
    // 6152  BC FF 8A   ldy  board_character_setup_matrix,x
    // 6155  B9 B3 8A   lda  W8AB3,y
    // 6158  9D FD BD   sta  WBDFD,x
    // 615B  CA         dex
    // 615C  10 F4      bpl  W6152
    lda #>COLRAM
    sec
    sbc #>SCNMEM
    sta screen.color_mem_offset
    // 6193  A9 51      lda  #$51 // TODO: I reckon this does stuff like sets up 2 powers, board matrix etc so these can be in data mem instead of assets??
    // 6195  8D 1A BF   sta  temp_data__curr_color
    // 6198  A9 00      lda  #$00
    // 619A  8D 1B BF   sta  temp_ptr__sprite
    // 619D  AA         tax
    // W619E:
    // 619E  AD 1A BF   lda  temp_data__curr_color
    // 61A1  9D E4 BE   sta  WBEE4,x
    // 61A4  A9 44      lda  #$44
    // 61A6  18         clc
    // 61A7  6D 1B BF   adc  temp_ptr__sprite
    // 61AA  9D EF BE   sta  WBEEF,x
    // 61AD  AD 1A BF   lda  temp_data__curr_color
    // 61B0  18         clc
    // 61B1  69 50      adc  #$50
    // 61B3  8D 1A BF   sta  temp_data__curr_color
    // 61B6  90 03      bcc  W61BB
    // 61B8  EE 1B BF   inc  temp_ptr__sprite
    // W61BB:
    // 61BB  E8         inx
    // 61BC  E0 0B      cpx  #$0B
    // 61BE  90 DE      bcc  W619E
    // 61C0  A9 7C      lda  #$7C
    // 61C2  8D 1A BF   sta  temp_data__curr_color
    // 61C5  A9 00      lda  #$00
    // 61C7  8D 1B BF   sta  temp_ptr__sprite
    // 61CA  AA         tax
    // W61CB:
    // 61CB  AD 1A BF   lda  temp_data__curr_color
    // 61CE  9D C0 BE   sta  board_row_occupancy_lo_ptr,x
    // 61D1  A9 BD      lda  #$BD
    // 61D3  18         clc
    // 61D4  6D 1B BF   adc  temp_ptr__sprite
    // 61D7  9D C9 BE   sta  board_row_occupancy_hi_ptr,x
    // 61DA  AD 1A BF   lda  temp_data__curr_color
    // 61DD  18         clc
    // 61DE  69 09      adc  #$09
    // 61E0  8D 1A BF   sta  temp_data__curr_color
    // 61E3  90 03      bcc  W61E8
    // 61E5  EE 1B BF   inc  temp_ptr__sprite
    // W61E8:
    // 61E8  E8         inx
    // 61E9  E0 09      cpx  #$09
    // 61EB  90 DE      bcc  W61CB
    // 61ED  A9 5D      lda  #$5D
    // 61EF  8D 1A BF   sta  temp_data__curr_color
    // 61F2  A9 00      lda  #$00
    // 61F4  8D 1B BF   sta  temp_ptr__sprite
    // 61F7  AA         tax
    // W61F8:
    // 61F8  AD 1A BF   lda  temp_data__curr_color
    // 61FB  9D D2 BE   sta  board_row_color_lo_ptr,x
    // 61FE  A9 0B      lda  #$0B
    // 6200  18         clc
    // 6201  6D 1B BF   adc  temp_ptr__sprite
    // 6204  9D DB BE   sta  board_row_color_hi_ptr,x
    // 6207  AD 1A BF   lda  temp_data__curr_color
    // 620A  18         clc
    // 620B  69 09      adc  #$09
    // 620D  8D 1A BF   sta  temp_data__curr_color
    // 6210  90 03      bcc  W6215
    // 6212  EE 1B BF   inc  temp_ptr__sprite
    // W6215:
    // 6215  E8         inx
    // 6216  E0 09      cpx  #$09
    // 6218  90 DE      bcc  W61F8
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
    lda game_state.flag__first_player
    sta game_state.flag__current_player
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
#if INCLUDE_INTRO
    lda state.flag_play_intro
    beq skip_board_walk
    jsr board_walk.entry
#endif
skip_board_walk:
    rts

// 4700
prep:
    // Indicate that we have initialised the app, so we no don't need to run `prep` again if the app is restarted.
    lda #$80
    sta initialized_flag
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
.segment Assets

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

.segment ScreenMemory

#if INCLUDE_INTRO
    * = CHRMEM1
    .import binary "/assets/charset-intro.bin"
#endif

* = CHRMEM2
.import binary "/assets/charset-game.bin"


//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
// Contains constants, assets and resources included in the compiled file.
.segment Assets

// 02A7
initialized_flag: .byte $00 // 00 for uninitialized, $80 for initialized

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
// Data in this area are not cleared on state change.
//
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
    // 0334
    curr_game_fn_ptr: .word $0000, $0000, $0000 // Pointers used to jump to various game states (intro, board, play)

    // BCC3 -> seems to be key check state maybe??
    flag_setup_progress: .byte $00 // Game setup state ($80 = intro, $00 = board walk, $ff = options)

    // BCC7
    counter: .byte $00 // State counter (increments after each state change)

    // BCD0
    flag_update: .byte $00 // Is set to $80 to indicate that the game state should be changed to the next state

    // BCD1
    flag_play_intro: .byte $00 // Set to $80 to play intro and $00 to skip intro
}

.namespace game_state {
    // BCC2
    flag__first_player: .byte $00 // Is positive for light, negative for dark

    // BCC6
    flag__current_player: .byte $00 // Is positive for light, negative for dark
}

//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
//
.segment DynamicDataStart
    dynamic_data_start:

.segment DynamicData

.namespace state {
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
    // BCE3
    default_direction_flag:
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
    flag__sprites_initialized: // Is TRUE if intro character sprites are initialized
         .byte $00

    // BF25
    data__sprite_final_y_pos: // Final Y position of animated sprite
        .byte $00

    // BF26
    data__current_board_row: // Board row offset for rendered piece
        .byte $00

    // BF28
    data__current_board_col: // Board column for rendered piece
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
    flag__string_control: // Used to control string rendering in intro page
        .byte $00

    // BF23
    data__sprite_y_direction_offset: // Amount added to y plan to move sprite to the left or right (uses rollover)
    data__temp_store_1: // Temporary data storage
        .byte $00

    // BF24
    data__sprite_x_direction_offset: // Amount added to x plan to move sprite to the left or right (uses rollover)
    data__current_square_color_code: // Color code used to render
    data__character_sprite_frame: // Frame offset of sprite character set. Add #$80 to invert the frame on copy.
        .byte $00
}

.segment DynamicDataEnd
    dynamic_data_end:
