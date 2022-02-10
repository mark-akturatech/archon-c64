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
// - The source does not include any original logic that moves code around. The code below has been developed so that
//   all code remians in place. This is to aide readability and also alows easy addition or modification of code.
//   We do need to move around some sprite resources though to fit within memory. See `Resources` section below.
// - The source uses the same data memory addresses for different purposes. For example `$BF24` may store the current
//   color phase, a sprite animation frame or a sprite x position offset. To simplify code readability, we have
//   added multiple lables to the same memory address.
//   TODO: MIGHT MAKE THESE SEPARATE MEMORY IF WE HAVE ENOUGH SPACE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
//
.segmentdef Assets [startAfter="Game"]
.segmentdef RelocatedResources [startAfter="Assets", virtual]
//
.segmentdef Data [start=$c000, virtual] // Data set once on game initialization
.segmentdef DynamicDataStart [startAfter="Data", virtual] // Data that is reset on each game state change
.segmentdef DynamicData [startAfter="DynamicDataStart", virtual]
.segmentdef DynamicDataEnd [startAfter="DynamicData", virtual]
//

//---------------------------------------------------------------------------------------------------------------------
// Output File
//---------------------------------------------------------------------------------------------------------------------
// Save all segments to a prg file except the virtual data segments.

.file [name="main.prg", segments="Upstart, Resources, Main, Common, Intro, Game, Assets"]

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
// Resources
//---------------------------------------------------------------------------------------------------------------------
// OK this is a little bit special. Archon loads a single file including all resources. The resources have a large
// number of sprites for the various movement and battle animations. Memory managament is therefore quite complex.
// 
// Archon requires 2 character maps and screen in the first 4k of graphics memory (there are lots of characters for
// each icon and logos etc) and spites in the second 4k (there are lots of sprites - enough for 2 characters to battle
// and throw projectiles and animate 4 directions and animate firing). Anyway, so this means we need 8k.
//
// We have limited options for placing graphics memory...VICII allows bank 0 ($0000), bank 1 ($4000), bank 2 ($8000)
// and bank 3 ($C000)...
// - We can use bank 0 however this is a little messy as we'd need to relocate the code that loads at $0801 onwards as
//   the graphics will take up to $3000.
// - We can use bank 1 however this requires us to either leave a big part of memory blank when we load the game (as the
//   game loads at $0801 and continues through to a little over $8000) or relocate code after the game loads.
// - We can use bank 2 however the code game loads past this point, so we'd need to relocate some code or assets in
//   this area to $C000+.
// - We can't use $C000 as this will take up $C000-$DFFF - we need registers in $D000 range to control graphics and
//   sound.
// 
// The simplest solution here is to use bank 2 then locate sprite assets at the end of the application and relocate
// after application load. HOWEVER, the original source uses bank 1, so for consistency we will do the same.
// 
// The original source loads sprites in to memory just after $0801 up to $4000. It then loads the character maps in
// place ($4000-$43ff and $4800-$4fff), and has the remaining sprites (and some music data) from $5000 to $5fff. 
// The data between $5000 to $5fff is relocated to memory under basic ROM after the application starts using code
// fitted between $4400 and $47ff. $4400-$47ff and $5000-$5fff is then cleared.
//
// So even though we are not trying to generate a byte for byte replication of the original source locations, we'll do
// something similar here as well for consistency.
//
// Our memory map will look like this...
//  - sprites - logo: start: $0900; length: $1c0; end: $0ac0
//  - sprites - projectile: length: $251; end: $0d11
//  - Sprites - icons: length: $3191; end: $3ea2
//  - charset - intro: start: $4000; length: $3ff; end: $4400
//  - charset - game: start: $4800; length: $7ff; end: $4fff
//  - sprites - elemetals; start: $5000; length: $ca7; end: $5ca7
.segment Resources

// BACB
// Sprites used by title page.
// Sprites are contained in the following order:
// - 0-3: Archon logo (in 3 parts)
// - 4-6: Freefall logo (in 2 parts)
res__sprites_logo: .import binary "/assets/sprites-logos.bin"

// BACB
// Sprites used by icons as projectiles within the battle arena.
// The projectiles are only small and consume 32 bytes each. There is not a projectile sprite per icon as may
// icons reuse the same projectile.
res__sprites_projectile: .import binary "/assets/sprites-projectiles.bin"

// BAE-3D3F
// Icon sprites. Note that sprites are not 64 bytes in length like normal sprites. Archon sprites are smaller so
// that they can fit on a board sqare and therefore do not need to take up 64 bytes. Instead, sprites consume 54
// bytes only. The positive of this is that we use less memory for each sprite. The negative is that we can't just
// load the raw sprite binary file in to a sprite editor.
// Anyway, there are LOTS of sprites. Generally 15 sprites for each icon. This includes fram animations in each
// direction, shoot animations and projectiles. NOTE that spearate frames for left moving and right moving
// animations. Instead, the routine used to load sprites in to graphical memory has a function that allows
// sprites to be mirrored when copied.
res__sprites_icon: .import binary "/assets/sprites-icons.bin"

// Embed character map in place
*=CHRMEM1 "Character set 1"
#if INCLUDE_INTRO
    .import binary "/assets/charset-intro.bin"
#endif
*=CHRMEM2 "Character set 2"
.import binary "/assets/charset-game.bin"

//---------------------------------------------------------------------------------------------------------------------
// All resources stored at this point will need to be relocated after the game has loaded.
// Logic will copy all data from `relocated_resource_source_start` up until `relocated_resource_source_end` to
// destination `relocated_resource_destination_start`.
// The pseudo operator below will ensure that references to any labels within this section will point to destination
// address.
*=GRPMEM "=Relocated="
relocated_resource_source_start:
.pseudopc relocated_resource_destination_start {
    // AE23-BACA
    // Icon sprites for the 4 summonable elementals. The sprites are arranged the same as `res__sprites_icon`.
    res__sprites_elemental: .import binary "/assets/sprites-elementals.bin"
}
relocated_resource_source_end:

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
    stx stack_ptr_store
    lda #FLAG_ENABLE
    sta flag__enable_intro // Play intro
    sta curr_pre_game_progress // Pregame state ($80 is intro)
    lda #$03 // Set number of large jiffies before game auto plays after intro (~12s as each tick is ~4s)
    sta board.countdown_timer

    lda flag__is_initialized
    bmi skip_prep
    jsr prep
skip_prep:
    jsr init

restart_game_loop:
    // Ensure each game state starts with cleared sound, clean graphics and 00's in all dynamic variables.
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

    jsr common.clear_screen
    jsr common.clear_sprites

    // Set the initial strength of each icon.
    ldx #(BOARD_TOTAL_NUM_ICONS - 1) // Total number of icons (0 offset)
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
    ldy #$03 // There are 8 phases (0 to 7) with 0 being the darked and 7 the lighted. $03 is in the middle.
    lda board.data.color_phase,y
    sta game.curr_color_phase

#if INCLUDE_INTRO
    // Display the game intro (bouncing Archon).
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

    // Configure graphics.
    // Set text mode character memory to $0800-$0FFF (+VIC bank offset as set in CI2PRA).
    // Set character dot data to $0400-$07FF (+VIC bank offset as set in CI2PRA).
    lda #%0001_0010
    sta VMCSB
    // Enable multicolor text mode.
    lda SCROLX
    ora #%0001_0000
    sta SCROLX

#if INCLUDE_INTRO
    // Display the board intro (walking icons).
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
    sta flag__enable_intro // Display game options
    lda TIME+1
    sta state.last_stored_time // Store time - used to start game if timeout on options page

    // Clear used spell flags.
    ldx #$0D // 7 spells per size (14 total - zero based)
    lda #SPELL_UNUSED
!loop:
    sta magic.flag__light_used_spells,x
    dex
    bpl !loop-

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

    // Let's play!
    jmp game.entry

// 4700
prep:
    // Indicate that we have initialised the app, so we no don't need to run `prep` again if the app is restarted.
    lda #FLAG_ENABLE
    sta flag__is_initialized

    // We only handle interrupts when the raster fires. So here we store the default system interrupt handler so that
    // we can call whenever a non-raster interrupt occurs.
    lda CINV
    sta interrupt.system_fn_ptr
    lda CINV+1
    sta interrupt.system_fn_ptr+1

    // move resources out of graphics memory to the end of the application
    lda #<relocated_resource_source_start
    sta FREEZP
    lda #>relocated_resource_source_start
    sta FREEZP+1
    lda #<relocated_resource_destination_start
    sta FREEZP+2
    lda #>relocated_resource_destination_start
    sta FREEZP+3
    // copy chunks of $ff bytes
    ldy #$00
    ldx #>(relocated_resource_source_end - relocated_resource_source_start)
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+1
    inc FREEZP+3
    dex
    bne !loop-
    // copy remaining bytes
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    cpy #<(relocated_resource_source_end - relocated_resource_source_start)
    bcc !loop-
    rts

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

    // Enable data direction bits for setting VICII memory bank.
    lda C2DDRA
    ora #%0000_0011
    sta C2DDRA

    // Set memory bank.
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
    // Raster interrupt handler function pointer. This pointer is updated during game play to handle state specific
    // background functions such as animations, detection of joystick inputs, delays and so on.
    raster_fn_ptr: .word $0000

    // BCCE
    // System interrupt handler function pointer. This pointer is calls a minimalist handler that really does nothing
    // and is used to ensure the game runs at optimum speed.
    system_fn_ptr: .word $0000

    // BCD0
    flag__enable: .byte $00 // Is set to $80 to indicate that the game state should be changed to the next state
}

.namespace state {
    // BCC7
    counter: // State counters
        .byte $00
        .byte $00
        .byte $00
    curr_phase:
        .byte $00
}

//---------------------------------------------------------------------------------------------------------------------
// Resources from $5000 to $5fff will be relocated here.
.segment RelocatedResources
    relocated_resource_destination_start:

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
    // State cycle counters (counts up and down using numbers 0, 2, 6, 8, E and C)
    curr_cycle: .byte $00, $00, $00, $00
}

// Memory addresses used for multiple purposes. Each purpose has it's own label and label description for in-code
// readbility.
.namespace temp {
    // BCEE
    flag__alternating_state: // Alternating state flag (alternates between 00 and FF)
    data__curr_frame_adv_count: // Counter used to advance animation frame (every 4 pixels)
        .byte $00

    // BCF2
    curr_debounce_count: // Current debounce counter (used when debouncing fire button presses)
    curr_battle_square_color: // Current color of square in which a battle is being faught
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
    flag__is_valid_square: // is TRUE if a surrounding square is valid for movement or magical spell
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
    data__dead_icon_count: // Number of dead icons in the dead icon list.
        .byte $00
}

.segment DynamicDataEnd
    dynamic_data_end:
