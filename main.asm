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
// - Main: Main game loop.
// - Common: Library of subroutines and assets used by various game states.
// - board: Subroutines and assets used to render the game board.
// - intro: Subroutines and assets used by the intro page (eg the dancing logo page).
// - board_walk: Subroutines and assets used during the introduction to walk icons on to the board.
// - game: Subroutines and assets used during main game play.
// - ai: Subroutinues used for AI in board and challenge game play. I split these out as they may be interesting.
// - challenge: Subroutines and assets used during challenge battle game play.
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
#import "src/magic.asm"
#import "src/challenge.asm"
#import "src/ai.asm"

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
    lda #FLAG_DISABLE
    sta game.state.flag__ai_player_ctl
    sta common.options.temp__ai_player_ctl
    sta common.options.flag__ai_player_ctl
    lda #$55 // Set light as first player
    sta game.state.flag__is_first_player_light
    tsx
    stx stack_ptr_store
    lda #FLAG_ENABLE
    sta flag__enable_intro // Non zero to play intro, $00 to skip
    sta curr_pre_game_progress // Flag used by keycheck routine to test for run/stop or Q (if set)
    lda #$03 // Set default number of large jiffies (~12s as each tick is ~4s)
    sta board.countdown_timer
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
    ldx #>((dynamic_data_end+$0100)-dynamic_data_start) // Number of blocks to clear + 1
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
    // Set the initial strength of each icon.
    ldx #(BOARD_NUM_ICONS - 1) // Total number of icons (0 offset)
!loop:
    ldy board.icon.init_matrix,x
    lda board.icon.init_strength,y
    sta game.curr_icon_strength,x
    dex
    bpl !loop-
    // skip 618B to 6219 as this just configures pointers to various constant areas - like pointers to each board row
    // tile color scheme or row occupancy. we have instead included these as constants using compiler directives as it
    // is much more readable.
    lda #FLAG_ENABLE
    sta interrupt.flag__enable
    // Clear board square occupancy data.
    ldx #(BOARD_NUM_COLS*BOARD_NUM_ROWS-1) // Empty (9x9 grid) squares (0 offset)
!loop:
    sta game.curr_square_occupancy,x
    dex
    bpl !loop-
    sta game.imprisoned_icon_id
    sta game.imprisoned_icon_id+1
    lda game.state.flag__is_first_player_light
    sta game.state.flag__is_light_turn
    // Set default board phase color.
    ldy #$03
    lda board.data.color_phase,y
    sta game.curr_color_phase
#if INCLUDE_INTRO
    lda flag__enable_intro
    beq skip_intro
    jsr play_intro
#endif
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
#else
    lda #%1111_1111 // Enable all sprites
    sta SPENA
#endif
skip_board_walk:
    lda #FLAG_DISABLE
    sta board.sprite.flag__copy_animation_group
    lda #FLAG_DISABLE
    sta flag__enable_intro
    lda TIME+1
    sta state.last_stored_time // Large jiffy (increments 256 jiffies aka ~ 4 seconds)
    // Clear used spell flags.
    ldx #$0D // 7 spells per size (14 total - zero based)
    lda #SPELL_UNUSED
!loop:
    sta magic.flag__light_used_spells,x
    dex
    bpl !loop-
    //
    // Set the board - This is done by setting each square to an index into the initial matrix which stores the icon in
    // column 1, 2 each row for player 1 and then repeated for player 2. The code below reads the sets two icons in the
    // row, clears the next 5 and then sets the last 2 icons and repeats for each row.
    lda #$12
    sta temp.data__temp_store // Player 2 icon matrix offset
    lda #$00
    sta temp.data__temp_store+1 // Player 1 icon matrix offset
    tax
board_setup_row_loop:
    ldy #$02
board_setup_player_1_loop:
    lda temp.data__temp_store+1
    sta game.curr_square_occupancy,x
    inc temp.data__temp_store+1
    inx
    dey
    bne board_setup_player_1_loop
    ldy #$05
    lda #BOARD_EMPTY_SQUARE
board_setup_empty_col_loop:
    sta game.curr_square_occupancy,x
    inx
    dey
    bne board_setup_empty_col_loop
    ldy #$02
board_setup_player_2_loop:
    lda temp.data__temp_store
    sta game.curr_square_occupancy,x
    inc temp.data__temp_store
    inx
    dey
    bne board_setup_player_2_loop
    cpx #(BOARD_NUM_COLS*BOARD_NUM_ROWS)
    bcc board_setup_row_loop
    //
    lda game.state.flag__is_first_player_light
    eor #$FF
    sta state.curr_phase // Phase state and direction
    sta game.state.flag__is_light_turn // Set current player
    // Set starting board color.
    lda #$06
    ldy game.state.flag__is_light_turn
    bpl !next+
    clc
    adc #$02
!next:
    sta main.state.curr_cycle+3 // Board color phase cycle
    lsr // 6 becomes 0011 (3), 8 becomes 0100 (4)
    tay
    lda board.data.color_phase,y
    sta game.curr_color_phase
    jsr common.clear_screen
    jmp game.entry

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
play_challenge:
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
    game_fn_ptr: // Pointer to each main game function
        .word game.interrupt_handler
        .word challenge.interrupt_handler
#if INCLUDE_INTRO
        .word intro.entry
#else
        .word $0000
#endif
}

.namespace math {
    // 8DC3
    pow2: .fill 8, pow(2, i) // Pre-calculated powers of 2
}

.namespace sprite {
    // 8DBF
    offset_00: .byte (VICGOFF/BYTES_PER_SPRITE)+00 // Sprite 0 screen pointer

    // 8DC0
    offset_24: .byte (VICGOFF/BYTES_PER_SPRITE)+24 // Sprite 24 screen pointer

    // 8DC1
    offset_48: .byte (VICGOFF/BYTES_PER_SPRITE)+48 // Sprite 48 screen pointer

    // 8DC2
    offset_56: .byte (VICGOFF/BYTES_PER_SPRITE)+56 // Sprite 56 screen pointer

    // 8DCB
    mem_ptr_00: // Pointer to sprite 0 graphic memory area
        .byte <(GRPMEM+00*BYTES_PER_SPRITE), >(GRPMEM+00*BYTES_PER_SPRITE)

    // 8DCD
    mem_ptr_24: // Pointer to sprite 24 (dec) graphic memory area
        .byte <(GRPMEM+24*BYTES_PER_SPRITE), >(GRPMEM+24*BYTES_PER_SPRITE)

    // 8DCF
    mem_ptr_48: // Pointer to sprite 48 (dec) graphic memory area
        .byte <(GRPMEM+48*BYTES_PER_SPRITE), >(GRPMEM+48*BYTES_PER_SPRITE)

    // 8DD1
    mem_ptr_56: // Pointer to sprite 56 (dec) graphic memory area
        .byte <(GRPMEM+56*BYTES_PER_SPRITE), >(GRPMEM+56*BYTES_PER_SPRITE)
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

// BCC3
curr_pre_game_progress: .byte $00 // Game intro state ($80 = intro, $00 = board walk, $ff = options)

// BCC4
stack_ptr_store: .byte $00 // Stored stack pointer so that stack is reset on each state update

// BCD1
flag__enable_intro: .byte $00 // Set to $80 to play intro and $00 to skip intro

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
    counter: // State counters
        .byte $00
        .byte $00
        .byte $00
    curr_phase:
        .byte $00
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
    // BD27
    last_stored_time: .byte $00 // Last recorded major jiffy clock counter (256 jiffy counter)

    // BD30
    curr_fn_ptr: .word $0000 // Pointer to code that will run in the current state

    // BF3D
    curr_cycle: .byte $00, $00, $00, $00 // State cycle counters (counts up and down using numbers 0, 2, 6, 8, E and C)
}

// Memory addresses used for multiple purposes. Each purpose has it's own label and label description for in-code
// readbility.
.namespace temp {
    // BCEE
    flag__alternating_state: // Alternating state flag (alternates between 00 and FF)
    data__curr_frame_adv_count: // Counter used to advance animation frame (every 4 pixels)
        .byte $00

    // BCFE
    data__curr_count: // Current counter value
    flag__icon_destination_valid: // Action on icon square drop selection
        .byte $00

    // BCEF
    flag__alternating_state_1: // Alternating state flag (alternates between 00 and FF)
        .byte $00

    // BD0D
    data__sprite_x_direction_offset_1: // Amount added to x plan to move sprite to the left or right (uses rollover)
    flag__board_sprite_moved: // Is non-zero if the board sprite was moved (in X or Y direction ) since last interrupt
        .byte $00

    // BD17
    data__sprite_final_x_pos: // Final X position of animated sprite
        .byte $00

    // BD26
    data__curr_sprite_ptr: // Current sprite counter
        .byte $00

    // BD2D
    data__temp_store_2: // Temporary storage
        .byte $00

    // BD38
    data__num_icons: // Number of baord icons to render
        .byte $00

    // BD66
    dynamic_fn_ptr: .word $0000 // Pointer to a dynanic function determined at runtime

    // BF1A
    data__curr_color: // Color of the current intro string being rendered
    data__board_icon_char_offset: // Index to character dot data for current board icon part (icons are 6 caharcters)
    data__math_store: // Temporary storage used for math operations
    data__x_pixels_per_move: // Pixels to move intro sprite for each frame
    data__temp_store: // Temporary data storage area
        .byte $00
    ptr__sprite: // Intro sprite data pointer
    data__curr_x_pos: // Current calculated sprite X position
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
    flag__are_sprites_initialized: // Is TRUE if intro icon sprites are initialized
         .byte $00

    // BF25
    data__sprite_final_y_pos: // Final Y position of animated sprite
    data__curr_icon_row: // Intitial board row of selected icon
        .byte $00

    // BF26
    data__curr_board_row: // Board row offset for rendered icon
        .byte $00

    // BF27
    data__curr_icon_col: // Intitial board column of selected icon
        .byte $00

    // BF28
    data__curr_board_col: // Board column for rendered icon
        .byte $00

    // BF30
    data__curr_line: // Current screen line used while rendering repeated strings in into page
    data__curr_row: // Current board row
        .byte $00

    // BF31
    data__curr_column: // Current board column
        .byte $00

    // BF32
    data__dark_icon_count: // Dark remaining icon count
    data__board_sprite_move_y_count: // Sprite Y position movement counter
    data__hold_delay_count: // Current spell selection
        .byte $00

    // BF33
    data__remaining_dark_icon_id: // Icon ID of last dark icon
        .byte $00

    // BF36
    data__light_icon_count: // Light remaining icon count
    data__board_sprite_move_x_count: // Sprite X position movement counter
        .byte $00

    // BF37
    data__remaining_light_icon_id: // Icon ID of last light icon
        .byte $00

    // BD3A
    data__msg_offset: // Offset of current message being rendered in into page
    data__icon_offset: // Offset of current icon being rendered on to the board
    data__curr_spell_id: // Current selected spell ID
        .byte $00

    // BD68
    data__temp_note_store: // Temporary storage for musical note being played
        .byte $00

    // BD7B
    data__counter: // Temporary counter
        .byte $00

    // BF3B
    data__sprite_y_offset: // Calculated Y offset for each sprite in walk in intro
        .byte $00

    // BF3C
    flag__string_pos_ctl: // Used to control string rendering in intro page
        .byte $00

    // BF23
    data__sprite_y_direction_offset: // Amount added to y plan to move sprite to the left or right (uses rollover)
    data__temp_store_1: // Temporary data storage
    data__used_spell_count: // Count of number of used spells for a specific player
        .byte $00

    // BF24
    data__sprite_x_direction_offset: // Amount added to x plan to move sprite to the left or right (uses rollover)
    data__curr_square_color_code: // Color code used to render
    data__icon_set_sprite_frame: // Frame offset of sprite icon set. Add #$80 to invert the frame on copy.
        .byte $00
}

.segment DynamicDataEnd
    dynamic_data_end:
