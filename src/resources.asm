.filenamespace resources
//---------------------------------------------------------------------------------------------------------------------
// Adds resources in the /assets directory in to build files.
//---------------------------------------------------------------------------------------------------------------------
// Resources are loaded at the start of the file so that they can be relocated as required to make room for graphics
// memory. See below for further details.
.segment Main

// 4700
// Move resouces from temporary load location to the end of the application to free up space for the graphics
// and screen display areas.
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
    // Move resources out of screen memory to the end of the application.
    lda #<private.prt__screen_block_start
    sta FREEZP
    lda #>private.prt__screen_block_start
    sta FREEZP+1
    lda #<private.prt__screen_block_relocate
    sta FREEZP+2
    lda #>private.prt__screen_block_relocate
    sta FREEZP+3
    ldx #>(private.prt__screen_block_end - private.prt__screen_block_start)
    // Copy full blocks of 255 bytes.
    ldy #$00
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+1
    inc FREEZP+3
    dex
    bne !loop-
    // Copy remaining bytes in the block.
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    cpy #<(private.prt__screen_block_end - private.prt__screen_block_start)
    bcc !loop-
    //
    // Move resources out of graphics memory to the end of the application.
    lda #<private.prt__graphic_block_relocate
    sta FREEZP+2
    lda #>private.prt__graphic_block_relocate
    sta FREEZP+3
    lda #>private.prt__graphic_block_start
    sta FREEZP+1
    lda #<private.prt__graphic_block_start
    sta FREEZP
    tay // Here the original assumes LSB of graphics area will always start at #$00
    ldx #(>(private.prt__graphic_block_end - private.prt__graphic_block_start))+1
!loop:
    lda (FREEZP),y
    sta (FREEZP+2),y
    iny
    bne !loop-
    inc FREEZP+1
    inc FREEZP+3
    dex
    bne !loop-
    jmp main.prep_game_states

//---------------------------------------------------------------------------------------------------------------------
// Resources
//---------------------------------------------------------------------------------------------------------------------
// OK this is a little bit special. Archon loads a single file including all resources. The resources have a large
// number of sprites for the various movement and battle animations. Memory managament is therefore quite complex.
// 
// Archon requires 2 character maps and screen data in the first 4k of graphics memory (there are lots of characters for
// each icon and logos etc) and spites in the second 4k (there are lots of sprites - enough for 2 characters to battle
// and throw projectiles and animate 4 directions and animate firing). Anyway, so this means we need 8k.
//
// We have limited options for placing graphics memory...VICII allows bank 0 ($0000), bank 1 ($4000), bank 2 ($8000)
// and bank 3 ($C000)...
// - We can use bank 0 however this is a little messy as we'd need to relocate the code that loads at $0801 onwards as
//   the graphics will take up to $3000.
// - We can use bank 1 however this requires us to either leave a big part of memory blank when we load the game (as the
//   game loads at $0801 and continues through to a little over $8000) or relocate code after the game loads.
// - We can use bank 2 however the code loads past this point, so we'd need to relocate some code or assets in
//   this area.
// - We can't use $C000 as this will take up $C000-$DFFF - we need registers in $D000 range to control graphics and
//   sound (ie this will only work if we need only 4kb of graphics).
// 
// The original source loads sprites in to memory just after $0801 up to $4000. It then loads the character maps in
// place ($4000-$43ff and $4800-$4fff), and has the remaining sprites (and some music data) from $5000 to $5fff. 
// The data between $5000 to $5fff is relocated to memory under basic ROM after the application starts using code
// fit between $4400 and $47ff. $4400-$47ff and $5000-$5fff is then cleared.
//
// So even though we are not trying to generate a byte for byte replication of the original source locations, we'll do
// something similar here as well for consistency.
//
// Our memory map is dictated by the fixed character map locations ($4000 and $4800) and the graphic area used to
// store sprites ($5000). We have therefore arranged the memory map as follows to try and stuff as many resources as
// possible in and around the graphics memory so that only resources will need to be relocated and all our code can
// remain inplace. This helps a lot with debugging and code readability.
//
// We've therefore stuffed the map as follows:
//   - $080e-$3fff: In-place resouces (sprite icons and game strings)
//   - $4000-$43ff: In-place character map 1 (intro character map)
//   - $4400-$47ff: Relocated resources (intro logo sprites and intro/outro music). We need to relocate these resources
//     as this area of memory is used for screen character display.
//   - $5000-$5fff: Relocated resources (projectile sprites and elemental icon sprites). We need to relocate these
//     resources as this area of memory will be used to store sprites that will be displayed on the screen.
//   - $6000>     : Additional in-place resources if required.
//
// This results in a few wasted bytes, but all-in-all we do end up with a pretty well packed prg file in the end:
//   - $0801-$080d Basic upstart
//   - $080e-$3ffa Resources
//   - $4000-$43ff Character set 1
//   - $4400-$47bf Relocted block #1
//   - $4800-$4fff Character set 2
//   - $5000-$5fb8 Relocted block #2
//   - $6000-      Source code and assets
//
// The relocated resources are placed directly after the end of the code and asset blocks.
.segment Resources

//---------------------------------------------------------------------------------------------------------------------
// 080e-3fff

// 0BAE-3D3F
// Icon sprites. Note that sprites are not 64 bytes in length like normal sprites. Archon sprites are smaller so
// that they can fit on a board sqare and therefore do not need to take up 64 bytes. Instead, sprites consume 54
// bytes only. The positive of this is that we use less memory for each sprite. The negative is that we can't just
// load the raw sprite binary file in to a sprite editor.
// Anyway, there are LOTS of sprites. Generally 15 sprites for each icon. This includes fram animations in each
// direction, attack animations and projectiles. NOTE that spearate frames for left moving and right moving
// animations. Instead, the routine used to load sprites in to graphical memory has a function that allows
// sprites to be mirrored when copied.
prt__sprites_icon: .import binary "/assets/sprites-icons.bin"

// A2AC
// Message strings used during gameplay.
#import "/assets/game_strings.asm"

#if INCLUDE_INTRO
    // A8C3
    // Message strings used in the intro.
    #import "/assets/intro_strings.asm"
#endif

//---------------------------------------------------------------------------------------------------------------------
// 4000-43ff

// Embed character map in place
*=CHRMEM1 "Character set 1"
#if INCLUDE_INTRO
    // 4000
    // Introduction character dot data including font and logos (Activision and Freefall).
    .import binary "/assets/charset-intro.bin"
#endif

//---------------------------------------------------------------------------------------------------------------------
// 4400-47ff (relocated)

*=CHRMEM1+$0400 "Relocted block #1"
.namespace private {
    prt__screen_block_start:
}
.pseudopc private.prt__screen_block_relocate {
    // BACB
    // Sprites used by intro title.
    // Sprites are contained in the following order:
    // - 0-3: Archon logo (in 3 parts)
    // - 4-6: Freefall logo (in 2 parts)
    #if INCLUDE_INTRO
        prt__sprites_logo: .import binary "/assets/sprites-logos.bin"
    #endif

    // 3D52
    // Music patterns for intro and outro music.
    #import "/assets/sound_music.asm"
}
.namespace private {
    prt__screen_block_end:
}

//---------------------------------------------------------------------------------------------------------------------
// 4800-4fff

*=CHRMEM2 "Character set 2"
// 4800
// Board character dot data including font and icons.
.import binary "/assets/charset-game.bin"

//---------------------------------------------------------------------------------------------------------------------
// 5000-5fff (relocated)

*=GRPMEM "Relocted block #2"
.namespace private {
    prt__graphic_block_start:
}
.pseudopc private.prt__graphic_block_relocate {
    // BACB
    // Sprites used by icons as projectiles within the battle arena.
    // The projectiles are only small and consume 32 bytes each. There is not a projectile sprite per icon as may
    // icons reuse the same projectile.
    ptr__sprites_projectile: .import binary "/assets/sprites-projectiles.bin"

    // AE23-BACA
    // Icon sprites for the 4 summonable elementals. The sprites are arranged the same as `prt__sprites_icon`.
    prt__sprites_elemental: .import binary "/assets/sprites-elementals.bin"

    // A15E
    // Sound effect patterns used the icons for moving and attacking and gameplay after each turn.
    #import "/assets/sound_effects.asm"
}
.namespace private {
    prt__graphic_block_end:
}

//---------------------------------------------------------------------------------------------------------------------
// 6000>
// ** If required.

*=$6000 "Additional resources"

//---------------------------------------------------------------------------------------------------------------------
// Resources from $5000 to $5fff will be relocated here.
.namespace private {
    .segment RelocatedResources

    * = * "Relocated Block 1" virtual
    prt__screen_block_relocate:

    * = * + $400 "Relocated Block 2" virtual
    prt__graphic_block_relocate:
}

//---------------------------------------------------------------------------------------------------------------------
// Data
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

// 02A7
// Is set ($80) if resource data has already been relocated out of the graphics memory area.
flag__is_relocated: .byte FLAG_DISABLE
