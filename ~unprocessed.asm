(^.*[a-z0-9])\s{2,9}
$1


---------------------------------------------------------------------------------------------

// 6FD7
get_score_walking_piece:
6FD7 8D 2B BD sta param__piece_number_moves // num moves
6FDA AD 29 BD lda idx__selected_piece_source_col
6FDD 38 sec
6FDE ED 2B BD sbc param__piece_number_moves
6FE1 B0 02 bcs W6FE5
6FE3 A9 00 lda #$00
W6FE5:
6FE5 8D 2C BD sta WBD2C // min reached col
6FE8 AD 29 BD lda idx__selected_piece_source_col
6FEB 18 clc
6FEC 6D 2B BD adc param__piece_number_moves
6FEF C9 09 cmp #$09
6FF1 90 02 bcc W6FF5
6FF3 A9 08 lda #$08
W6FF5:
6FF5 8D 3B BF sta idx__selected_piece_destination_col // max reached column
W6FF8:
6FF8 AD 29 BD lda idx__selected_piece_source_col
6FFB 38 sec
6FFC ED 3B BF sbc idx__selected_piece_destination_col
6FFF B0 04 bcs W7005
7001 49 FF eor #$FF
7003 69 01 adc #$01
W7005:
7005 8D 2F BF sta private.data__derived_score_adj
7008 AD 2B BD lda param__piece_number_moves
700B 38 sec
700C ED 2F BF sbc private.data__derived_score_adj
700F 8D 2F BF sta private.data__derived_score_adj
7012 AD 28 BD lda idx__selected_piece_source_row
7015 18 clc
7016 6D 2F BF adc private.data__derived_score_adj
7019 C9 09 cmp #$09
701B 90 02 bcc W701F
701D A9 08 lda #$08
W701F:
701F 8D 3A BF sta idx__selected_piece_destination_row
7022 AD 28 BD lda idx__selected_piece_source_row
7025 38 sec
7026 ED 2F BF sbc private.data__derived_score_adj
7029 10 02 bpl W702D
702B A9 00 lda #$00
W702D:
702D 8D 2A BD sta WBD2A // ^^ sets square boundary for moves
//
7030 20 99 70 jsr derive_offensive_score
7033 CE 3B BF dec idx__selected_piece_destination_col
7036 AD 3B BF lda idx__selected_piece_destination_col
7039 30 05 bmi W7040
703B CD 2C BD cmp WBD2C
703E B0 B8 bcs W6FF8
W7040:
7040 60 rts

get_score_flying_piece:
7041 29 0F and #$0F
7043 8D 2F BF sta private.data__derived_score_adj
7046 AD 28 BD lda idx__selected_piece_source_row
7049 38 sec
704A ED 2F BF sbc private.data__derived_score_adj
704D B0 02 bcs W7051
704F A9 00 lda #$00
W7051:
7051 8D 2A BD sta WBD2A
7054 AD 28 BD lda idx__selected_piece_source_row
7057 18 clc
7058 6D 2F BF adc private.data__derived_score_adj
705B C9 09 cmp #$09
705D 90 02 bcc W7061
705F A9 08 lda #$08
W7061:
7061 8D 2B BD sta param__piece_number_moves
7064 AD 29 BD lda idx__selected_piece_source_col
7067 38 sec
7068 ED 2F BF sbc private.data__derived_score_adj
706B B0 02 bcs W706F
706D A9 00 lda #$00
W706F:
706F 8D 2C BD sta WBD2C
7072 AD 29 BD lda idx__selected_piece_source_col
7075 18 clc
7076 6D 2F BF adc private.data__derived_score_adj
7079 C9 09 cmp #$09
707B 90 02 bcc W707F
707D A9 08 lda #$08
W707F:
707F 8D 3B BF sta idx__selected_piece_destination_col
W7082:
7082 AD 2B BD lda param__piece_number_moves
7085 8D 3A BF sta idx__selected_piece_destination_row
7088 20 99 70 jsr derive_offensive_score
708B CE 3B BF dec idx__selected_piece_destination_col
708E AD 3B BF lda idx__selected_piece_destination_col
7091 30 05 bmi W7098
7093 CD 2C BD cmp WBD2C
7096 B0 EA bcs W7082
W7098:
7098 60 rts

derive_offensive_score:
7099 20 05 71 jsr W7105
709C AD 22 BF lda flag__selected_move
709F 10 56 bpl W70F7
70A1 AE 2E BD ldx idx__selected_move
70A4 AD 2F BF lda private.data__derived_score_adj
70A7 38 sec
70A8 FD 49 BE sbc private.data__player_score_list,x
70AB 8D 2F BF sta private.data__derived_score_adj
70AE CD 2F BD cmp data__derived_player_score
70B1 90 44 bcc W70F7
70B3 BC 25 BE ldy private.data__player_piece_list,x
70B6 B9 FF 8A lda board.data__piece_icon_offset_list,y
70B9 A8 tay
70BA B9 C7 8A lda game.data__icon_num_moves_list,y
70BD 30 10 bmi W70CF
70BF AD 2F BF lda private.data__derived_score_adj
70C2 CD 42 BF cmp private.data__curr_highest_move_score
70C5 90 30 bcc W70F7
70C7 20 82 72 jsr find_path_to_destination
70CA AD 22 BF lda flag__selected_move
70CD 10 28 bpl W70F7
W70CF:
70CF AD 2F BF lda private.data__derived_score_adj
70D2 CD 2F BD cmp data__derived_player_score
70D5 D0 0E bne W70E5
W70D7:
70D7 AD 1B D4 lda RANDOM Random numbers generator oscillator 3
70DA 29 03 and #$03
70DC F0 F9 beq W70D7
70DE C9 02 cmp #$02
70E0 B0 15 bcs W70F7
70E2 AD 2F BF lda private.data__derived_score_adj
W70E5:
70E5 8D 2F BD sta data__derived_player_score
70E8 AC 2E BD ldy idx__selected_move
70EB AD 3A BF lda idx__selected_piece_destination_row
70EE 99 5B BE sta private.data__player_destination_row_list,y
70F1 AD 3B BF lda idx__selected_piece_destination_col
70F4 99 6D BE sta private.data__player_destination_col_list,y
W70F7:
70F7 CE 3A BF dec idx__selected_piece_destination_row
W70FA:
70FA AD 3A BF lda idx__selected_piece_destination_row
70FD 30 05 bmi W7104
70FF CD 2A BD cmp WBD2A
7102 B0 95 bcs derive_offensive_score
W7104:
7104 60 rts

W7105:
7105 A9 40 lda #(FLAG_ENABLE/2)
7107 8D 22 BF sta flag__selected_move
710A A9 00 lda #$00
710C 8D 12 BD sta challenge_square_strength_adj
710F 8D 2F BF sta private.data__derived_score_adj
7112 8D 23 BF sta magic.data__used_spell_count
7115 8D 24 BF sta main_temp_data__character_sprite_frame
7118 A0 09 ldy #$09
W711A:
711A 18 clc
711B 6D 3B BF adc idx__selected_piece_destination_col
711E 88 dey
711F D0 F9 bne W711A
7121 18 clc
7122 6D 3A BF adc idx__selected_piece_destination_row
7125 AA tax
7126 20 E2 71 jsr private.set_score__square_color
7129 A0 00 ldy #$00
712B 8C 3C BF sty temp_flag__adv_str
712E E0 24 cpx #BOARD_WIZARD_MAGIC_SQUARE_IDX
7130 D0 07 bne W7139
7132 AD C6 BC lda game.flag__is_light_turn
7135 30 10 bmi W7147
7137 10 0B bpl W7144
W7139:
7139 E0 2C cpx #BOARD_SOURCERESS_MAGIC_SQUARE_IDX
713B D0 1E bne W715B
713D A0 07 ldy #$07
713F AD C6 BC lda game.flag__is_light_turn
7142 10 03 bpl W7147
W7144:
7144 CE 3C BF dec temp_flag__adv_str
W7147:
7147 20 05 72 jsr magic.count_used_spells
714A 4E 23 BF lsr magic.data__used_spell_count
714D AD 3C BF lda temp_flag__adv_str
7150 F0 09 beq W715B
7152 A9 00 lda #$00
7154 38 sec
7155 ED 23 BF sbc magic.data__used_spell_count
7158 8D 23 BF sta magic.data__used_spell_count
W715B:
715B BC 7C BD ldy board.data__square_occupancy_list,x
715E 30 3C bmi W719C
7160 B9 FF 8A lda board.data__piece_icon_offset_list,y
7163 4D C0 BC eor game.data__ai_player_ctl
7166 29 08 and #$08
7168 F0 6D beq W71D7
716A B9 FD BD lda game.data__piece_strength_list,y
716D 8D 12 BD sta challenge_square_strength_adj
7170 B9 FF 8A lda board.data__piece_icon_offset_list,y
7173 A8 tay
7174 B9 B3 8A lda game.data__icon_strength_list,y
7177 8D 24 BF sta main_temp_data__character_sprite_frame
717A 38 sec
717B ED 12 BD sbc challenge_square_strength_adj
717E E9 03 sbc #$03
7180 ED 72 BD sbc param__piece_lost_strength
7183 18 clc
7184 6D 23 BF adc magic.data__used_spell_count
7187 6D 2F BF adc private.data__derived_score_adj
718A 6D 16 BF adc data__challenge_aggression_score
718D 8D 12 BD sta challenge_square_strength_adj
7190 AD 23 BF lda magic.data__used_spell_count
7193 30 07 bmi W719C
7195 18 clc
7196 6D 12 BD adc challenge_square_strength_adj
7199 8D 12 BD sta challenge_square_strength_adj
W719C:
719C BD 1F 72 lda data__square_occupancy_preference_list,x
719F 18 clc
71A0 6D 2F BF adc private.data__derived_score_adj
71A3 6D 23 BF adc magic.data__used_spell_count
71A6 6D 12 BD adc challenge_square_strength_adj
71A9 8D 2F BF sta private.data__derived_score_adj
71AC 0E 22 BF asl flag__selected_move
71AF AD 65 BD lda private.flag__end_of_game_strategy
71B2 F0 13 beq private.set_score__magic_square
71B4 AD 24 BF lda main_temp_data__character_sprite_frame
71B7 F0 0E beq private.set_score__magic_square
71B9 AD 73 BD lda param__piece_initial_strength
71BC 18 clc
71BD 6D 2F BF adc private.data__derived_score_adj
71C0 38 sec
71C1 ED 24 BF sbc main_temp_data__character_sprite_frame
71C4 8D 2F BF sta private.data__derived_score_adj
// ... private.set_score__magic_square
W71D7: rts



----










// 799E
// Determine if the AI should cast the heal spell.
check_cast_heal:
799E AD C0 BC lda game.data__ai_player_ctl
79A1 30 10 bmi W79B3
79A3 A0 08 ldy #$08
79A5 20 BE 79 jsr W79BE
79A8 A0 06 ldy #$06
79AA 20 BE 79 jsr W79BE
79AD A0 0A ldy #$0A
79AF 20 BE 79 jsr W79BE
79B2 60 rts
W79B3:
79B3 A0 1B ldy #$1B 
79B5 20 BE 79 jsr W79BE 
79B8 A0 1D ldy #$1D 
79BA 20 BE 79 jsr W79BE 
79BD 60 rts 
W79BE:
79BE B9 FD BD lda board_character_strength_data,y 
79C1 F0 10 beq W79D3 
79C3 C9 06 cmp #$06 
79C5 B0 0C bcs W79D3 
79C7 98 tya 
79C8 20 D9 79 jsr get_piece_position 
79CB 20 FF 62 jsr board_test_magic_square_selected 
79CE AD FE BC lda temp_data__curr_count 
79D1 10 01 bpl W79D4 
W79D3:
79D3 60 rts 
W79D4:
79D4 68 pla 
79D5 68 pla 
79D6 4C FD 79 jmp W79FD 

// 7905
// Determine if the AI should cast the exchange spell.
// Hint: never :)
check_cast_exchange:
	rts

// 7906
// Determine if the AI should cast the revive spell.
check_cast_revive:
7906 AD 29 BD lda idx__selected_piece_source_col
7909 8D 25 BF sta temp_data__curr_icon_row
790C AD 28 BD lda idx__selected_piece_source_row
790F 8D 27 BF sta temp_data__curr_icon_col
//Description:
//- Checks if any of the squares surrounding the current square is empty and non-magical.
//Prerequisites:
//- `main.temp.data__curr_icon_row`: row of source square
//- `main.temp.data__curr_icon_col`: column of source square
//Sets:
//- `main.temp.flag__is_valid_square`: #$80 if one or more surrounding squares are empty and non-magical
//- `surrounding_square_row`: Contains an array of rows for all 9 squares (including source)
//- `surrounding_square_column`: Contains an array of columns for all 9 squares (including source)
game_check_mt_non_mgc_surround_sqr:
7912 A9 40 lda #$40
...


// 7796
// Determine if the AI should cast the teleport spell.
check_cast_teleport:
7796 20 B5 76 jsr W76B5
7799 AD 3C BF lda temp_flag__adv_str
779C 30 5C bmi W77FA
779E AD DE BC lda game.data__player_offset
77A1 49 01 eor #$01
77A3 A8 tay
77A4 AD 87 BE lda data__selected_icon_id
77A7 D9 24 BD cmp game.data__imprisoned_icon_list,y
77AA D0 19 bne W77C5
77AC AC 1A BF ldy idx__square_offset
W77AF:
77AF B9 5D 0B lda board.data__board_square_color_list,y
77B2 10 11 bpl W77C5
77B4 AE 40 BF ldx game.data__phase_cycle_board
77B7 AD C0 BC lda game.data__ai_player_ctl
77BA 30 05 bmi W77C1
77BC E0 0C cpx #$0C
77BE B0 05 bcs W77C5
77C0 60 rts
W77C1:
77C1 E0 04 cpx #$04 
77C3 B0 2F bcs W77F4 
W77C5:
77C5 A0 05 ldy #$05 
77C7 A2 00 ldx #$00 
77C9 AD C0 BC lda game_state_flag__ai_player_ctl 
77CC 10 02 bpl W77D0 
77CE A2 08 ldx #$08 
W77D0:
77D0 8A txa 
77D1 48 pha 
77D2 BD 7C BD lda board_square_occupant_data,x 
77D5 30 12 bmi W77E9 
77D7 8D 2D BF sta board_icon_type 
77DA AA tax 
77DB BD FF 8A lda board.data__piece_icon_offset_list,x 
77DE 4D C0 BC eor game_state_flag__ai_player_ctl 
77E1 29 08 and #$08 
77E3 D0 04 bne W77E9 
77E5 68 pla 
77E6 4C F0 78 jmp W78F0 
W77E9:
77E9 68 pla 
77EA 88 dey 
77EB 30 07 bmi W77F4 
77ED 18 clc 
77EE 79 F5 77 adc W77F5,y 
77F1 AA tax 
77F2 10 DC bpl W77D0 
W77F4:
77F4 60 rts 
W77F5:
77F5 EE E5 12 inc W12E5 
77F8 24 12 bit $12 Flag: TAN/Result symbol of one comparison
W77FA:
77FA AD 1B D4 lda RANDOM Random numbers generator oscillator 3
77FD 29 03 and #$03 
77FF D0 F3 bne W77F4 
W7801:
7801 AD 1B D4 lda RANDOM Random numbers generator oscillator 3
7804 29 0F and #$0F 
7806 C9 09 cmp #$09 
7808 B0 F7 bcs W7801 
780A A8 tay 
780B B9 C0 BE lda board_row_occupancy_lo_ptr,y 
780E 85 FB sta FREEZP Free 0 page for user program
7810 B9 C9 BE lda board_row_occupancy_hi_ptr,y 
7813 85 FC sta FREEZP+1 
7815 8C 30 BF sty temp_data__curr_line 
7818 A0 00 ldy #$00 
781A AD C0 BC lda game_state_flag__ai_player_ctl 
781D 10 02 bpl W7821 
781F A0 08 ldy #$08 
W7821:
7821 8C 31 BF sty temp_data__curr_column 
7824 B1 FB lda (FREEZP),y Free 0 page for user program
7826 30 CC bmi W77F4 
7828 A8 tay 
7829 B9 FF 8A lda board.data__piece_icon_offset_list,y 
782C 4D C0 BC eor game_state_flag__ai_player_ctl 
782F 29 08 and #$08 
7831 D0 C1 bne W77F4 
7833 8C 2D BF sty board_icon_type 
7836 B9 FF 8A lda board.data__piece_icon_offset_list,y 
7839 29 07 and #$07 
783B C9 03 cmp #$03 
783D F0 54 beq W7893 
783F A9 08 lda #$08 
7841 38 sec 
7842 ED 30 BF sbc temp_data__curr_line 
7845 A8 tay 
7846 8D 6E BE sta WBE6E 
7849 B9 C0 BE lda board_row_occupancy_lo_ptr,y 
784C 85 FB sta FREEZP Free 0 page for user program
784E B9 C9 BE lda board_row_occupancy_hi_ptr,y 
7851 85 FC sta FREEZP+1 
7853 B9 D2 BE lda board_row_color_lo_ptr,y 
7856 85 39 sta CURLIN BASIC current line number
7858 B9 DB BE lda board_row_color_hi_ptr,y 
785B 85 3A sta CURLIN+1 BASIC current line number
785D AD 31 BF lda temp_data__curr_column 
7860 49 08 eor #$08 
7862 A8 tay 
7863 8D 5C BE sta WBE5C 
7866 B1 FB lda (FREEZP),y Free 0 page for user program
7868 30 28 bmi W7892 
786A A8 tay 
786B B9 FF 8A lda board.data__piece_icon_offset_list,y 
786E 4D C0 BC eor game_state_flag__ai_player_ctl 
7871 F0 1F beq W7892 
7873 AC 5C BE ldy WBE5C 
7876 B1 39 lda (CURLIN),y BASIC current line number
7878 F0 13 beq W788D 
787A 10 09 bpl W7885 
787C AD 40 BF lda game.data__phase_cycle_board 
787F F0 0C beq W788D 
7881 C9 0E cmp #$0E 
7883 D0 0D bne W7892 
W7885:
7885 AD C0 BC lda game_state_flag__ai_player_ctl 
7888 30 08 bmi W7892 
W788A:
788A 4C FD 79 jmp W79FD 
W788D:
788D AD C0 BC lda game_state_flag__ai_player_ctl 
7890 30 F8 bmi W788A 
W7892:
7892 60 rts 
W7893:
7893 AD 1B D4 lda RANDOM Random numbers generator oscillator 3
7896 4A lsr 
7897 B0 F9 bcs W7892 
7899 A9 00 lda #$00 
789B 8D 42 BF sta private.data__curr_highest_move_score 
789E A9 08 lda #$08 
78A0 8D 3B BF sta idx__selected_piece_destination_col 
W78A3:
78A3 A9 02 lda #$02 
78A5 8D 3B BD sta WBD3B 
78A8 A9 06 lda #$06 
78AA AC C0 BC ldy game_state_flag__ai_player_ctl 
78AD 10 02 bpl W78B1 
78AF A9 01 lda #$01 
W78B1:
78B1 8D 3A BF sta idx__selected_piece_destination_row 
W78B4:
78B4 20 05 71 jsr W7105 
78B7 AD 22 BF lda flag__selected_move 
78BA 10 1E bpl W78DA 
78BC 4E 22 BF lsr flag__selected_move 
78BF AD 2F BF lda private.data__derived_score_adj 
78C2 CD 42 BF cmp private.data__curr_highest_move_score 
78C5 90 13 bcc W78DA 
78C7 C9 30 cmp #$30 
78C9 90 0F bcc W78DA 
78CB 8D 42 BF sta private.data__curr_highest_move_score 
78CE AD 3A BF lda idx__selected_piece_destination_row 
78D1 8D 5C BE sta WBE5C 
78D4 AD 3B BF lda idx__selected_piece_destination_col 
78D7 8D 6E BE sta WBE6E 
W78DA:
78DA EE 3A BF inc idx__selected_piece_destination_row 
78DD CE 3B BD dec WBD3B 
78E0 D0 D2 bne W78B4 
78E2 CE 3B BF dec idx__selected_piece_destination_col 
78E5 10 BC bpl W78A3 
78E7 AD 42 BF lda private.data__curr_highest_move_score 
78EA F0 03 beq W78EF 
78EC 4C FD 79 jmp W79FD 
W78EF:
78EF 60 rts 
W78F0:
78F0 AD 30 BF lda temp_data__curr_line 
78F3 8D 6E BE sta WBE6E 
78F6 AD 31 BF lda temp_data__curr_column 
78F9 8D 5C BE sta WBE5C 
78FC AD 2D BF lda board_icon_type 
78FF 20 D9 79 jsr get_piece_position 
7902 4C FD 79 jmp W79FD 

// 7752
// Determine if the AI should cast the summon elemental spell.
check_cast_summon_elemental:
7752 20 B5 76 jsr W76B5
7755 AD 3C BF lda temp_flag__adv_str
7758 10 11 bpl W776B
775A 20 BC 75 jsr W75BC
775D AD 3C BF lda temp_flag__adv_str
7760 30 09 bmi W776B
7762 20 62 76 jsr W7662
7765 AD 3C BF lda temp_flag__adv_str
7768 30 0F bmi W7779
776A 60 rts
W776B:
776B AD DE BC lda game_curr_player_offset 
776E 49 01 eor #$01 
7770 A8 tay 
7771 AD 87 BE lda curr_dead_icon_types 
7774 D9 24 BD cmp game_imprisoned_icon_id,y 
7777 D0 1A bne W7793 
W7779:
7779 AE 1A BF ldx idx__square_offset 
777C BD 5D 0B lda board.data__board_square_color_list,x 
777F 10 12 bpl W7793 
7781 AE 40 BF ldx game.data__phase_cycle_board 
7784 AD C0 BC lda game_state_flag__ai_player_ctl 
7787 10 05 bpl W778E 
7789 E0 04 cpx #$04 
778B 90 06 bcc W7793 
778D 60 rts 
W778E:
778E E0 0C cpx #$0C 
7790 B0 01 bcs W7793 
7792 60 rts 
W7793:
7793 4C FD 79 jmp W79FD 

// 76D6
// Determine if the AI should cast the shift time spell.
check_cast_shift_time:
76D6 A0 00 ldy #$00
76D8 AD C0 BC lda game.data__ai_player_ctl
76DB 10 02 bpl W76DF
76DD A0 FF ldy #$FF
W76DF:
76DF CC CA BC cpy main_state_counter+3
76E2 D0 23 bne W7707
76E4 AD 40 BF lda game.data__phase_cycle_board
76E7 F0 04 beq W76ED
76E9 C9 0E cmp #$0E
76EB D0 19 bne W7706
W76ED:
76ED 8D 1A BF sta idx__square_offset
76F0 A0 00 ldy #$00
76F2 AD C0 BC lda game.data__ai_player_ctl
76F5 30 02 bmi W76F9
76F7 A0 0E ldy #$0E
W76F9:
76F9 CC 1A BF cpy idx__square_offset
76FC F0 31 beq W772F
76FE AC DE BC ldy game.data__player_offset
7701 B9 24 BD lda game.data__imprisoned_icon_list,y
7704 10 29 bpl W772F
W7706:
7706 60 rts
...
W772F:
772F 4C FD 79 jmp W79FD // set spell used 

// 7524
// Determine if the AI should cast the imprison spell.
check_cast_imprison:
7524 AE 40 BF ldx game.data__phase_cycle_board
7527 A9 00 lda #$00
7529 AC C0 BC ldy game.data__ai_player_ctl
752C 10 02 bpl !next+
752E A9 0E lda #$0E
!next:
7530 8D 1A BF sta idx__square_offset
7533 EC 1A BF cpx idx__square_offset
7536 F0 1F beq !return+
7538 A9 00 lda #$00
753A AC C0 BC ldy game.data__ai_player_ctl
753D 10 02 bpl W7541
753F A9 FF lda #$FF
W7541:
7541 CD CA BC cmp main_state_counter+3
7544 F0 16 beq W755C
7546 A0 02 ldy #$02
7548 B1 47 lda (VARPNT),y
754A C9 FE cmp #SPELL_USED
754C F0 09 beq !return+
754E AD C0 BC lda game.data__ai_player_ctl
7551 30 05 bmi W7558
7553 E0 04 cpx #$04
7555 B0 05 bcs W755C
!return:
	rts
W7558:
7558 E0 0C cpx #$0C 
755A B0 5C bcs W75B8 
W755C:
755C 8A txa 
755D 48 pha 
755E 20 B5 76 jsr W76B5 
7561 68 pla 
7562 AA tax 
7563 AD 3C BF lda temp_flag__adv_str 
7566 10 51 bpl W75B9 
7568 A9 00 lda #$00 
756A AC C0 BC ldy game_state_flag__ai_player_ctl 
756D 10 02 bpl W7571 
756F A9 FF lda #$FF 
W7571:
7571 CD CA BC cmp main_state_counter+3 
7574 D0 42 bne W75B8 
7576 A0 02 ldy #SPELL_ID_SHIFT_TIME 
7578 B1 3B lda (OLDLIN),y BASIC precedent line number
757A C9 FE cmp #SPELL_USED 
757C F0 1C beq W759A 
757E B1 47 lda (VARPNT),y Pointer: BASIC current variable data
7580 C9 FE cmp #SPELL_USED 
7582 F0 34 beq W75B8 
7584 AD C2 BC lda game_state_flag__is_first_player_light 
7587 CD C0 BC cmp game_state_flag__ai_player_ctl 
758A D0 0E bne W759A 
758C AD C0 BC lda game_state_flag__ai_player_ctl 
758F 30 05 bmi W7596 
7591 E0 06 cpx #$06 
7593 B0 05 bcs W759A 
7595 60 rts 
W7596:
7596 E0 0A cpx #$0A 
7598 B0 1E bcs W75B8 
W759A:
759A AD C0 BC lda game_state_flag__ai_player_ctl 
759D 30 05 bmi W75A4 
759F E0 0A cpx #$0A 
75A1 90 05 bcc W75A8 
75A3 60 rts 
W75A4:
75A4 E0 06 cpx #$06 
75A6 90 10 bcc W75B8 
W75A8:
75A8 20 BC 75 jsr W75BC 
75AB AD 3C BF lda temp_flag__adv_str 
75AE 30 09 bmi W75B9 
75B0 20 62 76 jsr W7662 
75B3 AD 3C BF lda temp_flag__adv_str 
75B6 30 01 bmi W75B9 
W75B8:
75B8 60 rts 
W75B9:
75B9 4C FD 79 jmp W79FD 











W79FD:
	asl flag__selected_move 
7A00 AE 3A BD ldx temp_data__offset 
	ldy data__spell_check_priority_list,x 
	lda #SPELL_USED 
	sta (VARPNT),y
7A0A B9 8C 8B lda frequencyHi1,y 
7A0D 8D 4F BD sta WBD4F 
7A10 AD 31 BF lda temp_data__curr_column 
7A13 8D 50 BD sta WBD50 
7A16 AC 30 BF ldy temp_data__curr_line 
7A19 8C 51 BD sty WBD51 
7A1C 60 rts 



W75BC:
75BC A9 40 lda #$40 
75BE 8D 3C BF sta temp_flag__adv_str 
75C1 A9 00 lda #$00 
75C3 8D 42 BF sta private.data__curr_highest_move_score 
75C6 A2 FF ldx #$FF 
75C8 A9 02 lda #$02 
75CA 8D 3B BF sta idx__selected_piece_destination_col 
75CD A9 05 lda #$05 
75CF 8D 38 BD sta temp_data__num_pieces // number of moves?
W75D2:
75D2 A9 04 lda #$04 
75D4 8D 3B BD sta WBD3B 
75D7 A9 00 lda #$00 
75D9 AC C0 BC ldy game_state_flag__ai_player_ctl 
75DC 10 02 bpl W75E0 
75DE A9 05 lda #$05 
W75E0:
75E0 8D 3A BF sta idx__selected_piece_destination_row 
75E3 AC 3B BF ldy idx__selected_piece_destination_col 
75E6 B9 C0 BE lda board_row_occupancy_lo_ptr,y 
75E9 85 FB sta FREEZP Free 0 page for user program
75EB B9 C9 BE lda board_row_occupancy_hi_ptr,y 
75EE 85 FC sta FREEZP+1 
W75F0:
75F0 AC 3A BF ldy idx__selected_piece_destination_row 
75F3 B1 FB lda (FREEZP),y Free 0 page for user program
75F5 30 35 bmi W762C 
75F7 A8 tay 
75F8 B9 FF 8A lda board.data__piece_icon_offset_list,y 
75FB 8D 23 BF sta magic.data__used_spell_count 
75FE 4D C0 BC eor game_state_flag__ai_player_ctl 
7601 29 08 and #$08 
7603 F0 27 beq W762C 
7605 AD C0 BC lda game_state_flag__ai_player_ctl 
7608 10 04 bpl W760E 
760A A9 07 lda #$07 
760C 10 02 bpl W7610 
W760E:
760E A9 0F lda #$0F 
W7610:
7610 CD 23 BF cmp magic.data__used_spell_count 
7613 F0 17 beq W762C 
7615 E8 inx 
7616 98 tya 
7617 9D 25 BE sta private.data__player_piece_list,x 
761A B9 FF 8A lda board.data__piece_icon_offset_list,y 
761D A8 tay 
761E B9 B3 8A lda game.data__icon_strength_list,y 
7621 9D 49 BE sta private.data__player_score_list,x 
7624 CD 42 BF cmp private.data__curr_highest_move_score 
7627 90 03 bcc W762C 
7629 8D 42 BF sta private.data__curr_highest_move_score 
W762C:
762C EE 3A BF inc idx__selected_piece_destination_row 
762F CE 3B BD dec WBD3B 
7632 D0 BC bne W75F0 
7634 EE 3B BF inc idx__selected_piece_destination_col 
7637 CE 38 BD dec temp_data__num_pieces 
763A D0 96 bne W75D2 
763C 8A txa 
763D 30 18 bmi W7657 
763F AD 1B D4 lda RANDOM Random numbers generator oscillator 3
7642 29 03 and #$03 
7644 8D 38 BD sta temp_data__num_pieces 
7647 EC 38 BD cpx temp_data__num_pieces 
764A 90 0B bcc W7657 
W764C:
764C BD 49 BE lda private.data__player_score_list,x 
764F CD 42 BF cmp private.data__curr_highest_move_score 
7652 F0 04 beq W7658 
7654 CA dex 
7655 10 F5 bpl W764C 
W7657:
7657 60 rts 
W7658:
7658 BD 25 BE lda private.data__player_piece_list,x 
765B 20 D9 79 jsr get_piece_position 
W765E:
765E 0E 3C BF asl temp_flag__adv_str 
7661 60 rts 




W7662:
7662 A9 40 lda #$40 
7664 8D 3C BF sta temp_flag__adv_str 
7667 AD 1B D4 lda RANDOM Random numbers generator oscillator 3
766A 29 03 and #$03 
766C D0 1A bne W7688 
766E AD C0 BC lda game_state_flag__ai_player_ctl 
7671 10 0B bpl W767E 
7673 A0 06 ldy #DJINNI 
7675 20 89 76 jsr W7689 
7678 A0 0A ldy #PHOENIX 
767A 20 89 76 jsr W7689 
767D 60 rts 

W767E:
767E A0 1D ldy #DRAGON 
7680 20 89 76 jsr W7689 
7683 A0 19 ldy #SHAPESHIFTER 
7685 20 89 76 jsr W7689 
W7688:
7688 60 rts 



W7689:
7689 B9 FD BD lda board_character_strength_data,y 
768C F0 26 beq W76B4 
768E 98 tya 
768F 20 D9 79 jsr get_piece_position 
7692 20 FF 62 jsr board_test_magic_square_selected 
7695 AD FE BC lda temp_data__curr_count 
7698 30 1A bmi W76B4 
769A AE 1A BF ldx idx__square_offset 
769D BD 5D 0B lda board.data__board_square_color_list,x 
76A0 30 0D bmi W76AF 
76A2 F0 06 beq W76AA 
76A4 AD C0 BC lda game_state_flag__ai_player_ctl 
76A7 10 06 bpl W76AF 
76A9 60 rts 

W76AA:
76AA AD C0 BC lda game_state_flag__ai_player_ctl 
76AD 10 05 bpl W76B4 
W76AF:
76AF 0E 3C BF asl temp_flag__adv_str 
76B2 68 pla 
76B3 68 pla 
W76B4:
76B4 60 rts 


W76B5:
76B5 A9 80 lda #$80 
76B7 8D 3C BF sta temp_flag__adv_str 
76BA A0 08 ldy #WIZARD 
76BC AD C0 BC lda game_state_flag__ai_player_ctl 
76BF 30 02 bmi W76C3 
76C1 A0 1B ldy #SORCERESS 
W76C3:
76C3 B9 FD BD lda board_character_strength_data,y 
76C6 F0 0D beq W76D5 
76C8 98 tya 
76C9 20 D9 79 jsr get_piece_position 
76CC 20 FF 62 jsr board_test_magic_square_selected 
76CF AD FE BC lda temp_data__curr_count 
76D2 8D 3C BF sta temp_flag__adv_str 
W76D5:
76D5 60 rts 




W747D:
747D A9 00 lda #$00 
747F 8D 38 BD sta temp_data__num_pieces 
7482 20 48 73 jsr W7348 
7485 AD 22 BF lda flag__selected_move 
7488 10 2B bpl W74B5 
748A AD 32 BD lda WBD32 
748D 8D 34 BD sta WBD34 
7490 4E 22 BF lsr flag__selected_move 
7493 20 48 73 jsr W7348 
7496 AD 22 BF lda flag__selected_move 
7499 10 06 bpl W74A1 
749B EE 3A BD inc temp_data__offset 
749E 4C A9 74 jmp W74A9 
W74A1:
74A1 20 48 73 jsr W7348 
74A4 AD 22 BF lda flag__selected_move 
74A7 10 0C bpl W74B5 
W74A9:
74A9 AD 32 BD lda WBD32 
74AC 8D 33 BD sta WBD33 
74AF 4E 22 BF lsr flag__selected_move 
74B2 20 48 73 jsr W7348 
W74B5:
74B5 60 rts 

W74B6:
74B6 A9 00 lda #$00 
74B8 8D 38 BD sta temp_data__num_pieces 
74BB 20 48 73 jsr W7348 
74BE AD 22 BF lda flag__selected_move 
74C1 10 06 bpl W74C9 
74C3 EE 3A BD inc temp_data__offset 
74C6 4C D1 74 jmp W74D1 
W74C9:
74C9 20 48 73 jsr W7348 
74CC AD 22 BF lda flag__selected_move 
74CF 10 25 bpl W74F6 
W74D1:
74D1 4E 22 BF lsr flag__selected_move 
74D4 AD 32 BD lda WBD32 
74D7 8D 34 BD sta WBD34 
74DA 20 48 73 jsr W7348 
74DD AD 22 BF lda flag__selected_move 
74E0 10 14 bpl W74F6 
74E2 4E 22 BF lsr flag__selected_move 
74E5 AD 32 BD lda WBD32 
74E8 8D 33 BD sta WBD33 
74EB 20 48 73 jsr W7348 
74EE AD 22 BF lda flag__selected_move 
74F1 30 03 bmi W74F6 
74F3 20 48 73 jsr W7348 
W74F6:
74F6 60 rts 


W74F7:
74F7 AD 2B BD lda param__piece_number_moves 
74FA C9 04 cmp #$04 
74FC B0 0B bcs W7509 
W74FE:
74FE AE 38 BD ldx temp_data__num_pieces 
7501 20 68 73 jsr W7368 
7504 CE 3B BD dec WBD3B 
7507 D0 F5 bne W74FE 
W7509:
7509 A9 00 lda #$00 
750B 8D 38 BD sta temp_data__num_pieces 
750E 20 48 73 jsr W7348 
7511 60 rts 


// ---

// 7282
// finds path from source square to destination square and create an array of moves
// requires: 
// - idx__selected_move
// - param__piece_number_moves
find_path_to_destination:
7282 AC 2E BD ldy idx__selected_move
7285 B9 37 BE lda data__player_square_idx_list,y
7288 8D 37 BD sta idx__selected_piece_square_offset
728B A0 09 ldy #$09
728D A9 00 lda #$00
W728F:
728F 18 clc
7290 6D 3B BF adc idx__selected_piece_destination_col
7293 88 dey
7294 D0 F9 bne W728F
7296 18 clc
7297 6D 3A BF adc idx__selected_piece_destination_row
729A 8D 36 BD sta WBD36
W729D:
729D A9 40 lda #(FLAG_ENABLE/2)
729F 8D 22 BF sta flag__selected_move
72A2 8D 3C BF sta temp_flag__adv_str
72A5 AD 36 BD lda WBD36
72A8 38 sec
72A9 ED 37 BD sbc idx__selected_piece_square_offset
72AC B0 07 bcs W72B5
72AE 49 FF eor #$FF
72B0 69 01 adc #$01
72B2 0E 3C BF asl temp_flag__adv_str
W72B5:
72B5 8D 39 BD sta WBD39
72B8 A0 11 ldy #$11
W72BA:
72BA D9 70 72 cmp W7270,y
72BD F0 12 beq W72D1
72BF 88 dey
72C0 10 F8 bpl W72BA
72C2 A9 00 lda #$00
72C4 8D 38 BD sta temp_data__num_pieces
72C7 AD 36 BD lda WBD36
72CA 8D 32 BD sta WBD32
72CD 0E 22 BF asl flag__selected_move
72D0 60 rts

W72D1:
72D1 B9 41 74 lda W7441,y
72D4 8D 38 BD sta temp_data__num_pieces
72D7 B9 53 74 lda W7453,y
72DA 8D 3B BD sta WBD3B
72DD B9 65 74 lda W7465,y
72E0 8D 3C BD sta WBD3C
72E3 B9 2F 74 lda W742F,y
72E6 2C 3C BF bit temp_flag__adv_str
72E9 70 03 bvs W72EE
72EB 18 clc
72EC 69 60 adc #$60
W72EE:
72EE 8D 3A BD sta temp_data__offset
72F1 AD 39 BD lda WBD39
72F4 C9 02 cmp #$02
72F6 D0 0E bne W7306
72F8 AD 2B BD lda param__piece_number_moves
72FB C9 04 cmp #$04
72FD 90 34 bcc W7333
72FF AD 3B BF lda idx__selected_piece_destination_col
7302 F0 16 beq W731A
7304 D0 10 bne W7316
W7306:
7306 C9 12 cmp #$12
7308 D0 1C bne W7326
730A AD 2B BD lda param__piece_number_moves
730D C9 04 cmp #$04
730F 90 22 bcc W7333
7311 AD 3A BF lda idx__selected_piece_destination_row
7314 F0 04 beq W731A
W7316:
7316 C9 08 cmp #$08
7318 D0 0C bne W7326
W731A:
731A AD 3A BD lda temp_data__offset
731D 18 clc
731E 69 06 adc #$06
7320 8D 3A BD sta temp_data__offset
7323 4C 33 73 jmp W7333

W7326:
7326 20 48 73 jsr W7348
7329 AD 22 BF lda flag__selected_move
732C 30 19 bmi W7347
732E CE 3B BD dec WBD3B
7331 D0 F3 bne W7326
W7333:
7333 AC 3C BD ldy WBD3C
7336 30 0F bmi W7347
7338 B9 77 74 lda W7477,y
733B 8D 30 BD sta ptr__check_ai_move
733E B9 78 74 lda W7477+1,y
7341 8D 31 BD sta ptr__check_ai_move+1
7344 6C 30 BD jmp (ptr__check_ai_move)

W7347:
7347 60 rts

W7348:
7348 AE 38 BD ldx temp_data__num_pieces
W734B:
734B AC 3A BD ldy temp_data__offset
734E AD 37 BD lda idx__selected_piece_square_offset
7351 18 clc
7352 79 6F 73 adc W736F,y
7355 9D 32 BD sta WBD32,x // moves (list of destination square indexes?
7358 A8 tay
7359 B9 7C BD lda board.data__square_occupancy_list,y
735C 10 0A bpl W7368
735E EE 3A BD inc temp_data__offset
7361 CA dex
7362 10 E7 bpl W734B
7364 0E 22 BF asl flag__selected_move
7367 60 rts

W7368:
7368 EE 3A BD inc temp_data__offset
736B CA dex
736C 10 FA bpl W7368
736E 60 rts


W7270:
	.byte $02, $03, $04, $06, $07, $08, $0A, $0B 
	.byte $0C, $10, $11, $12, $13, $14, $1A, $1B 
	.byte $1C, $24 

W742F:
	.byte $3E, $0A, $0A, $00, $4C, $5C, $5E, $50 
	.byte $0A, $28, $54, $45, $58, $33, $14, $1E 
	.byte $1E, $1E 

W7441:
	.byte $02, $01, $02, $02, $01, $00, $00, $01
	.byte $02, $02, $01, $02, $01, $02, $02, $01
	.byte $02, $02

W7453:
	.byte $02, $01, $01, $02, $02, $02, $02, $02
	.byte $02, $02, $02, $02, $02, $02, $02, $01
	.byte $02, $01

W7465:
	.byte $04, $FF, $FF, $00, $FF, $FF, $FF, $FF 
	.byte $00, $02, $FF, $04, $FF, $02, $00, $FF
	.byte $00, $FF



W7477:
	.word W747D, W74B6, W74F7



W736F:
	.byte $FF, $FE, $FD, $09, $08, $07, $FF, $FE 
	.byte $08, $07, $01, $02, $03, $09, $0A, $0B // Unusual operation
	.byte $01, $02 // Illegal instruction
	.byte $0A, $0B // Unusual operation
	.byte $09, $12 // Illegal instruction
	.byte $1B, $FF, $08, $11, $09, $08, $12 // Illegal instruction
	.byte $11, $09, $12 // Illegal instruction
	.byte $1B, $01, $0A, $13, $09, $0A, $12 // Illegal instruction
	.byte $13, $09, $12 // Illegal instruction
	.byte $11, $FF, $FE, $07, $FF, $09, $08, $07 
	.byte $11, $09, $12, $13, $01, $02 // Illegal instruction
	.byte $0B // Unusual operation
	.byte $09, $01, $0A, $0B // Unusual operation
	.byte $13, $F7, $F8, $F9, $09, $0A, $0B // Unusual operation
	.byte $01, $01, $0A, $13, $FF, $08, $11, $09 
	.byte $FF, $FE, $09, $08, $01, $02, $09, $0A 
	.byte $09, $12, $FF, $08, $09, $12 // Illegal instruction
	.byte $01, $0A, $FF, $09, $01, $09, $01, $02 // Illegal instruction
	.byte $03, $F7, $F8, $F9, $01, $02, $F8, $F9 
	.byte $FF, $FE, $FD, $F7, $F6, $F5, $FF, $FE 
	.byte $F6, $F5, $F7, $EE, $E5, $01, $F8, $EF 
	.byte $F7, $F8, $EE, $EF, $F7, $EE, $E5, $FF 
	.byte $F6, $ED, $F7, $F6, $EE, $ED, $F7, $EE 
	.byte $EF, $01, $02 // Illegal instruction
	.byte $F9, $F7, $01, $F8, $F9, $11, $FF, $FE 
	.byte $F5, $F7, $EE, $ED, $F7, $FF, $F6, $F5 
	.byte $ED, $F7, $F6, $F5, $09, $08, $07, $FF 
	.byte $01, $F8, $EF, $FF, $F6, $ED, $F7, $F7 
	.byte $F8, $01, $02, $F7, $F6, $FF, $FE, $F7 
	.byte $F8, $01, $F8, $F7, $EE, $FF, $F6, $F7 
	.byte $01, $F7 
	.byte $FF

 

 --------------------------------------------------------------------------------------------------------------

 select_piece:

82E5 AD FD BC lda game.data__icon_moves 
82E8 30 20 bmi W830A 
82EA AC 38 BD ldy temp_data__num_pieces // zzzzznumber of moves
82ED B9 32 BD lda WBD32,y  //zzzzz get square index for current move
// convert index to row/column of square
82F0 A0 00 ldy #$00 
W82F2:
82F2 38 sec 
82F3 E9 09 sbc #$09 
82F5 90 03 bcc W82FA 
82F7 C8 iny 
82F8 B0 F8 bcs W82F2 
W82FA:
82FA 69 09 adc #$09 
82FC A2 04 ldx #$04 
82FE 20 22 64 jsr board.convert_coord_sprite_pos 
8301 8D 17 BD sta data__sprite_curr_x_pos 
8304 8C 15 BD sty data__sprite_curr_y_pos 
8307 CE 38 BD dec temp_data__num_pieces 
W830A:
830A AE 22 BF ldx flag__selected_move // << move index
830D BD 5B BE lda data__player_destination_row_list,x 
8310 8D 28 BD sta idx__selected_piece_source_row 
8313 BC 6D BE ldy data__player_destination_col_list,x 
8316 8C 29 BD sty idx__selected_piece_source_col 
8319 AE FD BC ldx game.data__icon_moves 
831C 10 1A bpl !return 
831E A2 04 ldx #$04 
8320 20 22 64 jsr board.convert_coord_sprite_pos 
8323 2C FD BC bit game.data__icon_moves 
8326 50 0A bvc W8332 
// get selection square position
8328 38 sec 
8329 E9 02 sbc #$02 
832B 48 pha 
832C 98 tya 
832D 38 sec 
832E E9 01 sbc #$01 
8330 A8 tay 
8331 68 pla 
W8332:
8332 8D 17 BD sta data__sprite_curr_x_pos 
8335 8C 15 BD sty data__sprite_curr_y_pos
!return: 
rts



----------------------------------------------------------------------------------------------------------------


ai_board_cursor_to_piece:
8560 A9 20 lda #$20 
8562 8D FE BC sta temp_data__curr_count 
8565 AE 26 BD ldx temp_data__curr_sprite_ptr 
8568 BD 46 BD lda main_sprite_curr_y_pos,x 
856B CD 15 BD cmp data__sprite_curr_y_pos 
856E 90 13 bcc W8583 
8570 D0 06 bne W8578 
W8572:
8572 0E FE BC asl temp_data__curr_count 
8575 4C 8B 85 jmp W858B 
W8578:
8578 DE 46 BD dec main_sprite_curr_y_pos,x 
857B A9 08 lda #$08 
857D 8D EB BC sta game_icon_dir_frame_offset 
8580 4C 8B 85 jmp W858B 
W8583:
8583 FE 46 BD inc main_sprite_curr_y_pos,x 
8586 A9 04 lda #$04 
8588 8D EB BC sta game_icon_dir_frame_offset 
W858B:
858B BD 3E BD lda main_sprite_curr_x_pos,x 
858E CD 17 BD cmp data__sprite_curr_x_pos 
8591 90 13 bcc W85A6 
8593 D0 06 bne W859B 
8595 0E FE BC asl temp_data__curr_count 
8598 4C AE 85 jmp W85AE 
W859B:
859B DE 3E BD dec main_sprite_curr_x_pos,x 
859E A9 11 lda #$11 
85A0 8D EB BC sta game_icon_dir_frame_offset 
85A3 4C AE 85 jmp W85AE 
W85A6:
85A6 FE 3E BD inc main_sprite_curr_x_pos,x 
85A9 A9 00 lda #$00 
85AB 8D EB BC sta game_icon_dir_frame_offset 
W85AE:
85AE AD FE BC lda temp_data__curr_count 
85B1 30 06 bmi W85B9 
85B3 EE 0D BD inc flag__was_icon_moved 
85B6 4C 08 85 jmp W8508 
W85B9:
85B9 AD FD BC lda game.data__icon_moves 
85BC F0 49 beq W8607 
85BE 30 47 bmi W8607 
85C0 AC 38 BD ldy temp_data__num_pieces 
85C3 10 1C bpl W85E1 
85C5 AC 29 BD ldy idx__selected_piece_source_col 
85C8 CC 26 BF cpy temp_data__curr_board_row 
85CB D0 08 bne W85D5 
85CD AD 28 BD lda idx__selected_piece_source_row 
85D0 CD 28 BF cmp temp_data__curr_board_col 
85D3 F0 32 beq W8607 
W85D5:
85D5 8C 26 BF sty temp_data__curr_board_row 
85D8 AD 28 BD lda idx__selected_piece_source_row 
85DB 8D 28 BF sta temp_data__curr_board_col 
85DE 4C F0 85 jmp W85F0 
W85E1:
85E1 B9 32 BD lda WBD32,y 
85E4 A0 00 ldy #$00 
W85E6:
85E6 38 sec 
85E7 E9 09 sbc #$09 
85E9 90 03 bcc W85EE 
85EB C8 iny 
85EC B0 F8 bcs W85E6 
W85EE:
85EE 69 09 adc #$09 
W85F0:
85F0 A2 04 ldx #$04 
85F2 20 22 64 jsr board.convert_coord_sprite_pos 
85F5 8D 17 BD sta data__sprite_curr_x_pos 
85F8 8C 15 BD sty data__sprite_curr_y_pos 
85FB CE 38 BD dec temp_data__num_pieces 
85FE EE 0D BD inc flag__was_icon_moved 
8601 AE 26 BD ldx temp_data__curr_sprite_ptr 
8604 4C 08 85 jmp W8508 
W8607:
8607 AD 29 BD lda idx__selected_piece_source_col 
860A 8D 26 BF sta temp_data__curr_board_row 
860D AD 28 BD lda idx__selected_piece_source_row 
8610 8D 28 BF sta temp_data__curr_board_col 
8613 20 0D 87 jsr game_select_or_move_icon 
8616 A9 80 lda #$80 
8618 8D D0 BC sta main_state_flag_update_state 
861B 4C 8E 63 jmp common_complete_interrupt 
