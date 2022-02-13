.filenamespace resources

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
//  - sound phrases; start $3ea3; end: $3fa8
//  - charset - intro: start: $4000; length: $3ff; end: $4400
//  - charset - game: start: $4800; length: $7ff; end: $4fff
//  - sprites - elemetals; start: $5000; length: $ca7; end: $5ca7
//  - music phrases; start $5ca8; end: $5f0d
.segment Resources

// BACB
// Sprites used by title page.
// Sprites are contained in the following order:
// - 0-3: Archon logo (in 3 parts)
// - 4-6: Freefall logo (in 2 parts)
#if INCLUDE_INTRO
    sprites_logo: .import binary "/assets/sprites-logos.bin"
#endif

// BACB
// Sprites used by icons as projectiles within the battle arena.
// The projectiles are only small and consume 32 bytes each. There is not a projectile sprite per icon as may
// icons reuse the same projectile.
sprites_projectile: .import binary "/assets/sprites-projectiles.bin"

// BAE-3D3F
// Icon sprites. Note that sprites are not 64 bytes in length like normal sprites. Archon sprites are smaller so
// that they can fit on a board sqare and therefore do not need to take up 64 bytes. Instead, sprites consume 54
// bytes only. The positive of this is that we use less memory for each sprite. The negative is that we can't just
// load the raw sprite binary file in to a sprite editor.
// Anyway, there are LOTS of sprites. Generally 15 sprites for each icon. This includes fram animations in each
// direction, attack animations and projectiles. NOTE that spearate frames for left moving and right moving
// animations. Instead, the routine used to load sprites in to graphical memory has a function that allows
// sprites to be mirrored when copied.
sprites_icon: .import binary "/assets/sprites-icons.bin"

// 8B94
// Provides sound phraseology for icon movement and attacks. 
.namespace sound {
    // 8B94
    // Points to a list of sounds that can be made for each icon type. The same sounds may be reused by different icon
    // types.
    icon_pattern_ptr:
        .word pattern_walk_large   // 00
        .word pattern_fly_01       // 02
        .word pattern_fly_02       // 04
        .word pattern_walk_quad    // 06
        .word pattern_fly_03       // 08
        .word pattern_fly_large    // 10
        .word pattern_attack_01      // 12
        .word pattern_attack_02      // 14
        .word pattern_attack_03      // 16
        .word pattern_attack_04      // 18
        .word pattern_walk_slither // 20

    // 8BAA
    attack_pattern:
    // Sound pattern used for attack sound of each icon type. The data is an index to the icon pattern pointer array
    // defined above.
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 12, 12, 12, 12, 12, 12, 16, 14, 12, 12, 12, 12, 12, 12, 18, 14, 12, 12, 12, 12

    // 8BBE
    // Sound pattern used for each icon type. The data is an index to the icon pattern pointer array defined above.
    // Uses icon offset as index.
    icon_pattern:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 06, 08, 08, 00, 02, 02, 10, 08, 20, 08, 06, 00, 02, 04, 02, 08, 02, 02, 00, 04

    // 95f4
    // Provised pointers to the sounds that may be made during normal board movement.
    board_pattern_ptr:
        .word pattern_hit_player_light   // 00
        .word pattern_hit_player_dark    // 02
        .word pattern_player_light_turn  // 04
        .word pattern_player_dark_turn   // 06

    // A15E
    pattern_walk_large:
        .byte SOUND_CMD_NO_NOTE, $08, $34, SOUND_CMD_NO_NOTE, $20, $03, $81, SOUND_CMD_NO_NOTE, $08, $34
        .byte SOUND_CMD_NO_NOTE, $20, $01, $81
        .byte SOUND_CMD_NEXT_PATTERN
    pattern_fly_01:
        .byte SOUND_CMD_NO_NOTE, $04, SOUND_CMD_NO_NOTE, $40, $60, $08, $81, $04, SOUND_CMD_NO_NOTE, $40, $60
        .byte $0A, $81
        .byte SOUND_CMD_NEXT_PATTERN
    pattern_fly_02:
        .byte SOUND_CMD_NO_NOTE, $08, $70, SOUND_CMD_NO_NOTE, $E2, $04, $21, $08, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PATTERN
    pattern_walk_slither:
        .byte SOUND_CMD_NO_NOTE, $08, $70, SOUND_CMD_NO_NOTE, $C0, $07, $21, $08, $70, SOUND_CMD_NO_NOTE, $C0, $07
        .byte SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PATTERN
    pattern_walk_quad:
        .byte $04, $01, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $02, $81, SOUND_CMD_NO_NOTE, $04, $01
        .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $03, $81, SOUND_CMD_NO_NOTE, $04, $01, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NO_NOTE, $04, $81, SOUND_CMD_NO_NOTE, $04, $01, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PATTERN
    pattern_fly_03:
        .byte SOUND_CMD_NO_NOTE, $04, $12, SOUND_CMD_NO_NOTE, $20, $03, $81, $04, $12, SOUND_CMD_NO_NOTE, $20, $03
        .byte SOUND_CMD_NO_NOTE, $04, $12, SOUND_CMD_NO_NOTE, $20, $02, $81, $04, $12, SOUND_CMD_NO_NOTE, $20, $02
        .byte SOUND_CMD_NO_NOTE
        .byte SOUND_CMD_NEXT_PATTERN
    pattern_attack_03:
        .byte SOUND_CMD_NO_NOTE, $32, $A9, SOUND_CMD_NO_NOTE, $EF, $31, $81, SOUND_CMD_END
    pattern_hit_player_dark:
        .byte SOUND_CMD_NO_NOTE, $12, $08, SOUND_CMD_NO_NOTE, $C4, $07, $41, SOUND_CMD_END
    pattern_hit_player_light:
        .byte SOUND_CMD_NO_NOTE, $12, $08, SOUND_CMD_NO_NOTE, $D0, $3B, $43, SOUND_CMD_END
    pattern_attack_04:
        .byte SOUND_CMD_NO_NOTE, $28, $99, SOUND_CMD_NO_NOTE, $6A, $6A, $21, SOUND_CMD_END
    pattern_fly_large:
        .byte SOUND_CMD_NO_NOTE, $10, $84, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $06, $81
        .byte SOUND_CMD_NEXT_PATTERN
    pattern_attack_01:
        .byte SOUND_CMD_NO_NOTE, $80, $4B, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $21, $81, SOUND_CMD_END
    pattern_attack_02:
        .byte SOUND_CMD_NO_NOTE, $10, $86, SOUND_CMD_NO_NOTE, $F0, $F0, $81, SOUND_CMD_END
    pattern_player_light_turn:
        .byte SOUND_CMD_NO_NOTE, $1E, $09, SOUND_CMD_NO_NOTE, $3E, $2A, $11, SOUND_CMD_END
    pattern_player_dark_turn:
        .byte SOUND_CMD_NO_NOTE, $1E, $09, SOUND_CMD_NO_NOTE, $1F, $16, $11, SOUND_CMD_END
    pattern_transport:
        .byte SOUND_CMD_NO_NOTE, $80, $03, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $23, $11, SOUND_CMD_END
}

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
    // Icon sprites for the 4 summonable elementals. The sprites are arranged the same as `sprites_icon`.
    sprites_elemental: .import binary "/assets/sprites-elementals.bin"

    // 3D40
    // Music configuration.
    // Music is played by playing notes pointed to by `init_pattern_list_ptr` on each voice.
    // When the voice pattern list finishes, the music will look at the intro or outro pattern list pointers (
    // `intro_pattern_ptr` or `outro_pattern_ptr`) depending on the track being played. This list will then tell the
    // player which pattern to play next.
    // When the pattern finishes, it looks at the next pattern in the list and continues until a FE command is reached.
    .namespace music {
        #if INCLUDE_INTRO
        intro_pattern_ptr: // Pointers for intro music pattern list for each voice
            .word intro_pattern_V1_ptr, intro_pattern_V2_ptr, intro_pattern_V3_ptr
        #endif
        init_pattern_list_ptr: // Initial patterns for both intro and outro music
            .word pattern_1, pattern_2, pattern_3
        outro_pattern_ptr: // Pointers for outro music pattern list for each voice
            .word outro_pattern_V1_ptr, outro_pattern_V2_ptr, outro_pattern_V3_ptr

        // Music notes and commands.
        pattern_1: // Notes (00 to FA) and commands (FB to FF) for music pattern
            .byte SOUND_CMD_SET_DELAY, $07, $11, $C3, $10, $C3, $0F, $D2, $0E, $EF, $11, $C3, $10, $C3, $0F, $D2
            .byte $0E, $EF, $11, $C3, $10, $C3, $0F, $D2, $0E, $EF, $13, $EF, $15, $1F, $16, $60
            .byte $17, $B5
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_2:
            .byte SOUND_CMD_SET_DELAY, $38, SOUND_CMD_NO_NOTE, SOUND_CMD_SET_DELAY, $07, $0E, $18, $0D, $4E, $0C, $8F
            .byte $0B, $DA, $0B, $30, $0A, $8F, $09, $F7, $09, $68
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_3:
            .byte SOUND_CMD_SET_DELAY, $1C, SOUND_CMD_NO_NOTE, SOUND_CMD_SET_DELAY, $07, $0E, $18, $0D, $4E, $0C, $8F
            .byte $0B, $DA, $0B, $30, $0A, $8F, $09, $F7, $09, $68, $08, $E1, $08, $61, $07, $E9, $07, $77
            .byte SOUND_CMD_NEXT_PATTERN
        #if INCLUDE_INTRO
        pattern_4:
            .byte SOUND_CMD_NEXT_STATE, SOUND_CMD_SET_DELAY, $70, $19, $1E, SOUND_CMD_SET_DELAY, $38, $12, $D1
            .byte SOUND_CMD_SET_DELAY, $1C, $15, $1F, SOUND_CMD_SET_DELAY, $09, $12, $D1, $11, $C3, SOUND_CMD_SET_DELAY
            .byte $0A, $0E, $18, SOUND_CMD_SET_DELAY, $E0, $1C, $31
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_5:
            .byte SOUND_CMD_SET_DELAY, $70, $19, $3E, SOUND_CMD_SET_DELAY, $38, $12, $E9, SOUND_CMD_SET_DELAY, $1C, $15
            .byte $3A, SOUND_CMD_SET_DELAY, $09, $12, $E9, $11, $D9, SOUND_CMD_SET_DELAY, $0A, $0E, $2A
            .byte SOUND_CMD_SET_DELAY, $E0, $1C, $55
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_6:
            .byte SOUND_CMD_SET_DELAY, $07
        pattern_7:
            .byte $07, $0C, SOUND_CMD_RELEASE_NOTE, $0A, $8F, SOUND_CMD_RELEASE_NOTE, $0E, $18, SOUND_CMD_RELEASE_NOTE
            .byte $0A, $8F, SOUND_CMD_RELEASE_NOTE
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_8:
            .byte $09, $68, SOUND_CMD_RELEASE_NOTE, $0E, $18, SOUND_CMD_RELEASE_NOTE, $12, $D1, SOUND_CMD_RELEASE_NOTE
            .byte $0E, $18, SOUND_CMD_RELEASE_NOTE
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_9:
            .byte $06, $47, SOUND_CMD_RELEASE_NOTE, $09, $68, SOUND_CMD_RELEASE_NOTE, $0C, $8F, SOUND_CMD_RELEASE_NOTE
            .byte $09, $68, SOUND_CMD_RELEASE_NOTE, SOUND_CMD_NEXT_PATTERN
        pattern_10:
            .byte SOUND_CMD_SET_DELAY, $07, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $17, $B5, SOUND_CMD_RELEASE_NOTE
            .byte $1C, $31, SOUND_CMD_RELEASE_NOTE, $1F, $A5, SOUND_CMD_RELEASE_NOTE, $23, $86, SOUND_CMD_RELEASE_NOTE
            .byte $1F, $A5, SOUND_CMD_RELEASE_NOTE, $1C, $31, SOUND_CMD_RELEASE_NOTE, $17, $B5, SOUND_CMD_RELEASE_NOTE
            .byte $1F, $A5, SOUND_CMD_RELEASE_NOTE, $17, $B5, SOUND_CMD_RELEASE_NOTE, $1C, $31, SOUND_CMD_RELEASE_NOTE
            .byte $17, $B5, SOUND_CMD_RELEASE_NOTE, $11, $C3, SOUND_CMD_RELEASE_NOTE, $17, $B5, SOUND_CMD_RELEASE_NOTE
            .byte $0B, $DA, SOUND_CMD_RELEASE_NOTE, $11, $C3, SOUND_CMD_RELEASE_NOTE, SOUND_CMD_NO_NOTE
            .byte SOUND_CMD_NO_NOTE, $19, $1E, SOUND_CMD_RELEASE_NOTE, $1F, $A5, SOUND_CMD_RELEASE_NOTE, $23, $86
            .byte SOUND_CMD_RELEASE_NOTE, $25, $A2, SOUND_CMD_RELEASE_NOTE, $23, $86, SOUND_CMD_RELEASE_NOTE, $1F, $A5
            .byte SOUND_CMD_RELEASE_NOTE, $19, $1E, SOUND_CMD_RELEASE_NOTE, $23, $86, SOUND_CMD_RELEASE_NOTE, $19, $1E
            .byte SOUND_CMD_RELEASE_NOTE, $1F, $A5, SOUND_CMD_RELEASE_NOTE, $19, $1E, SOUND_CMD_RELEASE_NOTE, $12, $D1
            .byte SOUND_CMD_RELEASE_NOTE, $19, $1E, SOUND_CMD_RELEASE_NOTE, $0C, $8F, SOUND_CMD_RELEASE_NOTE, $12, $D1
            .byte SOUND_CMD_RELEASE_NOTE
        pattern_11:
            .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $10, $C3, $11, $C3, $1C, $31, $1A, $9C, $16, $60, $17, $B5
            .byte $1A, $9C, $1C, $31, $1F, $A5, $21, $87, $23, $86, $1C, $31, SOUND_CMD_SET_DELAY, $0E, $17, $B5
            .byte SOUND_CMD_SET_DELAY, $07, SOUND_CMD_NEXT_STATE
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_12:
            .byte SOUND_CMD_SET_DELAY, $07, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $17, $D3, SOUND_CMD_RELEASE_NOTE
            .byte $1C, $55, SOUND_CMD_RELEASE_NOTE, $1F, $CD, SOUND_CMD_RELEASE_NOTE, $23, $B3, SOUND_CMD_RELEASE_NOTE
            .byte $1F, $CD, SOUND_CMD_RELEASE_NOTE, $1C, $55, SOUND_CMD_RELEASE_NOTE, $17, $D3, SOUND_CMD_RELEASE_NOTE
            .byte $1F, $CD, SOUND_CMD_RELEASE_NOTE, $17, $D3, SOUND_CMD_RELEASE_NOTE, $1C, $55, SOUND_CMD_RELEASE_NOTE
            .byte $17, $D3, SOUND_CMD_RELEASE_NOTE, $11, $D9, SOUND_CMD_RELEASE_NOTE, $17, $D3, SOUND_CMD_RELEASE_NOTE
            .byte $0B, $E9, SOUND_CMD_RELEASE_NOTE, $11, $D9, SOUND_CMD_RELEASE_NOTE, SOUND_CMD_NO_NOTE
            .byte SOUND_CMD_NO_NOTE, $19, $3E, SOUND_CMD_RELEASE_NOTE, $1F, $CD, SOUND_CMD_RELEASE_NOTE, $23, $B3
            .byte SOUND_CMD_RELEASE_NOTE, $25, $D2, SOUND_CMD_RELEASE_NOTE, $23, $B3, SOUND_CMD_RELEASE_NOTE, $1F, $CD
            .byte SOUND_CMD_RELEASE_NOTE, $19, $3E, SOUND_CMD_RELEASE_NOTE, $23, $B3, SOUND_CMD_RELEASE_NOTE, $19, $3E
            .byte SOUND_CMD_RELEASE_NOTE, $1F, $CD, SOUND_CMD_RELEASE_NOTE, $19, $3E, SOUND_CMD_RELEASE_NOTE, $12, $E9
            .byte SOUND_CMD_RELEASE_NOTE, $19, $3E, SOUND_CMD_RELEASE_NOTE, $0C, $9F, SOUND_CMD_RELEASE_NOTE, $12, $E9
            .byte SOUND_CMD_RELEASE_NOTE
        pattern_13:
            .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $10, $D8, $11, $D9, $1C, $55, $1A, $BE, $16, $7C, $17, $D3
            .byte $1A, $BE, $1C, $55, $1F, $CD, $21, $B1, $23, $86, $1C, $55, SOUND_CMD_SET_DELAY, $0E, $17, $D3
            .byte SOUND_CMD_SET_DELAY, $07
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_14:
            .byte SOUND_CMD_SET_DELAY, $07
        pattern_15:
            .byte $05, $ED, SOUND_CMD_RELEASE_NOTE, $08, $E1, SOUND_CMD_RELEASE_NOTE, $0B, $DA, SOUND_CMD_RELEASE_NOTE
            .byte $08, $E1, SOUND_CMD_RELEASE_NOTE
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_16:
            .byte $06, $47, SOUND_CMD_RELEASE_NOTE, $09, $68, SOUND_CMD_RELEASE_NOTE, $0C, $8F, SOUND_CMD_RELEASE_NOTE
            .byte $09, $68, SOUND_CMD_RELEASE_NOTE
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_17:
            .byte $05, $ED, SOUND_CMD_RELEASE_NOTE, $08, $E1, SOUND_CMD_RELEASE_NOTE, $0B, $DA, SOUND_CMD_RELEASE_NOTE
            .byte $08, $E1, SOUND_CMD_RELEASE_NOTE
            .byte SOUND_CMD_NEXT_PATTERN
        pattern_18:
            .byte $07, $E9, SOUND_CMD_RELEASE_NOTE, $0B, $DA, SOUND_CMD_RELEASE_NOTE, $0F, $D2, SOUND_CMD_RELEASE_NOTE
            .byte $0B, $DA, SOUND_CMD_RELEASE_NOTE
            .byte SOUND_CMD_NEXT_PATTERN
        #endif
        pattern_19:
            .byte SOUND_CMD_SET_DELAY, $70, $19, $1E
            .byte SOUND_CMD_END
        pattern_20:
            .byte SOUND_CMD_SET_DELAY, $70, $0A, $8F, SOUND_CMD_NEXT_STATE
            .byte SOUND_CMD_END
        pattern_21:
            .byte SOUND_CMD_SET_DELAY, $70, $07, $0C
            .byte SOUND_CMD_END

        // Music patternology.
        #if INCLUDE_INTRO
        intro_pattern_V1_ptr: // Intro music voice 1 pattern list
            .word pattern_4, pattern_4, pattern_10, pattern_11, pattern_1
        #endif
        outro_pattern_V1_ptr:
            .word pattern_19 // Outro music voice 1 pattern list
        #if INCLUDE_INTRO
        intro_pattern_V2_ptr: // Intro music voice 2 pattern list
            .word pattern_5, pattern_5, pattern_12, pattern_13, pattern_2
        #endif
        outro_pattern_V2_ptr:
            .word pattern_21 // Outro music voice 2 pattern list
        #if INCLUDE_INTRO
        intro_pattern_V3_ptr: // Intro music voice 3 pattern list
            .word pattern_6, pattern_7, pattern_7, pattern_7, pattern_8, pattern_8, pattern_9, pattern_9
            .word pattern_6, pattern_7, pattern_7, pattern_7, pattern_8, pattern_8, pattern_9, pattern_9
            .word pattern_14, pattern_15, pattern_15, pattern_15, pattern_16, pattern_16, pattern_16, pattern_16
            .word pattern_17, pattern_17, pattern_18, pattern_18, pattern_3
        #endif
        outro_pattern_V3_ptr:
            .word pattern_20 // Outro music voice 3 pattern list
    }
}

relocated_resource_source_end:

// 4700
// Move resouces from temporary load location to the end of the application to free up space for the graphics
// display area.
* = $4700 "Relocation logic"
relocate:
    // Indicate that we have initialised the app, so we no don't need to run `prep` again if the app is restarted.
    lda #FLAG_ENABLE
    sta flag__is_relocated
    //
    // We only handle interrupts when the raster fires. So here we store the default system interrupt handler so that
    // we can call whenever a non-raster interrupt occurs.
    lda CINV
    sta main.ptr__system_interrupt_fn
    lda CINV+1
    sta main.ptr__system_interrupt_fn+1
    //
    // Move resources out of graphics memory to the end of the application.
    lda #<relocated_resource_source_start
    sta FREEZP
    lda #>relocated_resource_source_start
    sta FREEZP+1
    lda #<relocated_resource_destination_start
    sta FREEZP+2
    lda #>relocated_resource_destination_start
    sta FREEZP+3
    ldy #$00
    ldx #(>(relocated_resource_source_end - relocated_resource_source_start))+1
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+1
    inc FREEZP+3
    dex
    bne !loop-
    rts

//---------------------------------------------------------------------------------------------------------------------
// Resources from $5000 to $5fff will be relocated here.
.segment RelocatedResources
    relocated_resource_destination_start:

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// 02A7
flag__is_relocated: .byte FLAG_DISABLE // 00 for uninitialized, $80 for initialized
