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
    sty private.data__curr_icon_type // ??? Not used?
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
!loop:
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


    rts // TODO remove


// 938D
interrupt_handler:
    jmp common.complete_interrupt // TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//---------------------------------------------------------------------------------------------------------------------
// Private functions.
.namespace private {
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
        ldy #$08 // Dark player row (Y is left at 0 for light player row)
    !next:
        cpy board.data__curr_board_col
        bne !return+
        cpy #$08
        bne !skip+
        dey // `count_used_spells` needs 0 for light, 7 for dark in Y
    !skip:
        jsr magic.count_used_spells
    !return:
        pla
        rts
}

//---------------------------------------------------------------------------------------------------------------------
// Assets
//---------------------------------------------------------------------------------------------------------------------
.segment Assets

//---------------------------------------------------------------------------------------------------------------------
// Private assets.
.namespace private {
    // 8BAA
    idx__sound_attack_pattern:
    // Sound pattern used for attack sound of each icon type. The data is an index to the icon pattern pointer array.
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 12, 12, 12, 12, 12, 12, 16, 14, 12, 12, 12, 12, 12, 12, 18, 14, 12, 12, 12, 12

    // 8A8B
    // Attack Speed.
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

    // 8A9F
    // Attack Damage.
    // - 00 = shapeshifter - it gets damage of opponent
    data__icon_attack_damage_list:
        //    UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
        .byte 07, 10, 05, 10, 07, 06, 02, 05, 09, 08, 04, 10, 00, 11, 01, 05, 05, 09, 09, 06

    // 8B4F
    // Projectile animation sprite offsets. Note that some icons use the same projectiles.
    // Phoenix and Banshee use full height shape data stored with the icon shape data.
    // TODO: what are sprites at positions 6, 11 and 14
    ptr__projectile_sprite_mem_offset_list:
        .word resources.ptr__sprites_projectile+00*BYTERS_PER_PROJECTILE_SPRITE // UC
        .word resources.ptr__sprites_projectile+01*BYTERS_PER_PROJECTILE_SPRITE // WZ
        .word resources.ptr__sprites_projectile+02*BYTERS_PER_PROJECTILE_SPRITE // AR
        .word resources.ptr__sprites_projectile+03*BYTERS_PER_PROJECTILE_SPRITE // GM
        .word resources.ptr__sprites_projectile+04*BYTERS_PER_PROJECTILE_SPRITE // VK
        .word resources.ptr__sprites_projectile+05*BYTERS_PER_PROJECTILE_SPRITE // DJ
        .word resources.prt__sprites_icon+PHOENIX_OFFSET*BYTERS_PER_ICON_SPRITE*15+BYTERS_PER_ICON_SPRITE*10 // PH                                                         // PH
        .word resources.ptr__sprites_projectile+07*BYTERS_PER_PROJECTILE_SPRITE // KN
        .word resources.ptr__sprites_projectile+08*BYTERS_PER_PROJECTILE_SPRITE // BK
        .word resources.ptr__sprites_projectile+09*BYTERS_PER_PROJECTILE_SPRITE // SR
        .word resources.ptr__sprites_projectile+10*BYTERS_PER_PROJECTILE_SPRITE // MC
        .word resources.ptr__sprites_projectile+03*BYTERS_PER_PROJECTILE_SPRITE // TL
        .word resources.ptr__sprites_projectile+12*BYTERS_PER_PROJECTILE_SPRITE // SS (not used)
        .word resources.ptr__sprites_projectile+13*BYTERS_PER_PROJECTILE_SPRITE // DG
        .word resources.prt__sprites_icon+BANSHEE_OFFSET*BYTERS_PER_ICON_SPRITE*15+BYTERS_PER_ICON_SPRITE*10 // BS
        .word resources.ptr__sprites_projectile+15*BYTERS_PER_PROJECTILE_SPRITE // GB
        .word resources.ptr__sprites_projectile+05*BYTERS_PER_PROJECTILE_SPRITE // AE
        .word resources.ptr__sprites_projectile+12*BYTERS_PER_PROJECTILE_SPRITE // FE
        .word resources.ptr__sprites_projectile+03*BYTERS_PER_PROJECTILE_SPRITE // EE
        .word resources.ptr__sprites_projectile+12*BYTERS_PER_PROJECTILE_SPRITE // WE
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
    // TODO: Is this used?
    data__battle_square_color: .byte $00

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

    // BD23
    // Color of square where challenge was initiated. Used for determining icon strength.
    // TODO: Is this used?
    data__curr_square_color_code: .byte $00

    // BF2E
    // Temporary storage for selected icon.
    // TODO: Is this used?
    data__curr_icon_type: .byte $00

    // BF36
    // Calculated strength adjustment based on color of the challenge square plus 1.
    // TODO: Is this used?
    data__strength_adj_plus1: .byte $00

    // BF41
    // Calculated strength adjustment based on color of the challenge square times 2.
    // TODO: Is this used?
    data__strength_adj_x2: .byte $00
}
