.filenamespace challenge
//---------------------------------------------------------------------------------------------------------------------
// Code and assets used during challenge and battle erena game play.
//---------------------------------------------------------------------------------------------------------------------
.segment Game

// 7ACE
entry:
    // Redraw the board with only the challenge icons.
    jsr board.clear_text_area
    lda #FLAG_ENABLE
    sta board.param__render_square_ctl // Render only the current square when drawing the board
    jsr board.draw_board
    ldx #(1*JIFFIES_PER_SECOND)
    jsr common.wait_for_jiffy
    //
    sei
    lda #<main.play_challenge
    sta main.ptr__raster_interrupt_fn
    lda #>main.play_challenge
    sta main.ptr__raster_interrupt_fn+1
    cli
    // Configure sprites.
    lda #EMPTY_SPRITE_BLOCK
    sta SPTMEM+1
    sta SPTMEM+2
    sta SPTMEM+3
    sta SPTMEM+7
    jsr common.clear_mem_sprite_24
    jsr common.clear_mem_sprite_48
    jsr common.clear_mem_sprite_56_57
    lda #%0000_0011 // Icons multicolor, projectiles single color
    sta SPMC
    lda XXPAND
    and #%1111_1100 // Icons standard height, projectiles expanded in X direction
    sta XXPAND
    lda #%0000_0000 // No icons expanded in Y direction
    sta YXPAND
    //
    // Get the color of the square being challenged. This will be used to set the strength of the challenging
    // pieces. The logic below will generate a number from 0 to 7, where 0 is if square is black, 7 if square is
    // white and 2 to 6 depending on the current phase (with 2 being darkest phase and 6 being the lightest phase).
    // The number is then added to the strength of the piece as follows:
    // - Dark piece: Adds 7-strength (so if on white it adds 0, if on black adds 7)
    // - Light piece: Adds strength (so if on white it adds 7, black it adds 0)
    // Therefore a pieces strength will increase by up to 7 depending upon the color or phase of the challenged square.
    ldy board.data__curr_board_row
    sty board.data__curr_icon_row
    lda board.ptr__color_row_offset_lo,y
    sta CURLIN
    lda board.ptr__color_row_offset_hi,y
    sta CURLIN+1
    ldy board.data__curr_board_col
    sty board.data__curr_icon_col
    lda (CURLIN),y
    sta private.data__curr_square_color_code // Color of the sqauare - I don't think this is used anywhere
    // Get the battle square color (a) and a number between 0 and 7 (y). 0 is strongest on black, 7 is strongest on
    // white.
    beq !dark_square+
    bmi !vary_square+
    ldy #$07
    lda board.data__board_player_square_color_list+1 // White
    bne !next+
!dark_square:
    ldy #$00
    lda board.data__board_player_square_color_list // Black
    beq !next+
!vary_square:
    lda game.data__phase_cycle_board
    lsr
    tay
    lda game.data__phase_color // Phase color
!next:
    sta private.data__battle_square_color // Square color used to set battle arena border
    tya
    asl
    sta private.data__strength_adj_x2 // ??? Not used?
    sty private.data__strength_adj
    iny
    sty private.data__strength_adj_plus1 // ??? Not used?
    // Set A with light piece and Y with dark piece.
    lda common.param__icon_type_list
    ldy game.data__challenge_icon
    bit game.flag__is_light_turn
    bpl !next+
    ldy common.param__icon_type_list
    lda game.data__challenge_icon
!next:
    //
    // Configure battle pieces
    sta common.param__icon_type_list
    tax
    lda board.data__piece_icon_offset_list,x
    sta common.param__icon_offset_list
    sty common.param__icon_type_list+1
    lda board.data__piece_icon_offset_list,y
    tay
    cpy #SHAPESHIFTER_OFFSET // Shapeshifter?
    bne !next+
    ldy common.param__icon_offset_list // Set dark icon type to same as light icon
!next:
    sty common.param__icon_offset_list+1
    //
    ldx #(NUM_PLAYERS-1) // 0 offset
    // Create sprites at original coordinates on board. This will allow us to do the animation where the sprites slide
    // in to battle position.
!player_loop:
    // Create sprite group.
    jsr common.initialize_sprite
    lda #BYTERS_PER_ICON_SPRITE
    sta common.param__sprite_source_len
    jsr common.add_sprite_set_to_graphics
    // Place the sprite at the challenge square.
    lda board.data__curr_board_col
    ldy board.data__curr_board_row
    jsr board.convert_coord_sprite_pos
    // Configure player.
    ldy common.param__icon_offset_list,x
    lda private.data__icon_attack_speed_list,y
    sta private.data__player_attack_speed_list,x
    lda private.data__icon_attack_damage_list,y
    sta private.data__player_attack_damage_list,x
    // Configure icon projectile.
    tya
    asl
    tay
    lda private.ptr__projectile_sprite_mem_offset_list,y
    sta common.ptr__sprite_source_lo_list+2,x
    lda private.ptr__projectile_sprite_mem_offset_list+1,y
    sta common.ptr__sprite_source_hi_list+2,x
    //
    // Configure piece strength. The strength is adjusted by the square color they are fighting on. Shapeshifters
    // will obtain the initial full strength of the icon they are fighting, unless the shapeshifter is fighting an
    // elemental, in which case the strength is set to 10.
    ldy common.param__icon_type_list,x
    lda board.data__piece_icon_offset_list,y
    cmp #SHAPESHIFTER_OFFSET
    bne !not_shape_shifter+
    // Set Shape Shifter strength. Set to 10 if challenging an elemental, otherwise assume challenge icon initial
    // strength.
    ldy common.param__icon_offset_list
    cpy #AIR_ELEMENTAL_OFFSET
    bcc !skip+
    ldy #SHAPESHIFTER_OFFSET
!skip:
    lda game.data__icon_strength_list,y
    bne !adj_dark+ // Skip the player check as we know we are a dark player as Shape Shifter is only available to dark
!not_shape_shifter:
    lda game.data__piece_strength_list,y
    cpy #AIR_ELEMENTAL
    bcs !skip_adj+ // Don't adjust strength for elementals
    // Adjust strength. Remember the adjustment is the additional amount the light gains, so is 0 on a black square and
    // 7 on a light square. So if the number is 2, light will gain 2 strength and dark will gain 5 (7-2).
    cpx #$01 // Dark player?
    bne !adj_light+
!adj_dark:
    clc
    adc #$07
    sec
    sbc private.data__strength_adj // 7 - color strength adjustment
    jmp !adj_magic+
!adj_light:
    clc
    adc private.data__strength_adj // 0 + color strength adjustment
    // Add negative strength adjustment when defending a players magic square.
!adj_magic:
    jsr private.magic_square_strength_adj
    sec
    sbc magic.data__used_spell_count
!skip_adj:
    sta private.data__player_attack_strength_list,x
    //
    // Configure the icon sprite color.
    ldy common.param__icon_offset_list,x
    cpy #PHOENIX_OFFSET
    bne !set_color+
    // Enable sprite 3 multicolor for phonex attack animation. X is always 0 here.
    lda SPMC
    ora private.data__sprite_offset_bit_list,x
    sta SPMC
    lda common.data__player_icon_color_list,x
    bpl !skip+
!set_color:
    lda private.data__icon_projectile_color_list,y
!skip:
    sta SP2COL,x
    // Reset variables.
    lda #$00
    sta game.cnt__stalemate_moves // Reset stalemate counter
    // 7C12  9D 03 BD   sta WBD03,x // TODO
    sta game.data__icon_speed,x
    // 7C18  9D 21 BD   sta WBD21,x // TODO
    // Set icons speed.
    lda common.param__icon_offset_list,x
    cmp #EARTH_ELEMENTAL_OFFSET
    beq !set_slow_speed+
    and #%0001_0111
    cmp #$03 // Tests if icon is Golem or Troll
    bne !skip+
!set_slow_speed:
    lda #ICON_SLOW_SPEED
    sta game.data__icon_speed,x
!skip:
    // Configure sound.
    jsr board.get_sound_for_icon
    ldy common.param__icon_offset_list,x
    lda private.idx__sound_attack_pattern,y
    tay
    lda board.prt__sound_icon_effect_list,y
    sta private.ptr__player_attack_pattern_lo_list,x
    lda board.prt__sound_icon_effect_list+1,y
    sta private.ptr__player_attack_pattern_hi_list,x
    jsr board.set_icon_sprite_location
    //
    // Next player.
    dex
    bmi !next+
    jmp !player_loop-
!next:
    //
    // 7C4C
    lda #$11
    sta common.param__icon_sprite_source_frame_list+1 // Default dark player to left facing
    lda #$00
    sta common.flag__is_complete // Flag will be set to exit arena when battle is complete
    // Create projectile sprites
    ldx #$02
!loop:
    // Each projectile comprises 8 bytes. There are 4 sprite frames that are rotated to create sprites for each
    // direction. Up and down direction use the same sprite.
    lda #BYTERS_PER_PROJECTILE_SPRITE
    sta common.param__sprite_source_len
    jsr common.add_sprite_set_to_graphics
    inx
    cpx #$04
    bcc !loop-
    // Disable projectile sprites by default (they'll be enabled when one is shot)
    lda #%0000_1111
    ora SPENA
    sta SPENA
    lda private.data__icon_projectile_color_list+PHOENIX_OFFSET // Set color of Phoenix fire
    sta SPMC1
    jsr private.set_multicolor_screen
    jsr common.clear_screen
    jsr private.set_arena_colors
    // Set sprite starting positions. They will be animated from the current square to the starting position.
    lda #$19
    sta private.data__sprite_initial_x_pos_list
    lda #$7B
    sta private.data__sprite_initial_x_pos_list+1
    lda #$58
    sta private.data__sprite_initial_y_pos_list
    lda #$68
    sta private.data__sprite_initial_y_pos_list+1
    // Set player starting location.
    jsr private.set_player_sprite_location
    ldx #(1.5*JIFFIES_PER_SECOND)
    jsr common.wait_for_jiffy
    jsr common.clear_screen
    //
    lda #BLACK
    sta BGCOL0
    //
    // The challenge arena has a small character set at $6000
    lda #%0001_1000 // +$2000-$20FF char memory, +$0400-$07FF screen memory
    sta VMCSB
    //
    // Draw arena border.
    // Top border (row 1).
    lda #<SCNMEM
    sta FREEZP+2
    lda #>SCNMEM
    sta FREEZP+3
    .const NUM_HORIZONTAL_BORDERS = 3 // 2 x Top and 1 x bottom border
    ldx #NUM_HORIZONTAL_BORDERS
!border_loop:
    ldy #(NUM_SCREEN_COLUMNS-1) // 0 offset
!row_loop:
    .const BORDER_CHARACTER = $05
    lda #BORDER_CHARACTER // It's not great loading A every time within the loop.
    sta (FREEZP+2),y
    dey
    bpl !row_loop-
    dex
    bmi !next+
    beq !bottom_border+
    lda FREEZP+2
    clc
    adc #NUM_SCREEN_COLUMNS // Next screen row
    sta FREEZP+2
    bcc !border_loop-
    inc FREEZP+3
    jmp !border_loop-
    // Bottom border (rows 24 and 25).
!bottom_border:
    lda #<(SCNMEM+(NUM_SCREEN_ROWS-1)*NUM_SCREEN_COLUMNS)
    sta FREEZP+2
    lda #>(SCNMEM+(NUM_SCREEN_ROWS-1)*NUM_SCREEN_COLUMNS)
    sta FREEZP+3
    jmp !border_loop-
!next:
    // Side border (columns 1 and 40).
    ldx #(NUM_SCREEN_ROWS-2)
    lda #<(SCNMEM+NUM_SCREEN_COLUMNS)
    sta FREEZP+2
    lda #>SCNMEM
    sta FREEZP+3
!border_loop:
    ldy #$00
    lda #BORDER_CHARACTER
    sta (FREEZP+2),y // Left border
    ldy #(NUM_SCREEN_COLUMNS-1)
    sta (FREEZP+2),y // Right border
    lda FREEZP+2
    clc
    adc #NUM_SCREEN_COLUMNS
    sta FREEZP+2
    bcc !next+
    inc FREEZP+3
!next:
    dex
    bne !border_loop-
    //
    // Set single color mode for first character on each row.
    // This is so we can use the same character to represent current strength on both sides. Left side has
    // multicolor off and therefore will display as green, right side has multicolor on and will display as blue.
    ldx #(NUM_SCREEN_ROWS-1) // 0 offset
    lda #<COLRAM
    sta FREEZP+2
    lda #>COLRAM
    sta FREEZP+3
!loop:
    ldy #$00
    lda (FREEZP+2),y
    and #%1111_1000
    ora #%0000_0111 // Turn off multicolor bit
    sta (FREEZP+2),y
    lda FREEZP+2
    clc
    adc #NUM_SCREEN_COLUMNS
    sta FREEZP+2
    bcc !next+
    inc FREEZP+3
!next:
    dex
    bne !loop-
    // Set default secondary color to blue.
    lda common.data__player_icon_color_list+1
    sta BGCOL2
    // Set player starting positions.
    lda private.data__light_player_initial_x_pos
    sta private.data__sprite_initial_x_pos_list
    lda private.data__dark_player_initial_x_pos
    sta private.data__sprite_initial_x_pos_list+1
    jsr private.set_player_sprite_location
    //    


!brrrr:
    jmp !brrrr- // TODO remove


// 938D
interrupt_handler:
    jmp common.complete_interrupt // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//---------------------------------------------------------------------------------------------------------------------
// Private functions.
.namespace private {
    // 649D
    // Move player sprites in to the starting battle location.
    // `data__sprite_curr_y_pos_list` and `data__sprite_curr_x_pos_list` will be already set to the current location
    // of the sprites - on top of each other on the battle sqaure.
    // When moving the icons, the may need to move up or down or left or right depending upon the battle square and
    // the starting battle position.
    set_player_sprite_location:
        // OK here we set the 4th bit in a register. When a player sprite reaches the corrext X or Y position, the
        // register is shifted right. When the register reaches 0 we know both pieces are now at the corrext X and
        // Y position (as by then it would have been shifted 4 times). I can't work out why we don't just start with
        // #$03 and dec each time - maybe this is more efficient if you count clock cycles. But this isn't code that
        // needs to be highly optimized.
        lda #%0000_1000
        sta cnt__moves_remaining
        //
        ldx #(NUM_PLAYERS-1) // 0 offset
    !player_loop:
        // Adjust Y position
        lda board.data__sprite_curr_y_pos_list,x
        cmp data__sprite_initial_y_pos_list,x
        bcc !move_down+
        bne !move_up+
        lsr cnt__moves_remaining // At Y position
        jmp !next+
    !move_up:
        dec board.data__sprite_curr_y_pos_list,x
        jmp !next+
    !move_down:
        inc board.data__sprite_curr_y_pos_list,x
        // Adjust X position
    !next:
        lda board.data__sprite_curr_x_pos_list,x
        cmp data__sprite_initial_x_pos_list,x
        bcc !move_right+
        bne !move_left+
        lsr cnt__moves_remaining // At X position
        jmp !next+
    !move_left:
        dec board.data__sprite_curr_x_pos_list,x
        jmp !next+
    !move_right:
        inc board.data__sprite_curr_x_pos_list,x
    !next:
        jsr board.set_icon_sprite_location
        dex
        bpl !player_loop-
        // Add a short delay before each consecutive move (1/60th second).
        lda TIME+2
    !loop:
        cmp TIME+2
        beq !loop-
        // Keep moving to position if the sprites are not at the corretc position.
        lda cnt__moves_remaining
        beq !return+
        jmp set_player_sprite_location
    !return:
        rts

    // 7F05
    // Pieces will receive an negative strength adjustment when defending the caster magic square based on the number
    // of spells already cast by the spell caster. The caster magic square is the square that the spell caster
    // initially starts the game on.
    // I think the idea here is that the spell caster weakens the square as they cast spells, making the square harder
    // to defend.
    // Preserves:
    // - A, X
    magic_square_strength_adj:
        pha
        ldy #$00
        sty magic.data__used_spell_count
        lda board.data__curr_board_row
        .const MIDDLE_BOARD_ROW = 4
        cmp #MIDDLE_BOARD_ROW // Spell casters always start the game in the middle row
        bne !return+
        cpx #$00 // Light player
        beq !next+
        ldy #(BOARD_NUM_COLS-1) // Dark player coloumn (Y remains at 0 for light player row)
    !next:
        cpy board.data__curr_board_col
        bne !return+
        cpy #(BOARD_NUM_COLS-1)
        bne !skip+
        dey // `count_used_spells` needs 0 for light, 7 for dark in Y
    !skip:
        jsr magic.count_used_spells
    !return:
        pla
        rts

    // 7F63
    // Configures colors for battle arena.
    set_arena_colors:
        lda data__battle_square_color
        bne !skip+
        lda #DARK_GRAY // Use grey instead of black if fighting on a black square
    !skip:
        sta BGCOL0
        sta EXTCOL
        sta BGCOL1
        // Configure color data around the border of the battle arena.
        lda board.ptr__screen_row_offset_lo
        sta FREEZP+2
        sta VARPNT
        lda board.ptr__screen_row_offset_hi
        sta FREEZP+3
        clc
        adc common.data__color_mem_offset
        sta VARPNT+1
        ldx #(BOARD_NUM_ROWS*2) // 2 characters per row
    !row_loop:
        ldy #(BOARD_NUM_COLS*3-1) // 3 characters per column (0 offset)
    !char_loop:
        .const ARENA_CHARACTER = $60
        lda #ARENA_CHARACTER
        sta (FREEZP+2),y // Screen memory
        lda (VARPNT),y // Color memory
        // Reset color of all characters in the arena to the background color
        and #%1111_1000
        ora #%0000_1000
        sta (VARPNT),y
        dey
        bpl !char_loop-
        lda FREEZP+2
        clc
        adc #NUM_SCREEN_COLUMNS
        sta FREEZP+2
        sta VARPNT
        bcc !next+
        inc FREEZP+3
        inc VARPNT+1
    !next:
        dex
        bne !row_loop-
        rts

    // 9367
    // Enable multicolor character mode for all screen character locations.
    // If multicolor mode is enabled, bit 4 is used to turn on multicolor mode for the specified character. In this
    // mode, the color is controlled using the first 3 bits to select the appropriate color.
    set_multicolor_screen:
        lda #<COLRAM
        sta FREEZP+2
        lda #>COLRAM
        sta FREEZP+3
        ldx #$03
        ldy #$00
    !loop:
        lda (FREEZP+2),y
        ora #%0000_1000
        sta (FREEZP+2),y
        iny
        bne !loop-
        inc FREEZP+3
        dex
        bne !loop-
    !loop:
        lda (FREEZP+2),y
        ora #%0000_1000
        sta (FREEZP+2),y
        iny
        cpy #$E8 // Screen memory ends at +$03E8 (remaining bytes are used for sprite pointers)
        bcc !loop-
        rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 7F01
    // Starting X position of light player.
    data__light_player_initial_x_pos: .byte $08
        
    // 7F02
    // Starting X position of dark player.
    data__dark_player_initial_x_pos: .byte $91

    // 8BAA
    // Sound pattern used for attack sound of each icon type. The data is an index to the icon pattern pointer array.
    idx__sound_attack_pattern:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 12, 12, 12, 12, 12, 12, 16, 14, 12, 12, 12, 12, 12, 12, 18, 14, 12, 12, 12, 12

    // 8A8B
    // Icon attack Speed.
    // - 0-7 = speed
    // - 20 = non projectile directional weapon
    // - 40 = non projectile, surround weapon
    // - 00 = shapeshifter - it gets speed of opponent
    data__icon_attack_speed_list:
        //    UC, WZ, AR, GM, VK, DJ, PH,                 KN
        .byte 07, 05, 04, 03, 03, 04, ICON_CAN_TRANSFORM, ICON_CAN_THRUST
        //    BK, SR, MC, TL, SS, DG, BS,                 GB
        .byte 07, 06, 03, 03, 00, 04, ICON_CAN_TRANSFORM, ICON_CAN_THRUST
        //    AE, FE, EE, WE
        .byte 04, 05, 03, 03

    // 8AEB
    // Color of the icon projectile.
    data__icon_projectile_color_list:
        //    UC,     WZ,     AR,    GM     VK     DJ          PH      KN
        .byte YELLOW, ORANGE, BROWN, BROWN, BROWN, LIGHT_GRAY, ORANGE, WHITE
        //    BK,          SR,    MC,         TL,   SS,         DG,  BS,         GB
        .byte LIGHT_GREEN, WHITE, LIGHT_BLUE, GRAY, LIGHT_BLUE, RED, LIGHT_BLUE, BROWN
        //    AE,         FE,  EE,    WE
        .byte LIGHT_GRAY, RED, BROWN, BLUE

    // 8A9F
    // Icon attack Damage.
    // - 00 = shapeshifter - it gets damage of opponent
    data__icon_attack_damage_list:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 07, 10, 05, 10, 07, 06, 02, 05, 09, 08, 04, 10, 00, 11, 01, 05, 05, 09, 09, 06

    // 8AD7
    // Icon attack recovery speed (in number of jiffies).
    // - 00 = shapeshifter - it gets the recovery speed from the opponent
    data__icon_attack_recovery_list:
        //    UC,  WZ,  AR,  GM,  VK,  DJ,  PH,  KN,  BK,  SR,  MC,  TL,  SS,  DG,  BS,  GB,  AE,  FE,  EE,  WE
        .byte $3C, $50, $50, $64, $50, $5A, $64, $28, $3C, $50, $50, $64, $00, $78, $64, $28, $46, $3C, $64, $64

    // 8B4F
    // Projectile animation sprite offsets. Note that some icons use the same projectiles.
    // Phoenix and Banshee use full height shape data stored with the icon shape data.
    ptr__projectile_sprite_mem_offset_list:
        .word resources.ptr__sprites_projectile+00*BYTERS_PER_PROJECTILE_SPRITE*4 // UC
        .word resources.ptr__sprites_projectile+01*BYTERS_PER_PROJECTILE_SPRITE*4 // WZ
        .word resources.ptr__sprites_projectile+02*BYTERS_PER_PROJECTILE_SPRITE*4 // AR
        .word resources.ptr__sprites_projectile+03*BYTERS_PER_PROJECTILE_SPRITE*4 // GM
        .word resources.ptr__sprites_projectile+04*BYTERS_PER_PROJECTILE_SPRITE*4 // VK
        .word resources.ptr__sprites_projectile+05*BYTERS_PER_PROJECTILE_SPRITE*4 // DJ
        .word resources.prt__sprites_icon+PHOENIX_OFFSET*BYTERS_PER_ICON_SPRITE*15+BYTERS_PER_ICON_SPRITE*10 // PH                                                         // PH
        .word resources.ptr__sprites_projectile+07*BYTERS_PER_PROJECTILE_SPRITE*4 // KN
        .word resources.ptr__sprites_projectile+08*BYTERS_PER_PROJECTILE_SPRITE*4 // BK
        .word resources.ptr__sprites_projectile+09*BYTERS_PER_PROJECTILE_SPRITE*4 // SR
        .word resources.ptr__sprites_projectile+10*BYTERS_PER_PROJECTILE_SPRITE*4 // MC
        .word resources.ptr__sprites_projectile+03*BYTERS_PER_PROJECTILE_SPRITE*4 // TL
        .word resources.ptr__sprites_projectile+12*BYTERS_PER_PROJECTILE_SPRITE*4 // SS (not used)
        .word resources.ptr__sprites_projectile+13*BYTERS_PER_PROJECTILE_SPRITE*4 // DG
        .word resources.prt__sprites_icon+BANSHEE_OFFSET*BYTERS_PER_ICON_SPRITE*15+BYTERS_PER_ICON_SPRITE*10 // BS
        .word resources.ptr__sprites_projectile+15*BYTERS_PER_PROJECTILE_SPRITE*4 // GB
        .word resources.ptr__sprites_projectile+05*BYTERS_PER_PROJECTILE_SPRITE*4 // AE
        .word resources.ptr__sprites_projectile+12*BYTERS_PER_PROJECTILE_SPRITE*4 // FE
        .word resources.ptr__sprites_projectile+03*BYTERS_PER_PROJECTILE_SPRITE*4 // EE
        .word resources.ptr__sprites_projectile+12*BYTERS_PER_PROJECTILE_SPRITE*4 // WE

    // 98B1
    // Bits used to enable sprite 2 and 3 (and set color mode etc).
    // - 0 for sprite 2, 1 for sprite 3
    data__sprite_offset_bit_list:
        .byte %0000_0100 // Sprite 2 bit
        .byte %0000_1000 // Sprite 3 bit
}

//---------------------------------------------------------------------------------------------------------------------
// Variables
//---------------------------------------------------------------------------------------------------------------------
.segment Variables

//---------------------------------------------------------------------------------------------------------------------
// Private variables.
.namespace private {
    // BCF2
    // Current color of square in which a battle is being faught.
    data__battle_square_color: .byte $00

    // BCFE
    // Holds the number of moves remaining to shift the player pieces in to the starting location.
    cnt__moves_remaining: .byte $00

    // BD01
    // Attack speed for each challenge icon (light, dark).
    data__player_attack_speed_list: .byte $00, $00

    // BD05
    // Starting strength for each challenge icon (light, dark).
    data__player_attack_strength_list: .byte $00, $00

    // BD07
    // Attack damage for each challenge icon (light, dark).
    data__player_attack_damage_list: .byte $00, $00

    // BD12
    // Calculated strength adjustment based on color of the challenge square.
    data__strength_adj: .byte $00

    // BD15
    // Starting y position of each player.
    data__sprite_initial_y_pos_list: .byte $00, $00

    // BD17
    // Starting x position of each player.
    data__sprite_initial_x_pos_list: .byte $00, $00

    // BD23
    // Color of square where challenge was initiated. Used for determining icon strength.
    // TODO: Is this used?
    data__curr_square_color_code: .byte $00

    // BF0E
    // Low byte pointer to attack sound pattern for current icon (one byte for each player).
    ptr__player_attack_pattern_lo_list: .byte $00, $00

    // BF10
    // High byte pointer to attack sound pattern for current icon (one byte for each player).
    ptr__player_attack_pattern_hi_list: .byte $00, $00

    // BF36
    // Calculated strength adjustment based on color of the challenge square plus 1.
    // TODO: Is this used?
    data__strength_adj_plus1: .byte $00

    // BF41
    // Calculated strength adjustment based on color of the challenge square times 2.
    // TODO: Is this used?
    data__strength_adj_x2: .byte $00
}
