#import "io.asm"
#import "const.asm"

//---------------------------------------------------------------------------------------------------------------------
// Display introduction (title) page
//---------------------------------------------------------------------------------------------------------------------
.segment Intro
intro:
    jsr intro_import_charset
    jsr clear_screen
    jsr clear_sprites
    jsr intro_import_sprites
    jsr intro_configure
    rts

// import the title charset in to the lower character memory
intro_import_charset:
    lda #<title_charset
    sta FREEZP
    lda #>title_charset
    sta FREEZP+1
    lda #<CHRMEM1
    sta FREEZP+2
    lda #>CHRMEM1
    sta FREEZP+3
    ldx #$02
    jmp block_copy    

// ok so the original code seems to be decrypted or something. is way too complex for my little brain. so here we
// include a simplified version of the sprite loader.
intro_import_sprites:
    lda #<sprite_locations
    sta FREEZP
    lda #>sprite_locations
    sta FREEZP+1
    lda #<title_sprites
    sta FREEZP+2
    lda #>title_sprites
    sta FREEZP+3
    jmp move_sprites

intro_configure:
    // configure screen
    lda SCROLX
    and #%1110_1111     // multicolor bitmap mode off
    sta SCROLX
    lda #%0001_0000     // $0000-$07FF char memory, $0400-$07FF screen memory
    sta VMCSB

    // configure sprites
    lda #%0000_1111     // first 4 sprites multicolor; last 4 sprints single color
    sta SPMC
    lda #%1111_0000     // first 4 sprites double width; last 4 sprites single width
    sta XXPAND
    lda #%1111_1111     // enable all sprites
    sta SPENA

    // set interrupt handler to set intro loop state
    sei
    lda #<intro_state_interrupt_handler
    sta interruptPointer.system
    lda #>intro_state_interrupt_handler
    sta interruptPointer.system+1
    cli

    // black border and background
    lda #BLACK
    sta EXTCOL
    sta BGCOL0

    // set game state to intro
    sta new_game_state

    // set multicolor sprite second color
    lda #YELLOW // NOTE - TODO: original source loads this from A988 <- WHY? does this routine get calle dmultiple times?
    sta SPMC0
    sta SPMC1

    // configure the starting intro state function
    lda #<intro_state__scroll_title
    sta intro_state_handler_pointer
    lda #>intro_state__scroll_title
    sta intro_state_handler_pointer+1

    jsr intro_loop
    rts

intro_state_interrupt_handler:
    lda game_state
    bpl intro_process_state
    jmp quick_interupt_handler
intro_process_state:
    lda new_game_state
    sta game_state
    jsr intro_set_state
    jmp (intro_state_handler_pointer)

// called by the game state interrupt handler - $AC16
// i edited the source to stop this being called and it did two things...
// - no music
// - the intro has sub states (like slide in title, bounce title etc). it only did the first sub state (slide in title)
intro_set_state:
    rts

// main loop - $905C
intro_loop:
    lda #$00
    sta game_state
!loop:
    jsr check_keypress
    jsr check_stop
    lda game_state
    beq !loop-
    //jmp $7fab // TODO
    rts

check_stop: 
    // go to next state of ESC
    jsr STOP
    beq step_state // Escape pressed
    // go straight to options on Q key press
    cmp #KEY_Q 
    bne !return+
    // wait for key to be released
!loop: 
    jsr STOP
    cmp #KEY_Q
    beq !loop-
    //... TODO: jump to options state - JSR $63F3; JMP $612C
    rts // todo remove
step_state:
    lda new_game_state
    eor #$ff
    sta new_game_state
!loop:
    jsr STOP
    beq !loop-
!return:
    rts


// called by the game state interrupt handler - ($BCCC)
// Pretty sure this does the intro sub state - eg BCCC is first set to slide in the title
intro_state__scroll_title:
    // way this seems to work...
    // AA56
    // ...
    // ac5b: 
    // calls $a13e - returns sub state state


    jmp quick_interupt_handler

//---------------------------------------------------------------------------------------------------------------------
// Local Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// pointer to the routine used to handle the current game state
intro_state_handler_pointer: .word $0000

// Represents the sprite locations within grapphics memory that each sprite will occupy. See comment on
// `title_sprites` for a list of which sprite occupies which slot. The first word represents the first sprite, second
// word the second sprite and so on. The sprite location is calculated by adding the offset to the GRPMEM location.
// The location list is ffff terminated.
sprite_locations:
    .word $0000, $0040, $0080, $00C0, $0100, $0140, $0180, $0600
    .word $0640, $0680, $06C0, $0700, $0740, $0780, $07C0, $0800
    .word $0840, $0880, $08C0, $0900, $0940, $0980, $09C0, $ffff

//---------------------------------------------------------------------------------------------------------------------
// Binaries
//---------------------------------------------------------------------------------------------------------------------
.segment Binaries

// char set used by title page
title_charset: .import binary "/assets/charset-intro.bin"

// sprites used by title page
// sprites are contained in the following order:
// - 0-3: archon logo
// - 4-6: free fall logo
// - 7-10: left facing knight animation frames
// - 11-14: left facing troll animation frames
// - 15-18: right facing golum animation frames
// - 19-22: right facing goblin animation frames
title_sprites: .import binary "/assets/sprites-intro.bin"
