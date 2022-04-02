(^.*[a-z0-9])\s{2,9}
$1

// ----------------------------------------------------------------------------------------------------------
// interrupt

// 9495
9495 BD 01 BD lda private.data__player_icon_sprite_speed_list,x
9498 29 60 and #(ICON_CAN_TRANSFORM + ICON_CAN_THRUST)
949A F0 0F beq W94AB
949C BD 03 BD lda private.data__player_weapon_sprite_speed_list,x
949F F0 0A beq W94AB
94A1 BD 29 BF lda common.param__icon_offset_list,x
94A4 C9 0E cmp #$0E
94A6 F0 03 beq W94AB
94A8 4C 28 95 jmp W9528 // skip moving for players currently thrusting or transforming (except banshee)

W94AB:
94AB BD 05 BD lda data__player_attack_strength_list,x
94AE D0 03 bne W94B3
94B0 4C 9B 95 jmp W959B

W94B3:
94B3 BD F8 BC lda private.data__sprite_barrier_phase_collision_list,x
94B6 F0 17 beq W94CF
94B8 10 10 bpl W94CA
94BA 20 A2 9A jsr W9AA2
94BD AD C0 BC lda game.data__ai_player_ctl
94C0 F0 05 beq W94C7
94C2 EC 26 BD cpx temp_data__curr_sprite_ptr
94C5 F0 31 beq W94F8
W94C7:
94C7 4C 9B 95 jmp W959B

W94CA:
94CA BD 1D BD lda cnt__icon_delay_list,x // Halves player speed when running over swamp
94CD 49 FF eor #$FF
W94CF:
94CF 9D 1D BD sta cnt__icon_delay_list,x
94D2 F0 03 beq W94D7
94D4 4C 9B 95 jmp W959B

W94D7:
94D7 BD 09 BD lda game_curr_icon_move_speed,x
94DA F0 12 beq W94EE
94DC FE 09 BD inc game_curr_icon_move_speed,x
94DF BD 09 BD lda game_curr_icon_move_speed,x
94E2 29 03 and #$03
94E4 D0 08 bne W94EE
94E6 A9 40 lda #$40
94E8 9D 09 BD sta game_curr_icon_move_speed,x
94EB 4C 9B 95 jmp W959B

W94EE:
94EE AD C0 BC lda game.data__ai_player_ctl
94F1 F0 0B beq W94FE
94F3 EC 26 BD cpx temp_data__curr_sprite_ptr
94F6 D0 06 bne W94FE
W94F8:
// 94F8 20 E3 9A jsr W9AE3 // AI
94FB 4C 28 95 jmp W9528

W94FE:
94FE 8A txa
94FF 49 01 eor #$01
9501 A8 tay
9502 B9 00 DC lda CIAPRA,y
9505 48 pha
9506 29 08 and #$08
9508 D0 06 bne W9510
950A 20 FC 95 jsr W95FC
950D 4C 19 95 jmp W9519

W9510:
9510 68 pla
9511 48 pha
9512 29 04 and #$04
9514 D0 03 bne W9519
9516 20 4B 96 jsr W964B
W9519:
9519 68 pla
951A 4A lsr
951B 48 pha
951C B0 03 bcs W9521
951E 20 A5 96 jsr W96A5
W9521:
9521 68 pla
9522 4A lsr
9523 B0 03 bcs W9528
9525 20 F8 96 jsr W96F8
W9528:
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
9554 8A txa
9555 49 01 eor #$01
9557 A8 tay
9558 B9 00 DC lda CIAPRA,y
955B 29 10 and #$10
955D D0 3C bne W959B
955F BD 29 BF lda common.param__icon_offset_list,x
9562 29 07 and #$07
9564 C9 06 cmp #$06
9566 D0 33 bne W959B // Not banshee or phoenix
9568 20 22 97 jsr W9722
956B 4C 9B 95 jmp W959B

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
9596 D0 03 bne W959B
9598 FE E7 BC inc board.cnt__sprite_frame_list,x


W959B:
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










/// ---------------------------------------------------------------------------------------------------------


















W9AA2:
9AA2 BD 3E BD lda board.data__sprite_curr_x_pos_list,x
9AA5 29 F0 and #$F0
9AA7 09 0C ora #$0C
9AA9 C9 91 cmp #$91
9AAB 90 02 bcc W9AAF
9AAD A9 91 lda #$91
W9AAF:
9AAF 9D 3E BD sta board.data__sprite_curr_x_pos_list,x
9AB2 BD 46 BD lda board.data__sprite_curr_y_pos_list,x
9AB5 18 clc
9AB6 69 08 adc #$08
9AB8 29 E0 and #$E0
9ABA C9 12 cmp #$12
9ABC B0 02 bcs W9AC0
9ABE 69 20 adc #$20
W9AC0:
9AC0 C9 AE cmp #$AE
9AC2 90 02 bcc W9AC6
9AC4 E9 20 sbc #$20
W9AC6:
9AC6 9D 46 BD sta board.data__sprite_curr_y_pos_list,x
9AC9 A9 00 lda #$00
9ACB 9D 36 BF sta temp_data__light_piece_count,x
9ACE 9D 32 BF sta temp_data__dark_piece_count,x
9AD1 BD 29 BF lda common.param__icon_offset_list,x
9AD4 C9 0E cmp #$0E
9AD6 D0 0A bne W9AE2
9AD8 BD 03 BD lda data__player_weapon_sprite_speed_list,x
9ADB F0 05 beq W9AE2
9ADD A2 01 ldx #$01
9ADF 4C CC 98 jmp set_banshee_attack_pos

W9AE2:
9AE2 60 rts




W95FC:
95FC B9 00 DC lda CIAPRA,y Data port A #1: keyboard, joystick, paddle, optical pencil
95FF 29 10 and #$10
9601 F0 1E beq W9621
W9603:
9603 BD 62 BD lda WBD62,x
9606 29 81 and #$81
9608 09 40 ora #$40
960A 9D 62 BD sta WBD62,x
960D EE 0D BD inc private.flag__was_icon_moved
9610 A9 00 lda #$00
9612 9D E3 BC sta common.param__icon_sprite_source_frame_list,x
9615 BD 3E BD lda board.data__sprite_curr_x_pos_list,x
9618 CD 02 7F cmp data__light_player_initial_x_pos+1
961B B0 03 bcs W9620
961D FE 3E BD inc board.data__sprite_curr_x_pos_list,x
W9620:
9620 60 rts

W9621:
9621 BD 21 BD lda cnt__player_cooldown_delay_list,x
9624 D0 FA bne W9620
W9626:
9626 EE 10 BD inc private.flag__is_weapon_active
9629 BD 01 BD lda data__player_attack_speed_list,x
962C 29 40 and #$40
962E D0 F0 bne W9620
9630 A9 0E lda #$0E
9632 9D E3 BC sta common.param__icon_sprite_source_frame_list,x
9635 BD 3E BD lda board.data__sprite_curr_x_pos_list,x
9638 18 clc
9639 69 09 adc #$09
963B 9D 40 BD sta board.data__sprite_curr_x_pos_list+2,x
963E BD 01 BD lda data__player_attack_speed_list,x
9641 9D 38 BF sta data__player_weapon_sprite_x_dir_list,x
9644 A9 00 lda #$00
9646 9D E5 BC sta common.param__icon_sprite_source_frame_list+2,x
9649 10 50 bpl W969B
W964B:
964B B9 00 DC lda CIAPRA,y Data port A #1: keyboard, joystick, paddle, optical pencil
964E 29 10 and #$10
9650 F0 1E beq W9670
W9652:
9652 BD 62 BD lda WBD62,x
9655 29 81 and #$81
9657 09 42 ora #$42
9659 9D 62 BD sta WBD62,x
965C EE 0D BD inc private.flag__was_icon_moved
965F A9 11 lda #LEFT_FACING_ICON_FRAME
9661 9D E3 BC sta common.param__icon_sprite_source_frame_list,x
9664 BD 3E BD lda board.data__sprite_curr_x_pos_list,x
9667 CD 01 7F cmp data__light_player_initial_x_pos
966A 90 03 bcc W966F
966C DE 3E BD dec board.data__sprite_curr_x_pos_list,x
W966F:
966F 60 rts


W9670:
9670 BD 21 BD lda cnt__player_cooldown_delay_list,x
9673 D0 FA bne W966F
W9675:
9675 EE 10 BD inc private.flag__is_weapon_active
9678 BD 01 BD lda data__player_attack_speed_list,x
967B 29 40 and #$40
967D D0 F0 bne W966F
967F A9 00 lda #$00
9681 38 sec
9682 FD 01 BD sbc data__player_attack_speed_list,x
9685 9D 38 BF sta data__player_weapon_sprite_x_dir_list,x
9688 A9 16 lda #$16
968A 9D E3 BC sta common.param__icon_sprite_source_frame_list,x
968D BD 3E BD lda board.data__sprite_curr_x_pos_list,x
9690 38 sec
9691 E9 07 sbc #$07
9693 9D 40 BD sta board.data__sprite_curr_x_pos_list+2,x
9696 A9 04 lda #$04
9698 9D E5 BC sta common.param__icon_sprite_source_frame_list+2,x
W969B:
969B BD 46 BD lda board.data__sprite_curr_y_pos_list,x
969E 18 clc
969F 69 04 adc #$04
96A1 9D 48 BD sta board.data__sprite_curr_y_pos_list+2,x
96A4 60 rts




W96F8:
96F8 B9 00 DC lda CIAPRA,y Data port A #1: keyboard, joystick, paddle, optical pencil
96FB 29 10 and #$10
96FD F0 23 beq W9722
W96FF:
96FF BD 62 BD lda WBD62,x
9702 29 42 and #$42
9704 09 80 ora #$80
9706 9D 62 BD sta WBD62,x
9709 AD 0D BD lda private.flag__was_icon_moved
970C D0 08 bne W9716
970E EE 0D BD inc private.flag__was_icon_moved
9711 A9 04 lda #$04
9713 9D E3 BC sta common.param__icon_sprite_source_frame_list,x
W9716:
9716 BD 46 BD lda board.data__sprite_curr_y_pos_list,x
9719 CD 04 7F cmp W7F04
971C B0 03 bcs W9721
971E FE 46 BD inc board.data__sprite_curr_y_pos_list,x
W9721:
9721 60 rts



W9722:
9722 BD 21 BD lda cnt__player_cooldown_delay_list,x
9725 D0 FA bne W9721
W9727:
9727 EE 10 BD inc private.flag__is_weapon_active
972A BD 01 BD lda data__player_attack_speed_list,x
972D 29 40 and #$40
972F D0 F0 bne W9721
9731 A9 10 lda #$10
9733 9D E3 BC sta common.param__icon_sprite_source_frame_list,x
9736 BD 01 BD lda data__player_attack_speed_list,x
9739 9D 34 BF sta data__player_weapon_sprite_y_dir_list,x
973C BD 46 BD lda board.data__sprite_curr_y_pos_list,x
973F 18 clc
9740 69 10 adc #$10
9742 9D 48 BD sta board.data__sprite_curr_y_pos_list+2,x
W9745:
9745 BD 38 BF lda data__player_weapon_sprite_x_dir_list,x
9748 D0 1A bne W9764
974A A0 00 ldy #$00
974C BD 34 BF lda data__player_weapon_sprite_y_dir_list,x
974F 30 01 bmi W9752
9751 C8 iny
W9752:
9752 BD 3E BD lda board.data__sprite_curr_x_pos_list,x
9755 18 clc
9756 79 62 97 adc W9762,y
9759 9D 40 BD sta board.data__sprite_curr_x_pos_list+2,x
975C A9 01 lda #$01
975E 9D E5 BC sta common.param__icon_sprite_source_frame_list+2,x
9761 60 rts


W9764:
9764 A0 02 ldy #$02
9766 BD 34 BF lda data__player_weapon_sprite_y_dir_list,x
9769 30 01 bmi W976C
976B C8 iny
W976C:
976C 98 tya
976D BC 38 BF ldy data__player_weapon_sprite_x_dir_list,x
9770 10 03 bpl W9775
9772 18 clc
9773 69 03 adc #$03
W9775:
9775 9D E5 BC sta common.param__icon_sprite_source_frame_list+2,x
9778 A0 0D ldy #$0D
977A BD 34 BF lda data__player_weapon_sprite_y_dir_list,x
977D 30 02 bmi W9781
977F C8 iny
9780 C8 iny
W9781:
9781 98 tya
9782 BC 38 BF ldy data__player_weapon_sprite_x_dir_list,x
9785 10 03 bpl W978A
9787 18 clc
9788 69 08 adc #$08
W978A:
978A 9D E3 BC sta common.param__icon_sprite_source_frame_list,x
978D A0 00 ldy #$00
978F BD 34 BF lda data__player_weapon_sprite_y_dir_list,x
9792 30 01 bmi W9795
9794 C8 iny
W9795:
9795 BD 48 BD lda board.data__sprite_curr_y_pos_list+2,x
9798 18 clc
9799 79 A0 97 adc W97A0,y
979C 9D 48 BD sta board.data__sprite_curr_y_pos_list+2,x
W979F:
979F 60 rts


W97A2:
97A2 AD 10 BD lda private.flag__is_weapon_active
97A5 F0 F8 beq W979F
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
980B 4C 63 98 jmp W9863

W980E:
980E A9 29 lda #$29 // banshee attack length
9810 9D 38 BF sta data__player_weapon_sprite_x_dir_list,x
9813 A9 08 lda #$08
9815 0D 1D D0 ora XXPAND (2X) horizontal expansion (X) sprite 0..7
9818 8D 1D D0 sta XXPAND (2X) horizontal expansion (X) sprite 0..7
981B A9 08 lda #$08
981D 0D 17 D0 ora YXPAND (2X) vertical expansion (Y) sprite 0..7
9820 8D 17 D0 sta YXPAND (2X) vertical expansion (Y) sprite 0..7
9823 4C B3 98 jmp banshee_attack

W9826:
9826 A9 0F lda #$0F
W9828:
9828 09 80 ora #$80
982A 9D 03 BD sta data__player_weapon_sprite_speed_list,x
982D 20 C2 99 jsr check_rotatating_projectile
9830 A9 00 lda #$00
9832 9D E5 BC sta common.param__icon_sprite_source_frame_list+2,x
9835 60 rts
