.filenamespace intro

//---------------------------------------------------------------------------------------------------------------------
// Contains routines for displaying and animating the introduction/title sequence page.
//---------------------------------------------------------------------------------------------------------------------
#import "src/io.asm"
#import "src/const.asm"

.segment Intro

entry: // A82C
    jsr  common.clear_sprites 
    jsr  import_sprites
    rts

// Imports sprites in to graphics area.
// NOTE I am not using the original source code to do this. It is very dependent on location and uses sprites stored
// in a non standard way (I could be wrong here). Instead, i have a direct sprite.bin file and copy the sprites in to
// the correct location using a flexible matrix copy function described in the `unofficial.asm` file.
import_sprites: // A98F
    simplified: {
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

    rts 

//---------------------------------------------------------------------------------------------------------------------
// Assets
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
    // `title_sprites` for a list of which sprite occupies which slot. The first word represents the first sprite, second
    // word the second sprite and so on. The sprite location is calculated by adding the offset to the GRPMEM location.
    // The location list is ffff terminated. Use fffe to skip a sprite without copying it.
    offset:
        .word $0000, $0040, $0080, $00C0, $0100, $0140, $0180, $0600
        .word $0640, $0680, $06C0, $0700, $0740, $0780, $07C0, $0800
        .word $0840, $0880, $08C0, $0900, $0940, $0980, $09C0, $ffff
}




















// #import "io.asm"
// #import "const.asm"

// .filenamespace intro

// //---------------------------------------------------------------------------------------------------------------------
// // Display introduction (title) page
// //---------------------------------------------------------------------------------------------------------------------
// .segment Intro
// entry:
//     jsr clear_screen
//     jsr clear_sprites
//     jsr import_charset
//     jsr import_sprites
//     jsr initialize_music
//     jsr configure
//     rts

// import_charset:
//     lda #<charset
//     sta FREEZP
//     lda #>charset
//     sta FREEZP+1
//     lda #<CHRMEM1
//     sta FREEZP+2
//     lda #>CHRMEM1
//     sta FREEZP+3
//     ldx #$04
//     jmp block_copy

// import_sprites:
//     lda #<sprite.offset
//     sta FREEZP
//     lda #>sprite.offset
//     sta FREEZP+1
//     lda #<sprites
//     sta FREEZP+2
//     lda #>sprites
//     sta FREEZP+3
//     jsr move_sprites

//     // point screen to first 6 sprites in graphics memory and set default positions and colors


// AA09 **
//     lda #(VICGOFF / $40) + 6 // 64 bytes per sprite, start at graphmem offset
//     sta scratch
//     ldx #$06
// !loop:
//     txa
//     asl
//     tay
//     lda scratch
//     sta SPTMEM,x
//     dec scratch
//     lda sprite.color,x
//     sta SP0COL,x
//     lda sprite.x_pos,x
//     sta SP0X,y
//     sta sprite_x_pos,x
//     lda sprite.y_pos,x
//     sta SP0Y,y
//     sta sprite_y_pos,x
//     dex
//     bpl !loop-
//     lda #$45
//     sta sprite.final_y_pos
//     lda #$DA
//     sta sprite.final_y_pos+1
//     rts

// initialize_music:
//     // full volumne
//     lda #%0000_1111
//     sta SIGVOL

//     // configure voices
//     lda #$07
//     sta $D405
//     sta $D40C
//     sta $D413
//     lda #$3e
//     sta $D406
//     lda #$82
//     sta $D40D
//     lda #$07
//     sta $D414

//     // set music loop location for each voice
//     lda #<music.loop1.phrase_1
//     sta OLDTXT
//     lda #>music.loop1.phrase_1
//     sta OLDTXT+1
//     lda #<music.loop2.phrase_1
//     sta DATLIN
//     lda #>music.loop2.phrase_1
//     sta DATLIN+1
//     lda #<music.loop3.phrase_1
//     sta DATPTR
//     lda #>music.loop3.phrase_1
//     sta DATPTR+1
//     lda #<music.phrasing.loop_1
//     sta VARTAB
//     lda #>music.phrasing.loop_1
//     sta VARTAB+1
//     lda #<music.phrasing.loop_2
//     sta ARYTAB
//     lda #>music.phrasing.loop_2
//     sta ARYTAB+1
//     lda #<music.phrasing.loop_3
//     sta STREND
//     lda #>music.phrasing.loop_3
//     sta STREND+1
//     rts

// configure:
//     // configure screen
//     lda SCROLX
//     and #%1110_1111     // multicolor bitmap mode off
//     sta SCROLX
//     lda #%0001_0000     // $0000-$07FF char memory, $0400-$07FF screen memory
//     sta VMCSB

//     // configure sprites
//     lda #%0000_1111     // first 4 sprites multicolor; last 4 sprints single color
//     sta SPMC
//     lda #%1111_0000     // first 4 sprites double width; last 4 sprites single width
//     sta XXPAND
//     lda #%1111_1111     // enable all sprites
//     sta SPENA

//     // set interrupt handler to set intro loop state
//     sei
//     lda #<interrupt_handler
//     sta interruptPointer.system
//     lda #>interrupt_handler
//     sta interruptPointer.system+1
//     cli

//     // black border and background
//     lda #BLACK
//     sta EXTCOL
//     sta BGCOL0

//     // set game state to intro
//     sta new_game_state

//     // set multicolor sprite second color
//     lda sprite.color
//     sta SPMC0
//     sta SPMC1

//     // configure the starting intro state function
//     lda #<state__scroll_title
//     sta state.function_ptr
//     lda #>state__scroll_title
//     sta state.function_ptr+1

//     jsr intro_loop
//     rts

// interrupt_handler:
//     lda game_state
//     bpl !next+
//     jmp complete_interrupt
// !next:
//     lda new_game_state
//     sta game_state
//     jsr play_music
//     jmp (state.function_ptr)

// // OK here is where the magic happens. here we read from a command matrix. the command tells us to:
// //   01-F9: ??
// //   00: Play note??
// //   FA: delay??
// //   FB: 
// //   FC:
// //   FD: ???New intro sub state
// //   FE: Move to the next phrase
// //   FF: Finish playing the loop
// // At the conclusion of processing the command, we then read the next command in the sequence.
// play_music:
//     ldx #$02
// !loop:    
//     txa
//     asl
//     tay
//     lda music.note_data_ptr,y
//     sta music.current_note_ptr
//     lda music.note_data_ptr+1,y
//     sta music.current_note_ptr+1
//     lda music.voice_io_addr,y
//     sta FREEZP+2
//     lda music.voice_io_addr+1,y
//     sta FREEZP+3
//     lda music.phrase_data_ptr,y
//     sta music.current_phrase_ptr
//     lda music.phrase_data_ptr+1,y
//     sta music.current_phrase_ptr+1
//     //
//     lda music.delay_count,x
//     beq next_command
//     cmp #$02
//     bne !next+
//     // start note gate release
//     lda music.control,x
//     and #%1111_11110
//     ldy #$04
//     sta (FREEZP+2),y
// !next:
//     dec music.delay_count,x
//     bne skip_command
// next_command:
//     jsr get_next_command
// skip_command:
//     dex
//     bpl !loop-
//     rts

// get_next_command:
//     jsr get_note
//     cmp #$FF // TODO ENUM: stop note
//     bne !next+
//     ldy #$04
//     lda #$00
//     sta (FREEZP+2),y
//     rts
// !next:
//     cmp #$FE // TODO ENUM: next phrase
//     bne !next+
//     jsr get_next_phrase
//     jmp get_next_command
// !next:
//     cmp #$FD // TODO ENUM: next state
//     beq set_state
//     cmp #$FB //set TODO enum: set delay
//     beq set_delay
//     cmp #$00 // TODO enum: immediately turn off current note
//     beq clear_note
//     cmp #$FC // TODO enum: start early gate release
//     beq release_note
//     pha
//     ldy #$04
//     lda music.control,x
//     and #%1111_1110 // start gate release on current note
//     sta (FREEZP+2),y
//     ldy #$01
//     pla
//     sta (FREEZP+2),y
//     jsr get_note
//     ldy #$00
//     sta (FREEZP+2),y
//     jmp set_note
// set_state:
//     // TODO
//     jmp get_next_command
// clear_note:
//     ldy #$04
//     sta (FREEZP+2),y
//     jmp !return+
// set_delay:
//     jsr get_note
//     sta music.delay,x
//     jmp get_next_command
// release_note:
//     ldy #$04
//     lda music.control,x
//     and #%1111_1110 // start gate release on current note
//     sta (FREEZP+2),y
// set_note:
//     ldy #$04
//     lda music.control,x
//     sta (FREEZP+2),y
// !return:
//     lda music.delay,x
//     sta music.delay_count,x
//     rts

// // read note from current music loop and increment the note pointer
// get_note:
//     ldy #$00
//     jmp (music.current_note_ptr)
// get_note_loop_1:
//     lda (OLDTXT),y
//     inc OLDTXT
//     bne !next+
//     inc OLDTXT
// !next:
//     rts
// get_note_loop_2:
//     lda (DATLIN),y
//     inc DATLIN
//     bne !next+
//     inc DATLIN
// !next:
//     rts
// get_note_loop_3:
//     lda (DATPTR),y
//     inc DATPTR
//     bne !next+
//     inc DATPTR
// !next:
//     rts

// // read a phrase for the current music loop and increment the phrase pointer
// get_next_phrase:
//     ldy #$00
//     jmp (music.current_phrase_ptr)
// get_phrase_loop_1:
//     lda (VARTAB),y
//     sta OLDTXT
//     iny
//     lda (VARTAB),y
//     sta OLDTXT+1
//     lda VARTAB
//     clc
//     adc #$02
//     sta VARTAB
//     bcc !return+
//     inc VARTAB+1
// !return:
//     rts
// get_phrase_loop_2:
//     lda (ARYTAB),y
//     sta DATLIN
//     iny
//     lda (ARYTAB),y
//     sta DATLIN+1
//     lda ARYTAB
//     clc
//     adc #$02
//     sta ARYTAB
//     bcc !return+
//     inc ARYTAB+1
// !return:
//     rts
// get_phrase_loop_3:
//     lda (STREND),y
//     sta DATPTR
//     iny
//     lda (STREND),y
//     sta DATPTR+1
//     lda STREND
//     clc
//     adc #$02
//     sta STREND
//     bcc !return+
//     inc STREND+1
// !return:
//     rts

// // continually check for STOP, game options or Q keypress and exit intro if detected.
// // note that we can busy wait here as the intro is run on an interrupt.
// intro_loop:
//     lda #$00
//     sta game_state
// !loop:
//     // i feel like we should have some NOPs here so we don't busy wait at 100%. original code doesn't have any tho.
//     jsr check_option_keypress
//     jsr check_stop_keypess
//     lda game_state
//     beq !loop-
//     //jmp $7fab // TODO
//     rts

// // first intro sub state - Scroll in avatar and freefall titles
// state__scroll_title:
//     ldx #$01 // process two sprites groups ("avatar" comprises 3 sprites and "freefall" comprises 2)
// !loop:
//     lda sprite_y_pos+3,X
//     cmp sprite.final_y_pos,x
//     beq !next+ // stop moving if at final position
//     bcs scroll_up
//     //-- scroll down
//     adc #$02
//     // only updates the first sprite current position in the group. not sure why as scroll up updates the position of
//     // all sprites in the group
//     sta sprite_y_pos+3,x 
//     ldy #$04
// !move_loop:
//     sta SP0Y+8, y // move sprite 4 and 5
//     dey
//     dey
//     bpl !move_loop-
//     bmi !next+
//     //-- scroll up
// scroll_up:
//     sbc #$02
//     ldy #$03
// !update_pos:
//     sta sprite_y_pos,y
//     dey
//     bpl !update_pos-
//     ldy #$06
// !move_loop:
//     sta SP0Y, y // move sprite 1, 2 and 3
//     dey
//     dey
//     bpl !move_loop-
// !next:
//     dex
//     bpl !loop-
//     jmp complete_interrupt

// //---------------------------------------------------------------------------------------------------------------------
// // Variables
// //---------------------------------------------------------------------------------------------------------------------
// .segment Variables

// .namespace state {
//     function_ptr: .word $0000
// }

// .namespace sprite {
//     final_y_pos: .byte $00, $00
// }

// .namespace music {
//     delay: .byte $00, $00, $00
//     delay_count: .byte $00, $00, $00
//     control: .byte $21, $21, $21

//     current_note_ptr: .word $0000
//     current_phrase_ptr: .word $0000
// }

// //---------------------------------------------------------------------------------------------------------------------
// // Assets
// //---------------------------------------------------------------------------------------------------------------------
// .segment Assets

// // char set used by title page
// charset: .import binary "/assets/charset-intro.bin"

// // sprites used by title page
// // sprites are contained in the following order:
// // - 0-3: archon logo
// // - 4-6: free fall logo
// // - 7-10: left facing knight animation frames
// // - 11-14: left facing troll animation frames
// // - 15-18: right facing golum animation frames
// // - 19-22: right facing goblin animation frames
// sprites: .import binary "/assets/sprites-intro.bin"

// .namespace sprite {
//     // Represents the sprite locations within grapphics memory that each sprite will occupy. See comment on
//     // `title_sprites` for a list of which sprite occupies which slot. The first word represents the first sprite, second
//     // word the second sprite and so on. The sprite location is calculated by adding the offset to the GRPMEM location.
//     // The location list is ffff terminated.
//     offset:
//         .word $0000, $0040, $0080, $00C0, $0100, $0140, $0180, $0600
//         .word $0640, $0680, $06C0, $0700, $0740, $0780, $07C0, $0800
//         .word $0840, $0880, $08C0, $0900, $0940, $0980, $09C0, $ffff

//     color: .byte YELLOW, YELLOW, YELLOW, YELLOW, WHITE, WHITE, WHITE
//     x_pos: .byte $84, $9c, $b4, $cc, $6c, $9c, $cc
//     y_pos: .byte $ff, $ff, $ff, $ff, $30, $30, $30
// }

// // archon uses 3 separate loops to allow it to play up to 3 voices at once. loops can also contain commands that
// // skip on the intro at certain points within the music, or end the intro at the end of the music. each loop comprises
// // a number of phrases that can be repeated to form music.
// .namespace music {
//     .namespace loop1 {
//         phrase_1: // 3d52 - 3d74
//             .byte $fb, $07, $11, $c3, $10, $c3, $0f, $d2, $0e, $ef, $11, $c3, $10, $c3, $0f, $d2
//             .byte $0e, $ef, $11, $c3, $10, $c3, $0f, $d2, $0e, $ef, $13, $ef, $15, $1f, $16, $60
//             .byte $17, $b5, $fe
//         phrase_2: // 3da9 - 3dc4
//             .byte $fd, $fb, $70, $19, $1e, $fb, $38, $12, $d1, $fb, $1c, $15, $1f, $fb, $09, $12
//             .byte $d1, $11, $c3, $fb, $0a, $0e, $18, $fb, $e0, $1c, $31, $fe
//         phrase_3: // 3e09 - 3e68
//             .byte $fb, $07, $00, $00, $17, $b5, $fc, $1c, $31, $fc, $1f, $a5, $fc, $23, $86, $fc
//             .byte $1f, $a5, $fc, $1c, $31, $fc, $17, $b5, $fc, $1f, $a5, $fc, $17, $b5, $fc, $1c
//             .byte $31, $fc, $17, $b5, $fc, $11, $c3, $fc, $17, $b5, $fc, $0b, $da, $fc, $11, $c3
//             .byte $fc, $00, $00, $19, $1e, $fc, $1f, $a5, $fc, $23, $86, $fc, $25, $a2, $fc, $23
//             .byte $86, $fc, $1f, $a5, $fc, $19, $1e, $fc, $23, $86, $fc, $19, $1e, $fc, $1f, $a5
//             .byte $fc, $19, $1e, $fc, $12, $d1, $fc, $19, $1e, $fc, $0c, $8f, $fc, $12, $d1, $fc      
//         phrase_4: // 3e69 - 3e8a
//             .byte $00, $00, $10, $c3, $11, $c3, $1c, $31, $1a, $9c, $16, $60, $17, $b5, $1a, $9c
//             .byte $1c, $31, $1f, $a5, $21, $87, $23, $86, $1c, $31, $fb, $0e, $17, $b5, $fb, $07
//             .byte $fd, $fe
//         phrase_5: // 3f42 - 3f46
//             .byte $fb, $70, $19, $1e, $ff
//     }
//     .namespace loop2 {
//         phrase_1: // 3d75 - 3b8a
//             .byte $fb, $38, $00, $fb, $07, $0e, $18, $0d, $4e, $0c, $8f, $0b, $da, $0b, $30, $0a
//             .byte $8f, $09, $f7, $09, $68, $fe
//         phrase_2: // 3dc5 - 3ddf
//             .byte $fb, $70, $19, $3e, $fb, $38, $12, $e9, $fb, $1c, $15, $3a, $fb, $09, $12, $e9
//             .byte $11, $d9, $fb, $0a, $0e, $2a, $fb, $e0, $1c, $55, $fe
//         phrase_3: // 3e8b - 3eea
//             .byte $fb, $07, $00, $00, $17, $d3, $fc, $1c, $55, $fc, $1f, $cd, $fc, $23, $b3, $fc
//             .byte $1f, $cd, $fc, $1c, $55, $fc, $17, $d3, $fc, $1f, $cd, $fc, $17, $d3, $fc, $1c
//             .byte $55, $fc, $17, $d3, $fc, $11, $d9, $fc, $17, $d3, $fc, $0b, $e9, $fc, $11, $d9
//             .byte $fc, $00, $00, $19, $3e, $fc, $1f, $cd, $fc, $23, $b3, $fc, $25, $d2, $fc, $23
//             .byte $b3, $fc, $1f, $cd, $fc, $19, $3e, $fc, $23, $b3, $fc, $19, $3e, $fc, $1f, $cd
//             .byte $fc, $19, $3e, $fc, $12, $e9, $fc, $19, $3e, $fc, $0c, $9f, $fc, $12, $e9, $fc
//         phrase_4: // 3eeb - 3f0b
//             .byte $00, $00, $10, $d8, $11, $d9, $1c, $55, $1a, $be, $16, $7c, $17, $d3, $1a, $be
//             .byte $1c, $55, $1f, $cd, $21, $b1, $23, $86, $1c, $55, $fb, $0e, $17, $d3, $fb, $07
//             .byte $fe
//         phrase_5: // 3f4d - 3f51
//             .byte $fb, $70, $07, $0c, $ff
//     }
//     .namespace loop3 {
//         phrase_1: // 3d8b - 3da8
//             .byte $fb, $1c, $00, $fb, $07, $0e, $18, $0d, $4e, $0c, $8f, $0b, $da, $0b, $30, $0a
//             .byte $8f, $09, $f7, $09, $68, $08, $e1, $08, $61, $07, $e9, $07, $77, $fe
//         phrase_2: // 3de0 - 3de1
//             .byte $fb, $07
//         phrase_3: // 3de2 - 3dee
//             .byte $07, $0c, $fc, $0a, $8f, $fc, $0e, $18, $fc, $0a, $8f, $fc, $fe
//         phrase_4: // 3def - 3dfb
//             .byte $09, $68, $fc, $0e, $18, $fc, $12, $d1, $fc, $0e, $18, $fc, $fe
//         phrase_5: // 3dfc - 3e08
//             .byte $06, $47, $fc, $09, $68, $fc, $0c, $8f, $fc, $09, $68, $fc, $fe 
//         phrase_6: // 3f0c - 3f0d
//             .byte $fb, $07 
//         phrase_7: // 3f0e - 3f1a
//             .byte $05, $ed, $fc, $08, $e1, $fc, $0b, $da, $fc, $08, $e1, $fc, $fe
//         phrase_8: // 3f1b - 3f27
//             .byte $06, $47, $fc, $09, $68, $fc, $0c, $8f, $fc, $09, $68, $fc, $fe
//         phrase_9: // 3f28 - 3f34
//             .byte $05, $ed, $fc, $08, $e1, $fc, $0b, $da, $fc, $08, $e1, $fc, $fe
//         phrase_10: // 3f35 - 3f41
//             .byte $07, $e9, $fc, $0b, $da, $fc, $0f, $d2, $fc, $0b, $da, $fc, $fe
//         phrase_11: // 3f47 - 3f4c
//             .byte $fb, $70, $0a, $8f, $fd, $ff
//     }

//     .namespace phrasing {
//         loop_1: 
//             .word loop1.phrase_2, loop1.phrase_2, loop1.phrase_3, loop1.phrase_4
//             .word loop1.phrase_1, loop1.phrase_5
//         loop_2:
//             .word loop2.phrase_2, loop2.phrase_2, loop2.phrase_3, loop2.phrase_4
//             .word loop2.phrase_1, loop2.phrase_5
//         loop_3:
//             .word loop3.phrase_2, loop3.phrase_3, loop3.phrase_3, loop3.phrase_3
//             .word loop3.phrase_4, loop3.phrase_4, loop3.phrase_5, loop3.phrase_5
//             .word loop3.phrase_2, loop3.phrase_3, loop3.phrase_3, loop3.phrase_3
//             .word loop3.phrase_4, loop3.phrase_4, loop3.phrase_5, loop3.phrase_5
//             .word loop3.phrase_6, loop3.phrase_7, loop3.phrase_7, loop3.phrase_7
//             .word loop3.phrase_8, loop3.phrase_8, loop3.phrase_8, loop3.phrase_8
//             .word loop3.phrase_9, loop3.phrase_9, loop3.phrase_10, loop3.phrase_10
//             .word loop3.phrase_1, loop3.phrase_11
//     }

//     note_data_ptr: .word get_note_loop_1, get_note_loop_2, get_note_loop_3
//     phrase_data_ptr: .word get_phrase_loop_1, get_phrase_loop_2, get_phrase_loop_3
//     voice_io_addr: .word $D400, $D407, $D40E
// }
