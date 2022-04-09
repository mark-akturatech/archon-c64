(^.*[a-z0-9])\s{2,9}
$1

W97A2:
97A2 AD 10 BD lda flag__is_weapon_active
97A5 F0 F8 beq !return-
97A7 A9 82 lda #PLAYER_SOUND_FIRE
97A9 DD 08 BF cmp common.flag__is_player_sound_enabled,x
97AC 90 23 bcc W97D1
97AE 9D 08 BF sta common.flag__is_player_sound_enabled,x
97B1 A9 00 lda #$00
97B3 9D 0B BF sta common.data__voice_note_delay,x
97B6 8A txa
97B7 0A asl
97B8 A8 tay
97B9 BD 0E BF lda ptr__player_attack_pattern_lo_list,x
97BC 99 3D 00 sta OLDTXT,y Pointer: BASIC instruction for CONT
97BF BD 10 BF lda ptr__player_attack_pattern_hi_list,x
97C2 99 3E 00 sta OLDTXT+1,y Pointer: BASIC instruction for CONT
97C5 AD FA A1 lda board_sound_phrase_shoot_01+4
97C8 9D 68 BD sta ptr__player_attack_sound_fq_lo_list,x
97CB AD FB A1 lda board_sound_phrase_shoot_01+5
97CE 9D 6A BD sta ptr__player_attack_sound_fq_hi_list,x
W97D1:
97D1 BC 29 BF ldy common.param__icon_offset_list,x
97D4 B9 D7 8A lda data__icon_attack_recovery_list,y
97D7 9D 21 BD sta cnt__player_cooldown_delay_list,x
97DA BD 01 BD lda data__player_attack_speed_list,x
97DD 29 60 and #$60
97DF F0 47 beq W9828
97E1 C9 20 cmp #$20
97E3 F0 41 beq W9826
97E5 9D 03 BD sta data__player_weapon_sprite_speed_list,x
97E8 A9 00 lda #$00
97EA 9D E9 BC sta board.cnt__sprite_frame_list+2,x
97ED 9D 38 BF sta data__player_weapon_sprite_x_dir_list,x
97F0 9D 34 BF sta data__player_weapon_sprite_y_dir_list,x
97F3 BD 29 BF lda common.param__icon_offset_list,x
97F6 C9 0E cmp #BANSHEE_OFFSET
97F8 F0 14 beq W980E
97FA BD E3 BC lda common.param__icon_sprite_source_frame_list,x
97FD 9D DC BC sta data__icon_sprite_frame_before_attack_list,x
9800 BD 46 BD lda board.data__sprite_curr_y_pos_list,x
9803 9D 47 BF sta data__icon_sprite_y_pos_before_attack_list,x
9806 A9 CE lda #SPRITE_Y_OFFSCREEN
9808 9D 46 BD sta board.data__sprite_curr_y_pos_list,x
980B 4C 63 98 jmp configure_phoenix_animation

W980E:
	// Configure Banshee scream. The scream will last for 40 frames (1 offset). The scream sprite is expanded
	// in the X and Y directions. Note that we can hardcode the expansion of sprite 4 only as Banshee is a
	// dark piece only (attack sprite 4) and light player doesn't have a Shape Shifter (unfortunately every
	// light player needs to allow for a dark player of the same type if challenging the Shape Shifter).
	.const BANSHEE_ATTACK_FRAMES = 41
	lda #BANSHEE_ATTACK_FRAMES
	sta data__player_weapon_sprite_x_dir_list,x
	lda #$08
	ora XXPAND
	sta XXPAND
	lda #$08
	ora YXPAND
	sta YXPAND
	jmp banshee_attack
W9826:
	lda #NUM_THRUST_WEAPON_FAMES
W9828:
9828 09 80 ora #$80
982A 9D 03 BD sta data__player_weapon_sprite_speed_list,x
	// Set animation initial frame if the projectile is rotating. Note that the routine returns to the parent if
	// the icon does not support a rotating projectile. See `check_rotatating_projectile` for more details.
	jsr check_rotatating_projectile
	lda #$00
	sta common.param__icon_sprite_source_frame_list+2,x
	rts



// ----------------------------------------------------------------------------------------------------------
// interrupt

	

// 9528
9528 AD 0D BD lda private.flag__was_icon_moved
952B D0 41 bne W956E
952D 9D E7 BC sta board.cnt__sprite_frame_list,x
9530 BD 08 BF lda common.flag__is_player_sound_enabled,x
9533 F0 1F beq W9554
9535 C9 80 cmp #$80
9537 D0 1B bne W9554
9539 A9 00 lda #$00
953B 9D 08 BF sta common.flag__is_player_sound_enabled,x
953E 9D 0B BF sta common.data__voice_note_delay,x
9541 8A txa
9542 0A asl
9543 A8 tay
9544 B9 AB A0 lda common.ptr__voice_ctl_addr_list,y
9547 85 FD sta FREEZP+2
9549 B9 AC A0 lda common.ptr__voice_ctl_addr_list+1,y
954C 85 FE sta FREEZP+3
954E A9 00 lda #$00
9550 A0 04 ldy #$04
9552 91 FD sta (FREEZP+2),y
W9554:

// phoenix and animation attack
9554 8A txa
9555 49 01 eor #$01
9557 A8 tay
9558 B9 00 DC lda CIAPRA,y
955B 29 10 and #%0001_0000 // Fire button
955D D0 3C bne !skip_move+
955F BD 29 BF lda common.param__icon_offset_list,x
9562 29 07 and #$07
9564 C9 06 cmp #$06
9566 D0 33 bne !skip_move+ // Not banshee or phoenix
9568 20 22 97 jsr attack_player
956B 4C 9B 95 jmp !skip_move+

W956E:
956E A9 80 lda #$80
9570 DD 08 BF cmp common.flag__is_player_sound_enabled,x
9573 F0 19 beq W958E
9575 90 17 bcc W958E
9577 9D 08 BF sta common.flag__is_player_sound_enabled,x
957A A9 00 lda #$00
957C 9D 0B BF sta common.data__voice_note_delay,x
957F 8A txa
9580 0A asl
9581 A8 tay
9582 BD 12 BF lda board_sound_phrase_lo_ptr,x
9585 99 3D 00 sta OLDTXT,y
9588 BD 14 BF lda board_sound_phrase_hi_ptr,x
958B 99 3E 00 sta OLDTXT+1,y
W958E:
958E FE EE BC inc temp_flag__alternating_state,x
9591 BD EE BC lda temp_flag__alternating_state,x
9594 29 03 and #$03
9596 D0 03 bne !skip_move+
9598 FE E7 BC inc board.cnt__sprite_frame_list,x


!skip_move:
959B 20 A2 97 jsr W97A2 // fire projectile?
959E BD 21 BD lda cnt__player_cooldown_delay_list,x
95A1 F0 23 beq W95C6
95A3 DE 21 BD dec cnt__player_cooldown_delay_list,x
95A6 D0 1E bne W95C6
95A8 A9 81 lda #PLAYER_SOUND_RECHARGE
95AA DD 08 BF cmp common.flag__is_player_sound_enabled,x
95AD 90 17 bcc W95C6
95AF 9D 08 BF sta common.flag__is_player_sound_enabled,x
95B2 A9 00 lda #$00
95B4 9D 0B BF sta common.data__voice_note_delay,x
95B7 8A txa
95B8 0A asl
95B9 A8 tay
95BA B9 F8 95 lda game.ptr__sound_game_effect_list,y
95BD 99 3D 00 sta OLDTXT,y
95C0 B9 F9 95 lda game.ptr__sound_game_effect_list+1,y
95C3 99 3E 00 sta OLDTXT+1,y
W95C6:
95C6 AD CB BC lda board_countdown_timer
95C9 F0 06 beq W95D1
95CB 8A txa
95CC 49 01 eor #$01
95CE 8D 26 BD sta temp_data__curr_sprite_ptr
W95D1:
	dex
	bmi !next+
	jmp !player_loop-
!next:

//
W95D7:
95D7 AD 2A BF lda common.param__icon_offset_list+1
95DA C9 0E cmp #$0E
95DC D0 13 bne W95F1
95DE AD 04 BD lda data__player_weapon_sprite_speed_list+1
95E1 F0 0E beq W95F1
95E3 AD E4 BC lda common.param__icon_sprite_source_frame_list+1
95E6 4A lsr
95E7 4A lsr
95E8 C9 03 cmp #$03
95EA 90 02 bcc W95EE
95EC A9 03 lda #$03
W95EE:
95EE 8D E6 BC sta common.param__icon_sprite_source_frame_list+3
W95F1:
95F1 4C 8E 63 jmp common_complete_interrupt




