.filenamespace intro

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for displaying and animating the introduction/title sequence page.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Intro

// A82C
entry:
    jsr common.clear_sprites 
    jsr import_sprites
    jsr common.initialize_music

    // Configure screen.
    lda SCROLX
    and #%1110_1111     // multicolor bitmap mode off
    sta SCROLX
    lda #%0001_0000     // $0000-$07FF char memory, $0400-$07FF screen memory
    sta VMCSB

    // Configure sprites.
    lda #%0000_1111     // first 4 sprites multicolor; last 4 sprints single color
    sta SPMC
    lda #%1111_0000     // first 4 sprites double width; last 4 sprites single width
    sta XXPAND
    lda #%1111_1111     // enable all sprites
    sta SPENA

    // Set interrupt handler to set intro loop state.
    sei
    lda #<interrupt_handler
    sta main.interruptPtr.system
    lda #>interrupt_handler
    sta main.interruptPtr.system+1
    cli

    // black border and background
    lda #$00
    sta state.counter
    sta EXTCOL
    sta BGCOL0

    // set multicolor sprite second color
    lda sprite.color
    sta SPMC0
    sta SPMC1

    // configure the starting intro state function
    lda #<state__scroll_title
    sta state.fn_ptr
    lda #>state__scroll_title
    sta state.fn_ptr+1

    jsr common.wait_for_key
    rts    

// A98F
// Imports sprites in to graphics area.
// NOTE I am not using the original source code to do this. It is very dependent on location and uses sprites stored
// in a non standard way (I could be wrong here). Instead, i have a direct sprite.bin file and copy the sprites in to
// the correct location using a flexible matrix copy function described in the `unofficial.asm` file.
import_sprites:
    not_original: {
        lda #<sprite.offset
        sta FREEZP
        lda #>sprite.offset
        sta FREEZP+1
        lda #<sprite.source
        sta FREEZP+2
        lda #>sprite.source
        sta FREEZP+3
        jsr unofficial.move_sprites
    }

    // AA09
    // Pointer to first sprite: 64 bytes per sprite, start at graphmem offset. we add 6 as we are setting the first
    // 6 (of 8) sprites (and we work backwards from 6).
    .const NUM_SPRITES = 6
    lda #(VICGOFF / BYTES_PER_SPRITE) + NUM_SPRITES
    sta sprite.data_ptr
    ldx #NUM_SPRITES
!loop:
    txa
    asl
    tay
    lda sprite.data_ptr
    sta SPTMEM,x
    dec sprite.data_ptr
    lda sprite.color,x
    sta SP0COL,x
    lda sprite.x_pos,x
    sta SP0X,y
    sta sprite.curr_x_pos,x
    lda sprite.y_pos,x
    sta SP0Y,y
    sta sprite.curr_y_pos,x
    dex
    bpl !loop-
    // Final y-pos of Archon title sprites afters animate from bottom of screen.
    lda #$45
    sta sprite.final_y_pos
    // Final y-pos of Freefall logo sprites afters animate from top of screen.
    lda #$DA
    sta sprite.final_y_pos+1
    rts

// AA42
interrupt_handler:
    lda common.state.current
    bpl !next+
    jmp common.complete_interrupt
!next:
    lda common.state.new
    sta common.state.current
    jsr common.play_music
    jmp (state.fn_ptr)

// AA56
state__scroll_title:
    ldx #$01 // process two sprites groups ("avatar" comprises 3 sprites and "freefall" comprises 2)
!loop:
    lda sprite.curr_y_pos+3,X
    cmp sprite.final_y_pos,x
    beq !next+ // stop moving if at final position
    bcs scroll_up
    //-- scroll down
    adc #$02
    // Only updates the first sprite current position in the group. Not sure why as scroll up updates the position of
    // all sprites in the group.
    sta sprite.curr_y_pos+3,x 
    ldy #$04
!move_loop:
    sta SP0Y+8, y // move sprite 4 and 5
    dey
    dey
    bpl !move_loop-
    bmi !next+
    //-- scroll up
scroll_up:
    sbc #$02
    ldy #$03
!update_pos:
    sta sprite.curr_y_pos,y
    dey
    bpl !update_pos-
    ldy #$06
!move_loop:
    sta SP0Y, y // move sprite 1, 2 and 3
    dey
    dey
    bpl !move_loop-
!next:
    dex
    bpl !loop-
    jmp common.complete_interrupt

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

.namespace state {
    // BCC7
    counter: .byte $00 // state counter (increments after each state change)

    // BD30
    fn_ptr: .word $0000 // pointer to code that will run in the current state
}

// interrupt handler pointers
.namespace sprite {
    // BD15
    final_y_pos: .byte $00, $00 // the set final position of sprites after completion of aimation

    // BD3E
    // TODO: I think this should be in common (why 8 bytes and not 6 otherwise)
    curr_x_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00 // current sprite x-position

    // BD46
    // TODO: I think this should be in common (why 8 bytes and not 6 otherwise)
    curr_y_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00 // current sprite y-position

    // BF1B
    data_ptr: .byte $00 // sprite data pointer
}

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

.namespace sprite {
    // sprites used by title page
    // sprites are contained in the following order:
    // - 0-3: archon logo
    // - 4-6: free fall logo
    // - 7-10: left facing knight animation frames
    // - 11-14: left facing troll animation frames
    // - 15-18: right facing golum animation frames
    // - 19-22: right facing goblin animation frames
    source: .import binary "/assets/sprites-intro.bin"

    // Represents the sprite locations within grapphics memory that each sprite will occupy. See comment on
    // `title_sprites` for a list of which sprite occupies which slot. The first word represents the first sprite,
    // second word the second sprite and so on. The sprite location is calculated by adding the offset to the GRPMEM
    // location. The location list is ffff terminated. Use fffe to skip a sprite without copying it.
    offset:
        .word $0000, $0040, $0080, $00C0, $0100, $0140, $0180, $0600
        .word $0640, $0680, $06C0, $0700, $0740, $0780, $07C0, $0800
        .word $0840, $0880, $08C0, $0900, $0940, $0980, $09C0, $ffff

    // A97A
    y_pos: .byte $ff, $ff, $ff, $ff, $30, $30, $30 // initial sprite y-position

    // A981
    x_pos: .byte $84, $9c, $b4, $cc, $6c, $9c, $cc // initial sprite x-position

    // A988
    color: .byte YELLOW, YELLOW, YELLOW, YELLOW, WHITE, WHITE, WHITE // initial color of each sprite
}
