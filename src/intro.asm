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
    sta main.interrupt.system_fn_ptr
    lda #>interrupt_handler
    sta main.interrupt.system_fn_ptr+1
    cli

    // Black border and background.
    lda #$00
    sta main.state.counter
    sta EXTCOL
    sta BGCOL0

    // Set multicolor sprite second color.
    lda sprite.color
    sta SPMC0
    sta SPMC1

    // Configure the starting intro state function.
    lda #<state__scroll_title
    sta main.state.current_fn_ptr
    lda #>state__scroll_title
    sta main.state.current_fn_ptr+1

    // Busy wait for break key. Interrupts will play the music and animations while we wait.
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
    sta common.temp_data_ptr
    ldx #NUM_SPRITES
!loop:
    txa
    asl
    tay
    lda common.temp_data_ptr
    sta SPTMEM,x
    dec common.temp_data_ptr
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
    lda main.state.current
    bpl !next+
    jmp common.complete_interrupt
!next:
    lda main.state.new
    sta main.state.current
    jsr common.play_music
    jmp (main.state.current_fn_ptr)

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
    sta SP4Y,y // move sprite 4 and 5
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
    sta SP0Y,y // move sprite 1, 2 and 3
    dey
    dey
    bpl !move_loop-
!next:
    dex
    bpl !loop-
    jmp common.complete_interrupt

// AA8B
state__draw_freefall_logo:
    lda #$80                         
    // sta WBF3C                        TODO

    // Remove sprites 4 to 7 (Freefall logo).
    // The sprites are replaces with text characters after the animation has completed.
    ldx  #$04
    lda  #$0F
!loop:
    sta SPTMEM,x                     
    inx                              
    cpx #$08
    bcc !loop-

//     ldx  #$16                         
//     ldy  #$08                         
// WAAA0:
//     sty  WBD3A                        
// WAAA3:
//     stx  WBF30                        
//     jsr  WAACF                        
// WAAA9:
//     ldx  WBF30                        
//     dex                               
//     dec  WBD3A                        
//     ldy  WBD3A                        
//     cpy  #$04                         
//     bcs  WAAA3                        
//     lda  #$00                         
//     sta  WBF3C                        
//     jsr  WAACF                        
//     dec  WBD3A                        
    // Start scrolling Avatar logo colors
    lda #<state__avatar_color_scroll                      
    sta main.state.current_fn_ptr    
    lda #>state__avatar_color_scroll                      
    sta main.state.current_fn_ptr+1  
    jmp common.complete_interrupt  

// AB4F
state__xxx2:
//...
    // Start bouncing Avatar logo
    lda #<state__avatar_bounce                      
    sta main.state.current_fn_ptr    
    lda #>state__avatar_bounce                      
    sta main.state.current_fn_ptr+1  
    //
    lda #$0E
    sta sprite.x_move_counter 
    sta sprite.y_move_counter 
    lda #$FF                  
    sta sprite.x_direction_flag 
    jmp common.complete_interrupt

// AB83
// Bounce the Avatar logo in a sawtooth pattern within a defined rectangle on the screen.
state__avatar_bounce:
    lda #$01 // +1 (down)
    ldy sprite.y_direction_flag
    bpl !next+                        
    lda #$FF // -1 (up)
!next:
    sta sprite.y_direction_offset  
    //
    lda #$01 // +1 (right)
    ldy sprite.x_direction_flag
    bpl !next+                        
    lda #$FF // -1 (left)
!next:
    sta sprite.x_direction_offset
    // Move all 3 sprites that make up the Avatar logo.
    ldx #$03
    ldy #$06
!loop:
    lda sprite.curr_y_pos,x    
    // Add the direction pointer to the current sprite positions.
    // The direction pointer is 01 for right and FF (which is same as -1 as number overflows and wraps around) for left direction.
    clc                               
    adc sprite.y_direction_offset     
    sta sprite.curr_y_pos,x    
    sta SP0Y,y                    
    lda sprite.curr_x_pos,x    
    clc                               
    adc sprite.x_direction_offset     
    sta sprite.curr_x_pos,x    
    sta SP0X,y                    
    dey                               
    dey                               
    dex                               
    bpl !loop-                        
    // Reset the x and y position and reverse direction.
    dec sprite.y_move_counter
    bne !next+
    lda #$07 
    sta sprite.y_move_counter 
    lda sprite.y_direction_flag
    eor #$FF                         
    sta sprite.y_direction_flag
!next:
    dec sprite.x_move_counter 
    bne state__avatar_color_scroll 
    lda #$1C                         
    sta sprite.x_move_counter 
    lda sprite.x_direction_flag
    eor #$FF                         
    sta sprite.x_direction_flag    

// Scroll the colors on the Avatar logo.
// Here we increase the colours ever 8 counts. The Avatar logo is a multi-colour sprite with the sprite split in to
// even rows of alternating colors (col1, col2, col1, col2 etc). Here we set the first color (anded so it is between
// 1 and 16) and then we set the second color to first color + 1 (also anded so is between one and 16).
// ABE2
state__avatar_color_scroll:
    inc  sprite.avatar_logo_color_delay 
    lda  sprite.avatar_logo_color_delay 
    and  #$07
    bne  !return+                        
    inc  sprite.avatar_logo_color 
    lda  sprite.avatar_logo_color 
    and  #$0F                     
    sta  SPMC0                     
    clc                             
    adc  #$01                         
    and  #$0F                         
    sta  SPMC1 // C64 uses a global multi-color registers that are used for all sprites
    adc  #$01                         
    and  #$0F                
    // The avatar logo comprises 3 sprites, so set all to the same color.
    ldy  #$03                         
!loop:
    sta  SP0COL,y                  
    dey                               
    bpl  !loop-
!return:
    jmp  common.complete_interrupt

// AD83
state__xxx4:
    jmp common.complete_interrupt

// AC0E
// Complete the current game state and move on.
state__end_intro:
    lda #$80
    sta main.state.current
    jmp common.complete_interrupt
    rts

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// interrupt handler pointers
.namespace sprite {
    // BCE7
    avatar_logo_color: .byte $00 // Color of avatar sprite used for color scrolling

    // BCE8
    avatar_logo_color_delay: .byte $00 // Delay between color changes when color scrolling avatar sprites

    // BCE9
    y_move_counter: .byte $00 // Number of moves left in y plane in current direction (will reverse direction on 0)

    // BCEA
    x_move_counter: .byte $00 // Number of moves left in x plane in current direction (will reverse direction on 0)

    // BD15
    final_y_pos: .byte $00, $00 // Final set position of sprites after completion of animation

    // BD3E
    // TODO: I think this should be in common (why 8 bytes and not 6 otherwise)
    curr_x_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00 // Current sprite x-position

    // BD46
    // TODO: I think this should be in common (why 8 bytes and not 6 otherwise)
    curr_y_pos: .byte $00, $00, $00, $00, $00, $00, $00, $00 // Current sprite y-position

    // BD58
    x_direction_flag: .byte $00 // Is positive number for right direction, negative for left direction
    
    // BD59
    y_direction_flag: .byte $00 // Is positive number for down direction, negative for up direction

    // BF23
    y_direction_offset: .byte $00 // Amount added to y plan to move sprite to the left or right (uses rollover)

    // BF24
    x_direction_offset: .byte $00 // Amount added to x plan to move sprite to the left or right (uses rollover)
}

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// AD73
.namespace state {
    fn_ptr: // Pointers to intro state animation functions that are executed (one after the other) on an $fd
        .word state__draw_freefall_logo, state__xxx2, state__avatar_bounce, state__xxx4, state__end_intro
}

.namespace sprite {
    // sprites used by title page
    // sprites are contained in the following order:
    // - 0-3: Archon logo
    // - 4-6: Freefall logo
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
    y_pos: .byte $ff, $ff, $ff, $ff, $30, $30, $30 // Initial sprite y-position

    // A981
    x_pos: .byte $84, $9c, $b4, $cc, $6c, $9c, $cc // Initial sprite x-position

    // A988
    color: .byte YELLOW, YELLOW, YELLOW, YELLOW, WHITE, WHITE, WHITE // Initial color of each sprite
}
