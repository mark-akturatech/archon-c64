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
// See README.md file for additional information.

// TODO:
// - Standardise data label naming

//---------------------------------------------------------------------------------------------------------------------
// Memory map
//---------------------------------------------------------------------------------------------------------------------
//
.segmentdef Upstart
//
.segmentdef Resources [startAfter="Upstart", align=$100]
//
.segmentdef Main [start=$6000]
.segmentdef Common [startAfter="Main"]
.segmentdef Intro [startAfter="Common"]
.segmentdef Game [startAfter="Intro"]
.segmentdef CodeBase [segments="Main, Common, Intro, Game", hide]
//
.segmentdef Assets [startAfter="Game"]
.segmentdef RelocatedResources [startAfter="Assets", virtual, hide]
//
.segmentdef Data [start=$c000, virtual] // Data set once on game initialization
.segmentdef DynamicDataStart [startAfter="Data", virtual, hide] // Data that is reset on each game state change
.segmentdef DynamicData [startAfter="DynamicDataStart", virtual]
.segmentdef DynamicDataEnd [startAfter="DynamicData", virtual, hide]
//

//---------------------------------------------------------------------------------------------------------------------
// Output File
//---------------------------------------------------------------------------------------------------------------------
// Save all segments to a prg file except the virtual data segments.

.file [name="main.prg", segments="Upstart, Resources, CodeBase, Assets"]

//---------------------------------------------------------------------------------------------------------------------
// Source Files
//---------------------------------------------------------------------------------------------------------------------
// The source code is split in to the following files:
// - `main`: Main game loop.
// - `resources`: Game resources such as sprites, character sets and music phraseology.
// - `common`: Library of subroutines and assets used by two or more source code files.
// - `board`: Subroutines and assets used to render the game board.
// - `intro`: Subroutines and assets used by the intro page (eg the dancing logo page).
// - `board_walk`: Subroutines and assets used during the introduction to walk icons on to the board.
// - `game`: Subroutines and assets used during main game play.
// - `ai`: Subroutinues used for AI in board and challenge game play. I split these out as they may be interesting.
// - `challenge`: Subroutines and assets used during challenge battle game play.
// - `io`: Standard C64 memory and IO addresses using "MAPPING THE Commodore 64" constants names.
// - `const`: Game specific constants.

#import "src/io.asm"
#import "src/const.asm"
#import "src/resources.asm"
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
    // Configure defaults.
    lda #FLAG_DISABLE
    sta game.state.flag__ai_player_ctl // Two player
    sta common.options.temp__ai_player_ctl // AI player dark if one player selected
    sta common.options.flag__ai_player_ctl
    lda #$55 // Light player ($AA for dark)
    sta game.state.flag__is_first_player_light // Light player first
    tsx
    stx storage.stack_ptr
    lda #FLAG_ENABLE
    sta state.flag__enable_intro // Play intro
    sta state.flag__pregame_state // Pregame state ($80 is intro)
    lda #$03 // Set number of large jiffies before game auto plays after intro (~12s as each tick is ~4s)
    sta board.countdown_timer
    //
    lda flag__is_initialized
    bmi skip_move
    jsr resource.move
skip_move:
    jsr init
    //
restart_game_loop:
    // Ensure each game state starts with cleared sound, clean graphics and 00's in all dynamic variables.
    ldx storage.stack_ptr
    txs
    jsr common.stop_sound
    //
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
    //
    // Set the initial strength of each icon.
    ldx #(BOARD_TOTAL_NUM_ICONS - 1) // Total number of icons (0 offset)
!loop:
    ldy board.icon.init_matrix,x
    lda board.icon.init_strength,y
    sta game.curr_icon_strength,x
    dex
    bpl !loop-
    //    
    // skip 618B to 6219 as this just configures pointers to various constant areas - like pointers to each board row
    // tile color scheme or row occupancy. we have instead included these as constants using compiler directives as it
    // is much more readable.
    //
    lda #FLAG_ENABLE
    sta state.flag__enable_next
    //
    // Clear board square occupancy data.
    ldx #(BOARD_NUM_COLS*BOARD_NUM_ROWS-1) // Empty (9x9 grid) squares (0 offset)
!loop:
    sta game.curr_square_occupancy,x
    dex
    bpl !loop-
    //
    sta game.imprisoned_icon_id
    sta game.imprisoned_icon_id+1
    lda game.state.flag__is_first_player_light
    sta game.state.flag__is_light_turn
    //
    // Set default board phase color.
    ldy #$03 // There are 8 phases (0 to 7) with 0 being the darked and 7 the lighted. $03 is in the middle.
    lda board.data.color_phase,y
    sta game.curr_color_phase
    //
#if INCLUDE_INTRO
    // Display the game intro (bouncing Archon).
    lda state.flag__enable_intro
    beq skip_intro
    jsr play_intro
#endif
skip_intro:
    //
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
    //
    // Configure graphics.
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
    // Display the board intro (walking icons).
    lda state.flag__enable_intro
    beq skip_board_walk
    jsr board_walk.entry
#else
    lda #%1111_1111 // Enable all sprites
    sta SPENA
#endif
skip_board_walk:
    //
    lda #FLAG_DISABLE
    sta board.sprite.flag__copy_animation_group
    lda #FLAG_DISABLE
    sta state.flag__enable_intro // Display game options
    lda TIME+1
    sta state.last_stored_time // Store time - used to start game if timeout on options page
    //
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
    lda #BOARD_NUM_PLAYER_ICONS
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
    // The board has an even number of phases (8 in total, but two are disabled, so 6 in reality), the we cannot
    // select a true "middle" starting point for the game. Instead, we chose the phase on the darker side if light is
    // first (06) or the lighter side if dark is first (08). This should reduce any advantage that the first player
    // has. 
    // Furthermore, the phas edirection (from light to dark or vice versa) starts in the favor of the second player.
    // so starts in the direction of light to dark if light is first and dark to light if dark is first.
    lda game.state.flag__is_first_player_light
    eor #$FF
    sta state.curr_phase // Phase state and direction (towards light if dark first, towards darker if light first)
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
    //
    // Let's play!
    jmp game.entry

// 632D
init:
    // Set VIC memory bank.
    // Original code uses the furst 8kb of Bank #1 ($4000-$5FFF)
    //
    // Graphic assets are stored as follows (offsets shown from start of bank address):
    //
    //   0000 -+- intro character set
    //   ...   |
    //   ...   |   0400 -+- screen memory
    //   ...   |   ...   |
    //   ...   |   07e7 -+
    //   ...   |   07e8 -+- sprite location memory
    //   ...   |   ...   |
    //   07ff -+   07ff -+
    //   0800 -+- board character set
    //   ...   |
    //   ...   |
    //   0fff -+
    //   1000 -+- sprite memory (or 2000 for bank 0 and 2 as these banks copy the default charset in to 1000)
    //   ...   |
    //   ...   |
    //   2000 -+
    //
    // As can be seen, the screen memory overlaps the first character set. This is OK as the first character set
    // contains upper case only characters and therefore occupies only half of the memory of a full character set.
    //
    // Set VICII memory bank.
    lda C2DDRA
    ora #%0000_0011
    sta C2DDRA // Enable data direction bits for setting memory bank.
    lda CI2PRA
    and #%1111_1100
    ora #VICBANK
    sta CI2PRA // Set memory bank.
    //
    // Set text mode character memory to $0800-$0FFF (+VIC bank offset as set in CI2PRA).
    // Set character dot data to $0400-$07FF (+VIC bank offset as set in CI2PRA).
    lda #%0001_0010
    sta VMCSB
    //
    // Set RAM visible at $A000-$BFFF.
    // We don't actually need this as we fit everything in before $A000, but we'll leave it in.
    lda R6510
    and #%1111_1110
    sta R6510
    //
    // Configure interrupt handler routines
    // The interrupt handler calls the standard system interrupt if a non-raster interrupt is detected. If a raster
    // interrupt occurs, we will initially calls a minimalist interrupt routine. This routine will be replaced with
    // other function specific routines throughout the application runtime (eg to handle joystick input, animations)
    // etc. We use the raster interrupt as this allows us to trigger at the same time interval as the display is
    // updated at a regular and consistent interval.
    // To set the interrupts, we need to disable interrupts, configure the interrupt call pointers, stop raster scan
    // interrupts and then point the interrupt handler away from the system handler to our new handler. We can then
    // re-enable scan interupts and exit.
    sei
    lda #<common.complete_interrupt
    sta interrupt.raster_fn_ptr
    lda #>common.complete_interrupt
    sta interrupt.raster_fn_ptr+1
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
// Check if the raster interrupt has occurred and call the appropriate interrupt handlers.
interrupt_interceptor:
    lda VICIRQ
    and #%0000_0001
    beq !next+ // Non-raster?
    sta VICIRQ // Indicate that we have handled the interrupt
    jmp (interrupt.raster_fn_ptr)
!next:
    jmp (interrupt.system_fn_ptr)

// 8010
play_game:
    jmp (state.game_fn_ptr)

// 8013
play_challenge:
    jmp (state.game_fn_ptr+2)

// 8016
#if INCLUDE_INTRO
play_intro:
    jmp (state.game_fn_ptr+4)
#endif

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
// Assets are constant data, initialized variables and resources that are included in the prg file.
.segment Assets

// 02A7
flag__is_initialized: .byte FLAG_DISABLE // 00 for uninitialized, $80 for initialized

.namespace state {
    // 4760
    game_fn_ptr: // Pointer to each main game function
        .word game.interrupt_handler
        .word challenge.interrupt_handler
#if INCLUDE_INTRO
        .word intro.entry
#endif
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// Data in this area are not cleared on state change.
.segment Data

.namespace interrupt {
    // BCCC
    // Raster interrupt handler function pointer. This pointer is updated during game play to handle state specific
    // background functions such as animations, detection of joystick inputs, delays and so on.
    raster_fn_ptr: .word $0000

    // BCCE
    // System interrupt handler function pointer. This pointer is calls a minimalist handler that really does nothing
    // and is used to ensure the game runs at optimum speed.
    system_fn_ptr: .word $0000
}

.namespace state {
    // BCD0
    // Is set to $80 to indicate that the game state should be changed to the next state.
    flag__enable_next: .byte $00
    
    // BCD1
    // Set to $80 to play intro and $00 to skip intro.
    flag__enable_intro: .byte $00
    
    // BCC3
    // Pre-game intro state ($80 = intro, $00 = board walk, $ff = options).
    flag__pregame_state: .byte $00

    // BCC7
    counter: // State counters
        .byte $00
        .byte $00
        .byte $00
    curr_phase:
        .byte $00
}

.namespace storage {
    // BCC4
    // Stored stack pointer so that stack is reset on each state update.
    stack_ptr: .byte $00
}

//---------------------------------------------------------------------------------------------------------------------
// Dynamic data is cleared completely on each game state change. Dynamic data starts at BCD3 and continues to the end
// of the data area.
.segment DynamicDataStart
    dynamic_data_start:

.segment DynamicData

.namespace interrupt {
    // BCD3
    // Is set to non zero if the game state should be updated after interrupt ha completed.
    flag__set_new_state: .byte $00
}

.namespace state {
    // BD27
    // Last recorded major jiffy clock counter (256 jiffy counter).
    last_stored_time: .byte $00

    // BD30
    // Pointer to code that will run in the current state.
    curr_fn_ptr: .word $0000

    // BF3D
    // State cycle counters (counts up and down using numbers 0, 2, 6, 8, E and C).
    curr_cycle: .byte $00, $00, $00, $00
}

// Memory addresses used for multiple purposes. Each purpose has it's own label and label description for in-code
// readbility.
.namespace temp {
    // BCFE
    flag__icon_destination_valid: // Action on icon square drop selection
        .byte $00

    // BD26
    data__curr_sprite_ptr: // Current sprite counter
        .byte $00

    // BF1A
    data__temp_store: // Temporary data storage area
        .byte $00
    // BF1B
    ptr__sprite: // Intro sprite data pointer
        .byte $00 // data__temp_store+1
        .byte $00 // data__temp_store+2
        .byte $00 // data__temp_store+3
        .byte $00 // data__temp_store+4
        .byte $00 // data__temp_store+5

    // BF25
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
    
    // BF24
    data__icon_set_sprite_frame: // Frame offset of sprite icon set. Add #$80 to invert the frame on copy.
        .byte $00
}

.segment DynamicDataEnd
    dynamic_data_end:
