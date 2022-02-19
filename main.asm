.filenamespace main
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Archon (c) 1983
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Reverse engineered source code for C64 Archon (c) 1983 by Free Fall Associates.
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
    sta game.flag__ai_player_ctl // AI Off - ie Two player
    sta common.cnt__ai_selection // Select first AI option (off, AI is light, AI is dark)
    sta common.flag__ai_player_selection // Select AI player (00=none, 55=light, AA=dark, FF=both)
    lda #PLAYER_LIGHT_COLOR_STATE
    sta game.data__curr_player_color // Set player color state to light (color 1 - green)
    tsx
    stx private.ptr__stack // Store stack so we can restore it after each game loop (stop memory leaks?)
    lda #FLAG_ENABLE
    sta intro.flag__enable // Allow intro to be played (flag is reset after intro plays so that it isn't played again)
    sta common.flag__pregame_state // Set first intro state - scrolling logos
    .const TWELVE_SECONDS = $03
    lda #TWELVE_SECONDS // Set number of second before game autoplays if no option selected on options page
    sta board.countdown_timer
    //
    lda resources.flag__is_relocated
    bmi !skip+
    jsr resources.relocate // Relocate resources out graphical memory area
!skip:
    jsr private.init // Configure graphics and interrupts
    // ...
// 612C
// The game loop is responsible for initializing the current game. The loop is called after each game state (on
// intro start, on option select, on game start and on game restart).
game_loop:
    // Ensure each game state starts with reset stack, cleared sound, clean graphics and 00's in all variables.
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
    // Set the initial strength of each icon piece.
    // I should explain the board setup matrix here - the matrix contains a 2x18 matix of icons in their initial
    // board square position. It contains 2 full columns of light players and 2 full columns of dark players.
    // The matrix contains icon offsets (see constant.asm file for a list of icon offsets). The offset is basically an
    // offset in to the sprite resource, so $00 is the first sprite group (Unicorn), $01 the second (Wizard) and so
    // on. The matrix contains repeated icons (eg there are 7 Knights, 2 Unicorns etc).
    // There are two types of icon matrices used:
    // - Type: This matrix contains a byte for each type of icon (eg one byte for Unicorn, one for Knight etc). An
    //   example here is the initial strength matrix. Every Knight starts with the same strength, so therefore we
    //   only need to store an initial Knight strength once. The types of matrix are always ordered in offset order.
    // - Piece: This matrix contains a byte for each piece on the board (eg 7 bytes for Knights as there are 7 Knights
    //   on the board). An example is the current strength of each icon. These matrix are ordered in the same order
    //   as the `init_matrix`, which is initial placement order.
    // When reading from a piece matrix, to find the location within a type matrix we simply use the value in the
    // piece matrix (the offset) as an offset in the type matrix. Eg we read initial board matrix position $03 and
    // get a knight offset ($07) and we can then use that value to read the 7th value of any type matrix (eg strength,
    // string description pointer, movement, speed etc) to get that value for a Knight.
    ldx #(BOARD_TOTAL_NUM_ICONS - 1) // 0 offset (this means `0 to (x-1)` instead of `1 to x`)
!loop:
    ldy board.data__piece_icon_offset_list,x
    lda game.data__icon_strength_list,y
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
    // The occupancy matrix is used to keep track of which icon is in which square. Clearing this data effectively
    // removes all icons from the board.
    ldx #(BOARD_SIZE-1) // Empty (9x9 grid) squares (0 offset)
!loop:
    sta board.curr_square_occupancy,x
    dex
    bpl !loop-
    //
    sta game.imprisoned_data__icon_id_list // Clear imprisoned icon (light player)
    sta game.imprisoned_data__icon_id_list+1 // Clear imprisoned icon (dark player)
    //
    // Swap player's turn.
    // The game uses $55 to represent light player and $AA for dark. The reason is that the value can be written to
    // the board border character dot data to represent color 1 (green) or color 2 (blue) to indicate the current
    // player. This is pretty clever - it is how they change the board border color (the ring of characters around
    // the game board) by effectively writing a few bytes in to the character dot data.
    // However, most FALSE/TRUE flags use <$80 for FALSE and >=$80 for TRUE (so can use BMI/BPL). Therefore, copying
    // the player color (eg $55 for light) to `flag__is_light_turn` effectively puts FALSE in this flag therefore
    // indicating that it is the dark players turn.
    lda game.data__curr_player_color
    sta game.flag__is_light_turn
    //
    // Set default board phase color.
    // There are 8 phases (well 6 to be precise - read below) with 0 being the darkesy and 7 the lightest. 3 is in
    // the middle(ish) but slightly on the
    // dark side.
    .const MIDDLE_PHASE = 3
    ldy #MIDDLE_PHASE
    lda board.data__phase_color_list,y // Purple
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
    // Default to copying individual icon frames only when creating a sprite set for a selected icon when using
    // the `add_sprite_to_graphics` function.
    // An animation group contains animations for movement in all directions, attack animation and projectile
    // animations.
    // We only need the full sprite sets in the battle arena, so for now, we'll default this feature to off.
    lda #FLAG_DISABLE
    sta common.param__is_copy_animation_group
    //
    lda #FLAG_DISABLE
    sta intro.flag__enable // Don't play intro again
    lda TIME+1
    sta game.last_stored_time // Store time - used to start an AI vs AI game if we timeout on the options page
    //
    // Clear used spell flags.
    .const NUMBER_SPELLS = 7
    ldx #(NUMBER_SPELLS*2-1) // (0 based)
    lda #SPELL_UNUSED
!loop:
    sta magic.flag__light_used_spells_list,x
    dex
    bpl !loop-
    //
    // Set the board by placing an index in to `board.init_matrix` list in each initially occupied square. The initial
    // matrix contains a list of all icons in the correct board order (light in top part of list, dark in bottom).
    // Therefore, writing 00 in square 1 will add a Valkyrie (first item in the init_matrix), 01 an archer and so on.
    // The below creates a board occupancy matrix as follows (where $80 is empty):
    //   00 01 80 80 80 80 80 12 13
    //   02 03 80 80 80 80 80 14 15
    //   04 05 80 80 80 80 80 16 17
    //   06 07 80 80 80 80 80 18 19
    //   08 09 80 80 80 80 80 1A 1B
    //   0A 0B 80 80 80 80 80 1C 1D
    //   0C 0D 80 80 80 80 80 1E 1F
    //   0E 0F 80 80 80 80 80 20 21
    //   10 11 80 80 80 80 80 22 23
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
    cpx #BOARD_SIZE
    bcc !row_loop-
    //
    lda game.data__curr_player_color // 55 for light, aa for dark
    eor #$FF // So now we have >=$80 for light and <$80 for dark player
    sta game.flag__is_phase_towards_dark // Phase state and direction
    sta game.flag__is_light_turn // Set current player
    //
    // The board has an even number of phases (8 in total, but two are disabled, so 6 in reality), therefore we cannot
    // select a true "middle" starting point for the game (as we have an even number of phases). Instead, we choose
    // the phase on the darker side if light is first or the lighter side if dark is first. This should reduce any
    // advantage that the first player has.
    // Further, the phase direction (from light to dark or vice versa) starts in the favor of the second player.
    // The phase starts in the direction of light to dark if light is first and dark to light if dark is first.
    // OK, lets explain phases here... the game transitions between phases as time goes on. On the board, the phases
    // go from light to dark and then dark to light and light to dark again and so on. The phases are used to show the
    // color in the middle of the board. A light player is stronger in light phases and vice versa. Phases are also
    // used in the battle arena to add, remove and change obstacles within the arena.
    // The phases count up in increments of 2 (ie 0, 2, 6, 8, C and E). This is to simplify the logic within the
    // battle arena. However for the board phases, we really want to step up in increments of 1. So here we have to
    // divide the phase by 2 to determine the phase color index.
    // Oh and notice it jumps from 2 to 6 and 8 to C - there are two phases (and 2 colors) that arent used at all.
    // These can be enabled and the game works with 2 additional board and arena obstacle colors which is cool.
    .const LIGHT_PHASE_X2 = 06
    lda #LIGHT_PHASE_X2
    ldy game.flag__is_light_turn
    bpl !next+
    clc
    adc #$02 // Make phase darker
!next:
    sta game.data__phase_cycle_board
    lsr // Remember we need to divide by 2 to get the color index
    tay
    lda board.data__phase_color_list,y
    sta game.curr_color_phase // Purple if light first, green if dark first
    //
    // Let's play!
    jsr common.clear_screen
    jmp game.entry

// 4766
// Copies the game state pointers (into, game, challenge) to data memory. The pointers are called at the end of each
// game state (ie the intro end, a player turn completes or a challenge completes). I assume the addresses are copied
// so that they can be replaced while debugging.
prep_game_states:
    .const NUMBER_GAME_STATES = 3
    ldx #(NUMBER_GAME_STATES * 2 - 1) // (0 based)
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
    // code to be added in runtime without overwriting used memory/code.
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
