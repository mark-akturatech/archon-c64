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
    sta main.temp.ptr__sprite
    ldx #NUM_SPRITES
!loop:
    txa
    asl
    tay
    lda main.temp.ptr__sprite
    sta SPTMEM,x
    dec main.temp.ptr__sprite
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
    sta main.temp.flag__adv_str // Flag is used for 00-read string row from string data; 80-provide manual row in X

    // Remove sprites 4 to 7 (Freefall logo).
    // The sprites are replaces with text characters after the animation has completed.
    ldx  #$04
    lda  #$0F
!loop:
    sta SPTMEM,x                     
    inx                              
    cpx #$08
    bcc !loop-

    // Draw text method has two modes (set using flag $bfc3):
    // - if set, X register holds the starting row
    // - if not set, the starting row is read from the first byte of the string data
    // Here we set the start row manually and decrement it 4 times. We do this so we can show the same string (the top
    // half of the Free Fall log) on four separate lines.
    ldx #$16
    ldy #$08                         
    sty main.temp.data__msg_offset
!loop:
    stx main.temp.data__curr_line
    jsr screen_draw_text
    ldx main.temp.data__curr_line
    dex                               
    dec main.temp.data__msg_offset
    ldy main.temp.data__msg_offset
    cpy #$04
    bcs !loop-
    // Finished drawing 4 lines of top row of free fall log, so now we draw the rest of the lines. This time we will
    // read the screen rows from the remaining string messages.
    lda #$00
    sta main.temp.flag__adv_str
    jsr screen_draw_text
    //
    dec main.temp.data__msg_offset // Set to pointer next string to display in next state

    // Start scrolling Avatar logo colors
    lda #<state__avatar_color_scroll                      
    sta main.state.current_fn_ptr    
    lda #>state__avatar_color_scroll                      
    sta main.state.current_fn_ptr+1  
    jmp common.complete_interrupt  

// AACF
// Initiates the draw text routine by selecting a color and text offset.
// The routine then calls a method to write the text to the screen.
screen_draw_text:
    ldy main.temp.data__msg_offset
    lda screen.string_color_data,y    
    sta main.temp.data__curr_color
    tya                               
    asl                               
    tay                               
    lda screen.string_data_ptr,y 
    sta FREEZP                    
    lda screen.string_data_ptr+1,y 
    sta FREEZP+1                  
    ldy #$00
    jmp screen_calc_start_addr

// AAEA
// Write characters and colors to the screen.
screen_write_chars:
    ldy #$00                         
get_next_char:
    lda (FREEZP),y                
    inc FREEZP                    
    bne !next+
    inc FREEZP+1
!next:
    cmp #$80 // New line                        
    bcc !next+                        
    beq screen_calc_start_addr 
    rts
!next:  
    sta (FREEZP+2),y // Write character
    // Set color.
    lda (FORPNT),y               
    and #$F0                     
    ora main.temp.data__curr_color        
    sta (FORPNT),y
    // Next character.
    inc FORPNT
    inc FREEZP+2                  
    bne get_next_char                        
    inc FREEZP+3                  
    inc FORPNT+1                 
    jmp get_next_char   

// AB13
// Derivethe screen starting character offset and color memory offset.
// Requires the following prerequisites:
// - FB/FC - Pointer to string data. The string data starts with a column offset and ends with FF.
// - BF3C: Row control flag: 
//    $00 - the screen row and column is read from the first byte and second byte in the string
//    $80 - the screen row is supplied using the X register and column is the first byte in the string
//    $C0 - the screen column is hard coded to #06 and the screen row is read X register
// A $80 byte in the string represents a 'next line'. A screen row and colum offset must follw a $80 command.
// The string is terminated with a $ff byte.
// Spaces are represented as $00.
screen_calc_start_addr:
    lda main.temp.flag__adv_str           
    bmi skip_sceen_row // flag = $80 or $c0
    // Read screen row.
    lda (FREEZP),y                
    inc FREEZP                    
    bne !next+
    inc FREEZP+1                  
!next:
    tax  // Get screen row from x regsietr
skip_sceen_row:
    // Determine start screen and color memory addresses.
    lda #>SCNMEM  // Screen memory hi byte
    sta FREEZP+3 // Screen memory pointer
    clc
    adc main.screen.color_mem_offset // Derive color memory address
    sta FORPNT+1  // color memory pointer
    bit main.temp.flag__adv_str           
    bvc !next+ // flag = $c0
    lda #$06 // Hard coded screen column offset if BF3C flag set
    bne skip_sceen_column
!next:
    lda (FREEZP),y                
    inc FREEZP                    
    bne skip_sceen_column
    inc FREEZP+1                  
skip_sceen_column:
    clc                               
    adc #$28  // 40 columns per row                       
    bcc !next+
    inc FREEZP+3                  
    inc FORPNT+1                          
!next:
    dex                               
    bne skip_sceen_column                        
    sta FREEZP+2                  
    sta FORPNT                  
    jmp screen_write_chars   

// AB4F
state__show_authors:
    jsr common.clear_screen
    // Display author names.
!next:    
    jsr screen_draw_text 
    dec main.temp.data__msg_offset
    bpl !next-
    // Show press run/stop message.
    lda #$C0 // Manual row/column
    sta main.temp.flag__adv_str
    lda #$09
    sta main.temp.data__msg_offset        
    ldx #$18
    jsr screen_draw_text       
    // Bounce the Avatar logo.
    lda #<state__avatar_bounce                      
    sta main.state.current_fn_ptr    
    lda #>state__avatar_bounce                      
    sta main.state.current_fn_ptr+1  
    // Initialize sprite registers used to bounce the logo in the next state.
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
    inc sprite.avatar_logo_color_delay 
    lda sprite.avatar_logo_color_delay 
    and #$07
    bne !return+                        
    inc sprite.avatar_logo_color 
    lda sprite.avatar_logo_color 
    and #$0F                     
    sta SPMC0                     
    clc                             
    adc #$01                         
    and #$0F                         
    sta SPMC1 // C64 uses a global multi-color registers that are used for all sprites
    adc #$01                         
    and #$0F                
    // The avatar logo comprises 3 sprites, so set all to the same color.
    ldy #$03                         
!loop:
    sta SP0COL,y                  
    dey                               
    bpl !loop-
!return:
    jmp common.complete_interrupt

// AD83
state__chase_scene:
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

.namespace state {
    // AD73
    fn_ptr: // Pointers to intro state animation functions that are executed (one after the other) on an $fd
        .word state__draw_freefall_logo, state__show_authors, state__avatar_bounce, state__chase_scene, state__end_intro
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

.namespace screen {
    // A8A5
    string_data_ptr: // Pointer to string data for each string
        .word string_5, string_6, string_7, string_4, string_2, string_2, string_2, string_2, string_3, string_1

    // A8B9
    string_color_data: .byte $07, $0e, $0e, $01, $0b, $0c, $0f, $01, $01, $08 // Color of each string

    // A805
    string_1: // Press run key to continue
        .text @"PRESS\$00RUN\$00KEY\$00TO\$00CONTINUE"
        .byte $ff

    // A87F
    string_2: // Top half of "free Fall" logo
        .byte $0b
        .byte $64, $65, $68, $69, $6c, $6d, $6c, $6d, $00, $64, $65, $60, $61, $70, $71, $70
        .byte $71
        .byte $ff // todo

    // A892
    string_3: // Bottom half of "free Fall" logo
        .byte $0b
        .byte $66, $67, $6a, $6b, $6e, $6f, $6e, $6f, $00, $66, $67, $62, $63, $72, $73, $72
        .byte $73
        .byte $ff

    // A8C3
    string_4: // A .... Game
        .byte $10, $13
        .text "A"
        .byte $80
        .byte $18, $11
        .text "GAME"
        .byte $ff
        
    // A8CE
    string_5: // By Anne Wesfall and Jon Freeman & Paul Reiche III
        .byte $08, $0c
        .text @"BY\$00ANNE\$00WESTFALL"
        .byte $80
        .byte $0a, $0b
        .text @"AND\$00JON\$00FREEMAN"
        .byte $80
        .byte $0c, $0d
        .text @"\$40\$00PAUL\$00REICHE\$00III"
        .byte $ff

    // A907
    string_6: // Clear part of screen
        .byte $0f, $01
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00
        .byte $ff
        
    // A931
    string_7: // Electronic Arts Logo
        .byte $12, $01
        .byte $16, $17, $17, $18, $19, $1a, $1b, $1c 
        .byte $80, $13, $01
        .byte $1e, $1f, $1f, $20, $1f, $1f, $21, $22, $23
        .byte $80, $14, $01
        .byte $24, $25, $25, $26, $27, $28, $29, $2a, $3f, $1d
        .byte $80, $15, $01
        .byte $2b, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2d, $2e
        .byte $80, $16, $01
        .byte $2f, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e
        .byte $ff
}
