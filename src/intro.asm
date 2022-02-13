.filenamespace intro

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for displaying and animating the introduction/title sequence.
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
    and #%1110_1111 // Multicolor bitmap mode off
    sta SCROLX
    lda #%0001_0000 // $0000-$07FF char memory, $0400-$07FF screen memory
    sta VMCSB
    // Configure sprites.
    lda #%0000_1111 // First 4 sprites multicolor; last 4 sprints single color
    sta SPMC
    lda #%1111_0000 // First 4 sprites double width; last 4 sprites single width
    sta XXPAND
    lda #%1111_1111 // Enable all sprites
    sta SPENA
    // Set interrupt handler to set intro loop state.
    sei
    lda #<interrupt_handler
    sta main.ptr__raster_interrupt_fn
    lda #>interrupt_handler
    sta main.ptr__raster_interrupt_fn+1
    cli
    lda #$00
    sta idx__substate_fn_ptr // Initialize substate to first substate (draw Freefall logo)
    sta EXTCOL // Black border
    sta BGCOL0 // Black background
    // Set multicolor sprite second color.
    lda data__logo_sprite_color_list
    sta SPMC0
    sta SPMC1
    // Configure the starting intro state function.
    lda #<state__scroll_title
    sta ptr__substate_fn
    lda #>state__scroll_title
    sta ptr__substate_fn+1
    // Busy wait for break key. Interrupts will play the music and animations while we wait.
    jsr common.wait_for_key
    rts

// A98F
// Imports sprites in to graphics area.
import_sprites:
    // Copy in icon frames for chase scene
    lda #FLAG_ENABLE
    sta board.sprite.flag__copy_animation_group
    lda #BYTERS_PER_STORED_SPRITE
    sta board.sprite.copy_length
    lda common.sprite.mem_ptr_24
    sta FREEZP+2
    sta ptr__sprite_mem_lo
    lda common.sprite.mem_ptr_24+1
    sta FREEZP+3
    ldx #$03 // Copy 4 frames (0 offset)
import_sprite_icon_set:
    ldy data__icon_id_list,x
    sty board.icon.type
    lda board.icon.init_matrix,y
    sta board.icon.offset,x
    jsr board.sprite_initialize
    lda flag__is_icon_sprite_mirrored_list,x // Invert frames for icons pointing left
    sta board.data__icon_set_sprite_frame
    lda #$04 // Copy 4 frames for each icon
    sta common.sprite.init_animation_frame
import_sprite_frame:
    jsr board.add_sprite_to_graphics
    lda ptr__sprite_mem_lo
    clc
    adc #BYTES_PER_SPRITE
    sta FREEZP+2
    sta ptr__sprite_mem_lo
    bcc !next+
    inc FREEZP+3
!next:
    inc board.data__icon_set_sprite_frame
    dec common.sprite.init_animation_frame
    bne import_sprite_frame
    dex
    bpl import_sprite_icon_set
    // Add Archon and Avatar logo sprites
    lda common.sprite.mem_ptr_00
    sta FREEZP+2
    lda common.sprite.mem_ptr_00+1
    sta FREEZP+3
    lda ptr__logo_sprite_resource
    sta FREEZP
    lda ptr__logo_sprite_resource+1
    sta FREEZP+1
    ldy #$00 // Copy 7 sprites (448 bytes)
!loop: // Copy first 256 bytes
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+1
    inc FREEZP+3
!loop: // Copy remaining 206 bytes
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    cpy #$C0
    bcc !loop-
    // Pointer to first sprite: 64 bytes per sprite, start at graphmem offset. we add 6 as we are setting the first
    // 6 (of 8) sprites (and we work backwards from 6).
    .const NUM_SPRITES = 6
    lda #(VICGOFF/BYTES_PER_SPRITE)+NUM_SPRITES
    sta ptr__sprite_mem
    ldx #NUM_SPRITES
!loop:
    txa
    asl
    tay
    lda ptr__sprite_mem
    sta SPTMEM,x
    dec ptr__sprite_mem
    lda data__logo_sprite_color_list,x
    sta SP0COL,x
    lda pos__logo_sprite_x_list,x
    sta SP0X,y
    sta common.sprite.curr_x_pos,x
    lda pos__logo_sprite_y_list,x
    sta SP0Y,y
    sta common.sprite.curr_y_pos,x
    dex
    bpl !loop-
    // Final y-pos of Archon title sprites afters animate from bottom of screen.
    lda #$45
    sta common.sprite.final_y_pos
    // Final y-pos of Freefall logo sprites afters animate from top of screen.
    lda #$DA
    sta common.sprite.final_y_pos+1
    rts

// AA42
interrupt_handler:
    lda common.flag__enable_next_state
    bpl !next+
    jmp common.complete_interrupt
!next:
    lda flag__exit_intro
    sta common.flag__enable_next_state
    jsr common.play_music
    jmp (ptr__substate_fn)

// AA56
state__scroll_title:
    ldx #$01 // process two sprites groups ("avatar" comprises 3 sprites and "freefall" comprises 2)
!loop:
    lda common.sprite.curr_y_pos+3,X
    cmp common.sprite.final_y_pos,x
    beq !next+ // stop moving if at final position
    bcs scroll_up
    //-- scroll down
    adc #$02
    // Only updates the first sprite current position in the group. Not sure why as scroll up updates the position of
    // all sprites in the group.
    sta common.sprite.curr_y_pos+3,x
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
    sta common.sprite.curr_y_pos,y
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
    lda #FLAG_ENABLE
    sta flag__string_pos_ctl
    // Enable sprites 4 to 7 (Freefall logo).
    // The sprites are replaced with text character dot data after the animation has completed.
    ldx #$04
    lda #%0000_1111
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
    sty idx__string
!loop:
    stx data__curr_line
    jsr screen_draw_text
    ldx data__curr_line
    dex
    dec idx__string
    ldy idx__string
    cpy #$04
    bcs !loop-
    // Finished drawing 4 lines of top row of free fall log, so now we draw the rest of the lines. This time we will
    // read the screen rows from the remaining string messages.
    lda #FLAG_DISABLE
    sta flag__string_pos_ctl
    jsr screen_draw_text
    //
    dec idx__string // Set to pointer next string to display in next state
    // Start scrolling Avatar logo colors
    lda #<state__avatar_color_scroll
    sta ptr__substate_fn
    lda #>state__avatar_color_scroll
    sta ptr__substate_fn+1
    jmp common.complete_interrupt

// AACF
// Description:
// - Initiates the draw text routine by selecting a color and text offset.
// - The routine then calls a method to write the text to the screen.
// Prerequisites:
// - `idx__string`: Contains the string ID offset
// Notes:
// - The message offset is used to read the string memory location from `prt__string_list` (message offset is
//   multiplied by 2 as 2 bytes are required to store the message location).
// - The message offset is used to read the string color from `data__string_color_list`.
screen_draw_text:
    ldy idx__string
    lda data__string_color_list,y
    sta data__curr_color
    tya
    asl
    tay
    lda prt__string_list,y
    sta FREEZP
    lda prt__string_list+1,y
    sta FREEZP+1
    ldy #$00
    jmp screen_calc_start_addr

// AAEA
// Description:
// - Write characters and colors to the screen.
// Prerequisites:
// - FREEZP/FREEZP+1: Pointer to string data. The string data starts with a column offset and ends with $FF.
// - FREEZP+2/FREEZP+3: Pointer to screen character memory.
// - FORPNT/FORPNT+1: Pointer to screen color memory.
// - `data__curr_color`: Color code used to set the character color.
// Sets:
// - Updates screen character and color memory.
// Notes:
// - Calls `screen_calc_start_addr` to determine screen character and color memory on new line command.
// - Strings are defined as follows:
//  - A $80 byte in the string represents a 'next line'.
//  - A screen row and colum offset must follow a $80 command.
//  - The string is terminated with a $ff byte.
//  - Spaces are represented as $00.
screen_write_chars:
    ldy #$00
get_next_char:
    lda (FREEZP),y
    inc FREEZP
    bne !next+
    inc FREEZP+1
!next:
    cmp #STRING_CMD_NEWLINE
    bcc !next+
    beq screen_calc_start_addr
    rts
!next:
    sta (FREEZP+2),y // Write character
    // Set color.
    lda (FORPNT),y
    and #$F0
    ora data__curr_color
    sta (FORPNT),y
    // Next character.
    inc FORPNT
    inc FREEZP+2
    bne get_next_char
    inc FREEZP+3
    inc FORPNT+1
    jmp get_next_char

// AB13
// Description:
// - Derive the screen starting character offset and color memory offset.
// Prerequisites:
// - FREEZP/FREEZP+1 - Pointer to string data. The string data starts with a column offset and ends with FF.
// - `flag__string_pos_ctl`: Row control flag:
//    $00 - the screen row and column is read from the first byte and second byte in the string
//    $80 - the screen row is supplied using the X register and column is the first byte in the string
//    $C0 - the screen column is hard coded to #06 and the screen row is read X register
// Sets:
// - FREEZP+2/FREEZP+3 - Pointer to screen character memory.
// - FORPNT/FORPNT+1 - Pointer to screen color memory.
// Notes:
// - Calls `screen_write_chars` to output the characters after the screen location is determined.
screen_calc_start_addr:
    lda flag__string_pos_ctl
    bmi skip_sceen_row // flag = $80 or $c0
    // Read screen row.
    lda (FREEZP),y
    inc FREEZP
    bne !next+
    inc FREEZP+1
!next:
    tax // Get screen row from x regsietr
skip_sceen_row:
    // Determine start screen and color memory addresses.
    lda #>SCNMEM // Screen memory hi byte
    sta FREEZP+3 // Screen memory pointer
    clc
    adc common.screen.color_mem_offset // Derive color memory address
    sta FORPNT+1  // color memory pointer
    bit flag__string_pos_ctl
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
    adc #CHARS_PER_SCREEN_ROW
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
    dec idx__string
    bpl !next-
    // Show press run/stop message.
    lda #$C0 // Manual row/column
    sta flag__string_pos_ctl
    lda #$09
    sta idx__string
    ldx #$18
    jsr screen_draw_text
    // Bounce the Avatar logo.
    lda #<state__avatar_bounce
    sta ptr__substate_fn
    lda #>state__avatar_bounce
    sta ptr__substate_fn+1
    // Initialize sprite registers used to bounce the logo in the next state.
    lda #$0E
    sta common.sprite.x_move_counter
    sta common.sprite.y_move_counter
    lda #$FF
    sta flag__sprite_x_direction
    jmp common.complete_interrupt

// AB83
// Bounce the Avatar logo in a sawtooth pattern within a defined rectangle on the screen.
state__avatar_bounce:
    lda #$01 // +1 (down)
    ldy flag__sprite_y_direction
    bpl !next+
    lda #$FF // -1 (up)
!next:
    sta pos__sprite_y
    //
    lda #$01 // +1 (right)
    ldy flag__sprite_x_direction
    bpl !next+
    lda #$FF // -1 (left)
!next:
    sta pos__sprite_x
    // Move all 3 sprites that make up the Avatar logo.
    ldx #$03
    ldy #$06
!loop:
    lda common.sprite.curr_y_pos,x
    // Add the direction pointer to the current sprite positions.
    // The direction pointer is 01 for right and FF (which is same as -1 as number overflows and wraps around) for left direction.
    clc
    adc pos__sprite_y
    sta common.sprite.curr_y_pos,x
    sta SP0Y,y
    lda common.sprite.curr_x_pos,x
    clc
    adc pos__sprite_x
    sta common.sprite.curr_x_pos,x
    sta SP0X,y
    dey
    dey
    dex
    bpl !loop-
    // Reset the x and y position and reverse direction.
    dec common.sprite.y_move_counter
    bne !next+
    lda #$07
    sta common.sprite.y_move_counter
    lda flag__sprite_y_direction
    eor #$FF
    sta flag__sprite_y_direction
!next:
    dec common.sprite.x_move_counter
    bne state__avatar_color_scroll
    lda #$1C
    sta common.sprite.x_move_counter
    lda flag__sprite_x_direction
    eor #$FF
    sta flag__sprite_x_direction

// ABE2
// Scroll the colors on the Avatar logo.
// Here we increase the colours ever 8 counts. The Avatar logo is a multi-colour sprite with the sprite split in to
// even rows of alternating colors (col1, col2, col1, col2 etc). Here we set the first color (anded so it is between
// 1 and 16) and then we set the second color to first color + 1 (also anded so is between one and 16).
state__avatar_color_scroll:
    inc common.sprite.animation_delay
    lda common.sprite.animation_delay
    and #$07
    bne !return+
    inc common.sprite.curr_animation_frame
    lda common.sprite.curr_animation_frame
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
    lda flag__are_sprites_initialized
    bpl chase_set_sprites // Initialise sprites on first run only
    jmp animate_icons
chase_set_sprites:
    lda #BLACK
    sta SPMC0 // Set sprite multicolor (icon border) to black
    lda #FLAG_ENABLE
    sta flag__are_sprites_initialized // Set sprites intiialised flag
    // Confifure sprite colors and positions
    ldx #$03
!loop:
    lda common.sprite.curr_x_pos,x
    lsr
    sta common.sprite.curr_x_pos,x
    lda data__icon_sprite_color_list,x
    sta SP0COL,x
    dex
    bpl !loop-
    jmp animate_icons

// ADC2
// Animate icons by moving them across the screen and displaying animation frames.
animate_icons:
    ldx #$03
    // Animate on every other frame.
    // The code below just toggles a flag back and forth between the minus state.
    lda common.sprite.animation_delay
    eor #$FF
    sta common.sprite.animation_delay
    bmi !return+
    inc common.sprite.curr_animation_frame // Counter is used to set the animation frame
    //Move icon sprites.
!loop:
    txa
    asl
    tay
    lda common.sprite.curr_x_pos,x
    cmp pos__icon_sprite_final_x_list,x
    beq !next+
    clc
    adc flag__icon_sprite_direction_list,x
    sta common.sprite.curr_x_pos,x
    asl // Move by two pixels at a time
    sta SP0X,y
    // C64 requires 9 bits for sprite X position. Therefore sprite is set using sprite X position AND we may need to
    // set the nineth bit in MSIGX (offset bit by spreit enumber).
    bcc clear_sprite_x_pos_msb
    lda MSIGX
    ora common.math.pow2,x
    sta MSIGX
    jmp set_icon_frame
clear_sprite_x_pos_msb:
    lda common.math.pow2,x
    eor #$FF
    and MSIGX
    sta MSIGX
    // Set the sprite pointer to point to one of four sprites used for each icon. A different frame is shown on
    // each movement.
set_icon_frame:
    lda common.sprite.curr_animation_frame
    and #$03 // 1-4 animation frames
    clc
    adc ptr__icon_sprite_mem_list,x
    sta SPTMEM,x
!next:
    dex
    bpl !loop-
!return:
    jmp common.complete_interrupt

// AC0E
// Complete the current game state and move on.
state__end_intro:
    lda #FLAG_ENABLE
    sta common.flag__enable_next_state
    jmp common.complete_interrupt
    rts

//---------------------------------------------------------------------------------------------------------------------
// Assets and constants
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// A97A
// Initial sprite y-position for intro logo sprites.
pos__logo_sprite_y_list: .byte $ff, $ff, $ff, $ff, $30, $30, $30

// A981
// Initial sprite x-position for intro logo sprites.
pos__logo_sprite_x_list: .byte $84, $9c, $b4, $cc, $6c, $9c, $cc

// A988
// Initial color of intro logo sprites.
data__logo_sprite_color_list: .byte YELLOW, YELLOW, YELLOW, YELLOW, WHITE, WHITE, WHITE

// AD73
// Pointers to intro state animation functions that are executed (one after the other) on an $FD command while playing
// music.
ptr__substate_fn_list:
    .word state__draw_freefall_logo, state__show_authors, state__avatar_bounce, state__chase_scene
    .word state__end_intro

// ADAA:
// Icon IDs of pieces used in chase scene.
data__icon_id_list: .byte GOBLIN, GOLEM, TROLL, KNIGHT

// ADAE:
// Direction flags of intro sprites ($80=invert direction).
flag__is_icon_sprite_mirrored_list: .byte FLAG_DISABLE, FLAG_DISABLE, FLAG_ENABLE, FLAG_ENABLE

// ADB2
// Direction of each icon sprite (FF=left, 01=right).
flag__icon_sprite_direction_list: .byte $FF, $FF, $01, $01

// ADB6
// End position of each intro icon sprite.
pos__icon_sprite_final_x_list: .byte $00, $00, $AC, $AC

// ADBA
// Screen pointer sprite offsets for each icon.
ptr__icon_sprite_mem_list:
    .byte (VICGOFF/BYTES_PER_SPRITE)+24
    .byte (VICGOFF/BYTES_PER_SPRITE)+28
    .byte (VICGOFF/BYTES_PER_SPRITE)+32
    .byte (VICGOFF/BYTES_PER_SPRITE)+36

// ADBE
// Initial color of chase scene icon sprites.
data__icon_sprite_color_list: .byte YELLOW, LIGHT_BLUE, YELLOW, LIGHT_BLUE

// 8B27
// Pointer to intro logo sprites.
ptr__logo_sprite_resource: .word resources.sprites_logo

// A8A5
// Pointer to string data for each string.
prt__string_list: 
    .word string_0, string_1, string_2, string_3, string_4, string_4, string_4, string_4
    .word string_5, string_6

// A8B9
// Color of each string.
data__string_color_list:
    .byte YELLOW, LIGHT_BLUE, LIGHT_BLUE, WHITE, DARK_GRAY, GRAY, LIGHT_GRAY, WHITE, WHITE, ORANGE

// A87F
// Top half of "Free Fall" logo.
string_4:
    .byte $0b
    .byte $64, $65, $68, $69, $6c, $6d, $6c, $6d, $00, $64, $65, $60, $61, $70, $71, $70, $71
    .byte STRING_CMD_END

// A892
// Bottom half of "Free Fall" logo.
string_5: 
    .byte $0b
    .byte $66, $67, $6a, $6b, $6e, $6f, $6e, $6f, $00, $66, $67, $62, $63, $72, $73, $72, $73
    .byte STRING_CMD_END

// A8C3
// A .... Game
string_3:
    .byte $10, $13
    .text "A"
    .byte STRING_CMD_NEWLINE, $18, $11
    .text "GAME"
    .byte STRING_CMD_END

// A8CE
// By Anne Wesfall and Jon Freeman & Paul Reiche III
string_0:
    .byte $08, $0c
    .text @"BY\$00ANNE\$00WESTFALL"
    .byte STRING_CMD_NEWLINE, $0a, $0b
    .text @"AND\$00JON\$00FREEMAN"
    .byte STRING_CMD_NEWLINE, $0c, $0d
    .text @"\$40\$00PAUL\$00REICHE\$00III"
    .byte STRING_CMD_END

// A907
// Emptry string under authors - presumably here to allow text to be added for test versions etc
string_1:
    .byte $0f, $01
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00
    .byte STRING_CMD_END

// A931
// Electronic Arts Logo
string_2:
    .byte $12, $01
    .byte $16, $17, $17, $18, $19, $1a, $1b, $1c
    .byte STRING_CMD_NEWLINE, $13, $01
    .byte $1e, $1f, $1f, $20, $1f, $1f, $21, $22, $23
    .byte STRING_CMD_NEWLINE, $14, $01
    .byte $24, $25, $25, $26, $27, $28, $29, $2a, $3f, $1d
    .byte STRING_CMD_NEWLINE, $15, $01
    .byte $2b, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2d, $2e
    .byte STRING_CMD_NEWLINE, $16, $01
    .byte $2f, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e
    .byte STRING_CMD_END

// A805
// replicated from board - copied here for completeness.
string_6:
    .text @"PRESS\$00RUN\$00KEY\$00TO\$00CONTINUE"
    .byte STRING_CMD_END        

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Data

// BCC7
// Index for current introduction sub-state function pointer.
idx__substate_fn_ptr: .byte $00

// BCD1
// Set to $80 to play intro and $00 to skip intro.
flag__enable: .byte $00

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

// BCD3
// Is set to non zero to stop the current intro and advance the game state to the options screen.
flag__exit_intro: .byte $00

// BD0D
// Is positive number for right direction, negative for left direction.
flag__sprite_x_direction: .byte $00

// BD30
// Pointer to code for the current intro substate (eg bounce logo, chase icons, display text etc).
ptr__substate_fn: .word $0000

// BD3A
// Offset of current intro message being rendered.
idx__string: .byte $00

// BD59
// Is positive number for down direction, negative for up direction.
flag__sprite_y_direction: .byte $00 

// BF1A
// Color of the current intro string being rendered.
data__curr_color: .byte $00

// BF1B
// Current sprite location pointer.
ptr__sprite_mem: .byte $00

// BF22
// Is TRUE if intro icon sprites are initialized.
flag__are_sprites_initialized: .byte $00

// BF23
// Current sprite Y position of bouncing Archon sprite.
pos__sprite_y: .byte $00

// BF23
// Low byte of current sprite memory location pointer. Used to increment to next sprite pointer location (by adding 64
// bytes) when adding chasing icon sprites.
ptr__sprite_mem_lo: .byte $00

// BF24
// Current sprite X position of bouncing Archon sprite.
pos__sprite_x: .byte $00

// BF30
// Current screen line used while rendering repeated strings.
data__curr_line: .byte $00

// BF3C
// Used to control string rendering ($00 = read row/column fro first bytes of string, $80 = row supplied in x, $C0 =
// column is #06 and row supplied in x).
flag__string_pos_ctl: .byte $00
