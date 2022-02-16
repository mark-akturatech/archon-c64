.filenamespace main
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Archon (c) 1983
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Reverse engineer of C64 Archon (c) 1983 by Free Fall Associates.
//
// Full resepct to the awesome authors:
// - Anne Westfall, Jon Freeman, Paul Reiche III
//
// THANK YOU FOR MANY YEARS OF MEMORABLE GAMING. ARCHON ROCKS AND ALWAYS WILL!!!
//
// See README.md file for additional information.

//---------------------------------------------------------------------------------------------------------------------
// Memory map
//---------------------------------------------------------------------------------------------------------------------
//
.segmentdef Upstart
//
.segmentdef Resources [startAfter="Upstart"]
//
.segmentdef Main [startAfter="Resources", min=$6000]
.segmentdef Common [startAfter="Main"]
.segmentdef Intro [startAfter="Common"]
.segmentdef Game [startAfter="Intro"]
.segmentdef CodeBase [segments="Main, Common, Intro, Game", hide]
//
.segmentdef Assets [startAfter="Game"]
.segmentdef RelocatedResources [startAfter="Assets", virtual, hide]
//
.segmentdef Data [start=$c000, virtual] // Data set once on game initialization
.segmentdef VariablesStart [startAfter="Data", virtual, hide] // Data that is reset on each game state change
.segmentdef Variables [startAfter="VariablesStart", virtual]
.segmentdef VariablesEnd [startAfter="Variables", virtual, hide]

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
// - `common`: Library of subroutines and assets used by the intro, board and battle arean states.
// - `intro`: Subroutines and assets used by the introduction.
// - `board_walk`: Subroutines and assets used during the introduction to walk icons on to the board.
// - `game`: Subroutines and assets used during main game play.
// - `board`: Subroutines and assets used to render the game board.
// - `magic`: Subroutines and assets used to select and cast spells.
// - `challenge`: Subroutines and assets used during challenge and battle erena game play.
// - `ai`: Subroutinues used for AI in board and challenge game play.
// - `io`: Standard C64 memory and IO addresses using "MAPPING THE Commodore 64" constants names.
// - `const`: Game specific constants.

#import "src/io.asm"
#import "src/const.asm"
#import "src/resources.asm"
#import "src/common.asm"
#import "src/intro.asm"
#import "src/board_walk.asm"
#import "src/game.asm"
#import "src/board.asm"
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
    sta common.options.cnt__ai_player_selection // Count is used to toggle between 3 options - select 1st option (none)
    sta common.options.flag__ai_player_ctl // 00=none, 55=light, AA=dark, FF=both
    lda #PLAYER_LIGHT
    sta game.state.flag__is_first_player_light // Light player first
    tsx
    stx private.ptr__stack // Store stack so we can restore it after each game loop (stop memory leaks?)
    lda #FLAG_ENABLE
    sta intro.flag__enable // Allow intro to be played (is reset after intro plays so that it isn't played again)
    sta common.flag__pregame_state // First intro state - scrolling logos
    .const TWELVE_SECONDS = $03
    lda #TWELVE_SECONDS // Set number of second before game autoplays if no option selected on options page
    sta board.countdown_timer
    //
    lda resources.flag__is_relocated
    bmi !skip+
    jsr resources.relocate // Relocate loaded resources out graphical memory area
!skip:
    jsr private.init // Configure graphics and interrupts
    // ...
// 612C
// The game loop is responsible for initializing the current game. The loop is called after each game phase (on
// intro start, on option select, on game start and on game restart).
game_loop:
    // Ensure each game state starts with reset stack, cleared sound, clean graphics and 00's in all dynamic variables.
    ldx private.ptr__stack
    txs
    jsr common.stop_sound
    // Clears variable storage area.
    // Note that the logic below will clear past the end of the storage area up to #$ff. This is probably done as it
    // may be more efficient to clear a little bit of extra memory instead of having additional logic to clear the
    // exact number of bytes.
    lda #<private.ptr__variables_start
    sta FREEZP+2
    lda #>private.ptr__variables_start
    sta FREEZP+3
    ldx #(>(private.ptr__variables_end - private.ptr__variables_start))+1
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
    // I should explain the board matrix here - the board matrix contains a 2x18 matix of icons in their initial board
    // position. It contains the 2 full columns of light players and then 2 full columns of dark players.
    // The matrix uses icon offsets (see constant.asm file for a list of icon offsets). The offset is basically an
    // offset in to the sprite resource, so $00 is the first sprite group (Unicorn), $01 the second (Wizard) and so
    // on.
    // All other icon matrices are therefore ordered in the same way. So `init_strength` has Unicorn as first byte,
    // Wizard as second and so on.
    ldx #(BOARD_TOTAL_NUM_ICONS - 1) // Total number of icons (0 offset)
!loop:
    ldy board.icon.init_matrix,x
    lda game.icon.init_strength,y
    sta game.curr_icon_strength,x
    dex
    bpl !loop-
    //    
    // Skip 618B to 6219 as this just configures pointers to various constant areas - like pointers to each board row
    // tile color scheme or row occupancy. We have instead included these as assets as it is much more readable.
    // 621A
    lda #FLAG_ENABLE
    sta common.flag__enable_next_state // Force any running interrupt routines to exit
    //
    // Clear board square occupancy data.
    ldx #(BOARD_NUM_COLS*BOARD_NUM_ROWS-1) // Empty (9x9 grid) squares (0 offset)
!loop:
    sta board.curr_square_occupancy,x
    dex
    bpl !loop-
    //
    sta game.imprisoned_data__icon_id_list // Clear imprisoned icon (light player)
    sta game.imprisoned_data__icon_id_list+1 // Clear imprisoned icon (dark player)
    lda game.state.flag__is_first_player_light // Set first player
    sta game.state.flag__is_light_turn // Set current turn (first player)
    //
    // Set default board phase color.
    .const MIDDLE_PHASE = 3 // There are 8 phases with 0 being the darked and 7 the lighted. 3 is in the middle(ish).
    ldy #MIDDLE_PHASE
    lda board.data.color_phase,y // Purple
    sta game.curr_color_phase 
    //
    // Display the game intro if it hasn't already been played.
    lda intro.flag__enable
    beq !skip+
    jsr play_intro
!skip:
    //
    // Configure SID.
    lda #$08
    sta PWHI1
    sta PWHI2
    lda #$40
    sta FRELO3
    lda #$0A
    sta FREHI3
    lda #%1000_0001 // Configure voice 3 as noise waveform
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
    // Display the board intro (walking icons to each square).
    lda intro.flag__enable
    beq !skip+
    jsr board_walk.entry
!skip:
    //
    lda #FLAG_DISABLE
    sta common.sprite.flag__copy_animation_group // Animation groups only copied in challenge
    lda #FLAG_DISABLE // Not necessary
    sta intro.flag__enable // Don't play intro again
    lda TIME+1
    sta game.last_stored_time // Store time - used to start game if timeout on options page
    //
    // Clear used spell flags.
    .const NUMBER_SPELLS = 7
    ldx #(NUMBER_SPELLS*2-1) // Total spells (14 total - zero based)
    lda #SPELL_UNUSED
!loop:
    sta magic.flag__light_used_spells,x
    dex
    bpl !loop-
    //
    // Set the board - This is done by setting each square to an index into the initial matrix which stores the icon in
    // column 1, 2 each row for light player and then repeated for dark player. The code below reads the sets two icons
    // in the row, clears the next 5 and then sets the last 2 icons and repeats for each row.
    lda #BOARD_NUM_PLAYER_ICONS
    sta private.idx__dark_icon_type // Matrix for dark icons is stored directly after light icons
    lda #$00
    sta private.idx__light_icon_type
    tax
!row_loop:
    // 2 light player squares.
    ldy #$02
!loop:
    lda private.idx__light_icon_type
    sta board.curr_square_occupancy,x
    inc private.idx__light_icon_type
    inx
    dey
    bne !loop-
    // 5 empty squares.
    ldy #$05
    lda #BOARD_EMPTY_SQUARE
!loop:
    sta board.curr_square_occupancy,x
    inx
    dey
    bne !loop-
    // 2 dark player squares.
    ldy #$02
!loop:
    lda private.idx__dark_icon_type
    sta board.curr_square_occupancy,x
    inc private.idx__dark_icon_type
    inx
    dey
    bne !loop-
    cpx #(BOARD_NUM_COLS*BOARD_NUM_ROWS)
    bcc !row_loop-
    //
    // The board has an even number of phases (8 in total, but two are disabled, so 6 in reality), the we cannot
    // select a true "middle" starting point for the game (as we havve an even number of phases). Instead, we choose
    // the phase on the darker side if light is first or the lighter side if dark is first. This should
    // reduce any advantage that the first player has.
    // Further, the phase direction (from light to dark or vice versa) starts in the favor of the second player.
    // The phase starts in the direction of light to dark if light is first and dark to light if dark is first.
    lda game.state.flag__is_first_player_light
    eor #$FF
    sta game.flag__phase_direction_board // Phase state and direction (lighter if dark first, darker if light first)
    sta game.state.flag__is_light_turn // Set current player // TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WHY IS IT INVERTED
    // Set starting board color.
    lda #$06 // TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! FIGURE OUT WHY / 2
    ldy game.state.flag__is_light_turn
    bpl !next+
    clc
    adc #$02
!next:
    sta game.data__phase_cycle_board // TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WHY IS PHASE 2x!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    lsr
    tay
    lda board.data.color_phase,y
    sta game.curr_color_phase // Purple if light first, green if dark first
    //
    // Let's play!
    jsr common.clear_screen
    jmp game.entry

// 4766
// Copies the game state pointers (into, game, challenge) to data memory. The pointers are called at the end of each
// game loop (ie the intro end, a player turn completes or a challenge completes). I assume the addresses are copied
// so that they can be dynamically replaced while debugging.
prep_game_states:
    .const NUMBER_GAME_STATES = 3
    ldx #(NUMBER_GAME_STATES * 2 - 1) // Zero based
!loop:
    lda private.ptr__game_state_fn_list_source,x
    sta private.ptr__game_state_fn_list,x
    dex
    bpl !loop-
    rts

// 8010
play_game:
    jmp (private.ptr__game_state_fn_list)

// 8013
play_challenge:
    jmp (private.ptr__game_state_fn_list+2)

// 8016
play_intro:
    jmp (private.ptr__game_state_fn_list+4)

//---------------------------------------------------------------------------------------------------------------------
// Private functions.
.namespace private {
    // 632D
    init:
        // Set VIC memory bank.
        // Original code uses the first 8kb of Bank #1 ($4000-$5FFF)
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
        // contains a half set only and therefore occupies only half of the memory of a full character set.
        //
        // Set VICII memory bank.
        lda C2DDRA
        ora #%0000_0011
        sta C2DDRA // Enable data direction bits for setting graphics memory bank
        lda CI2PRA
        and #%1111_1100
        ora #VICBANK
        sta CI2PRA // Set graphics memory bank
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
        // Configure interrupt handler routines.
        // The interrupt handler calls the standard system interrupt if a non-raster interrupt is detected. If a raster
        // interrupt occurs, we will initially call a minimalist interrupt routine. This routine will be replaced with
        // other function specific routines throughout the application runtime (eg to handle joystick input, animations)
        // etc. We use the raster interrupt as this allows us to trigger at the same time interval as the display is
        // updated at a regular and consistent interval.
        sei // ensure interrupts are disabled while we are configuring them
        lda #<common.complete_interrupt
        sta ptr__raster_interrupt_fn
        lda #>common.complete_interrupt
        sta ptr__raster_interrupt_fn+1
        lda IRQMASK
        and #%0111_1110 // Disable raster interrupts
        sta IRQMASK
        // Set interrupt handler.
        // The code below looks a bit odd but it written this way to give the authors the ability to dynamically
        // modify or add to the interceptor without overwriting any existing logic.
        lda #<interrupt_interceptor
        jsr set_partial_interrupt
        nop
        nop
        sta CINV+1
        // Set raster line used to trigger a raster interrupt.
        // As there are 262 lines, the line number is set by setting the highest bit of $D011 (SCROLY) and the 8 bits
        // in $D012 (RASTER).
        lda SCROLY
        and #%0111_1111
        sta SCROLY
        lda #251
        sta RASTER
        // Reenable interrupts.
        lda IRQMASK
        ora #%1000_0001
        sta IRQMASK
        cli
        rts

    // BC8B
    // Since this routine is at the end of the application, I am guessing this function allows additional debugging
    // code to be added in runtime. 
    // Requires:
    // - A: Low byte of interrupt interceptor function memory address
    // Sets:
    // - A: High byte of interrupt interceptor function memory address
    set_partial_interrupt:
        sta CINV
        sta CBINV
        lda #>interrupt_interceptor
        sta CBINV+1
        rts

    // 637E
    // Check if the raster interrupt has occurred and call the appropriate interrupt handlers.
    // This funciton is called on each interrupt.
    interrupt_interceptor:
        lda VICIRQ
        and #%0000_0001
        beq !next+ // Non-raster interrupt?
        // Many games use this approach to run interrupts on a fixed time based schedule. In previous logic we hooked
        // in to the raster interrupt and configured it to trigger an interrupt on every 251st raster. The screen
        // is drawn at regular intervals and therefore we know that this interrupt will also occur at a regular
        // interval.
        // So now any of our logic just needs to update the `ptr__raster_interrupt_fn` location to point to an
        // an interrupt handler and boom, we can play music at a regular beat or animate icons at a regular frame
        // rate or perform any matter of background time based task.
        sta VICIRQ // Writing to VICIRQ will allow further raster interrupts to occur
        jmp (ptr__raster_interrupt_fn)
    !next:
        jmp (ptr__system_interrupt_fn)
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
// Assets are constant data. Assets are permanent and will not change during the program lifetime.
.segment Assets

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 4760
    // Pointer to each main game function.
    ptr__game_state_fn_list_source:
        .word game.interrupt_handler
        .word challenge.interrupt_handler
        .word intro.entry
}

//---------------------------------------------------------------------------------------------------------------------
// Data in this area are not cleared on state change.
//---------------------------------------------------------------------------------------------------------------------
// Dynamic data typically starts at BCC0 and continues to BCD2, however some lower addresses are used within the
// application.
.segment Data

// BCCC
// Raster interrupt handler function pointer. This pointer is updated during game play to handle state specific
// background functions such as animations, detection of joystick inputs, delays and so on.
ptr__raster_interrupt_fn: .word $0000

// BCCE
// Pointer to default kernal system interrupt handler.
ptr__system_interrupt_fn: .word $0000

//---------------------------------------------------------------------------------------------------------------------
// Private data.
.namespace private {
    // 0334
    // Pointer to each main game function copied from the function list source. I assume they do this so that they can
    // repoint the function pointers after the game has loaded for testing and debugging purposes.
    ptr__game_state_fn_list: .word $0000, $0000, $000

    // BCC4
    // Stored stack pointer so that stack is reset on each state update.
    ptr__stack: .byte $00
}

//---------------------------------------------------------------------------------------------------------------------
// Variable data is cleared completely on each game state change. 
//---------------------------------------------------------------------------------------------------------------------
// Variable data starts at BCD3 and continues to the end of the data area.
//
// The variable data memory block is flanked by `VariablesStart` and `VariablesEnd`, allowing us to dynamically
// calculate the size of the memory block at compilation time. This is then used to clear the variabe data at the
// start of each game loop.

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    .segment VariablesStart
    ptr__variables_start:

    .segment Variables
    // ... Variables within other files will be inserted here ...

    // BF1A
    // Index in to the matrix of dark icon types.
    idx__dark_icon_type: .byte $00

    // BF1B
    // Index in to the matrix of light icon types.
    idx__light_icon_type: .byte $00

    .segment VariablesEnd
    ptr__variables_end:
}
