.filenamespace resources
//---------------------------------------------------------------------------------------------------------------------
// Contains sound effect patterns used the icons for moving and attacking and gameplay after each turn.
//---------------------------------------------------------------------------------------------------------------------

// A15E
// See comment on `common.play_music` for details on how sound patterns are interpreted.
snd__effect_walk_large:
    .byte SOUND_CMD_NO_NOTE, $08, $34, SOUND_CMD_NO_NOTE, $20, $03, $81, SOUND_CMD_NO_NOTE, $08, $34
    .byte SOUND_CMD_NO_NOTE, $20, $01, $81
    .byte SOUND_CMD_NEXT_PATTERN
snd__effect_fly_01:
    .byte SOUND_CMD_NO_NOTE, $04, SOUND_CMD_NO_NOTE, $40, $60, $08, $81, $04, SOUND_CMD_NO_NOTE, $40, $60
    .byte $0A, $81
    .byte SOUND_CMD_NEXT_PATTERN
snd__effect_fly_02:
    .byte SOUND_CMD_NO_NOTE, $08, $70, SOUND_CMD_NO_NOTE, $E2, $04, $21, $08, SOUND_CMD_NO_NOTE
    .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
    .byte SOUND_CMD_NEXT_PATTERN
snd__effect_walk_slither:
    .byte SOUND_CMD_NO_NOTE, $08, $70, SOUND_CMD_NO_NOTE, $C0, $07, $21, $08, $70, SOUND_CMD_NO_NOTE, $C0, $07
    .byte SOUND_CMD_NO_NOTE
    .byte SOUND_CMD_NEXT_PATTERN
snd__effect_walk_quad:
    .byte $04, $01, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $02, $81, SOUND_CMD_NO_NOTE, $04, $01
    .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $03, $81, SOUND_CMD_NO_NOTE, $04, $01, SOUND_CMD_NO_NOTE
    .byte SOUND_CMD_NO_NOTE, $04, $81, SOUND_CMD_NO_NOTE, $04, $01, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
    .byte SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE
    .byte SOUND_CMD_NEXT_PATTERN
snd__effect_fly_03:
    .byte SOUND_CMD_NO_NOTE, $04, $12, SOUND_CMD_NO_NOTE, $20, $03, $81, $04, $12, SOUND_CMD_NO_NOTE, $20, $03
    .byte SOUND_CMD_NO_NOTE, $04, $12, SOUND_CMD_NO_NOTE, $20, $02, $81, $04, $12, SOUND_CMD_NO_NOTE, $20, $02
    .byte SOUND_CMD_NO_NOTE
    .byte SOUND_CMD_NEXT_PATTERN
snd__effect_attack_03:
    .byte SOUND_CMD_NO_NOTE, $32, $A9, SOUND_CMD_NO_NOTE, $EF, $31, $81, SOUND_CMD_END
snd__effect_hit_player_dark:
    .byte SOUND_CMD_NO_NOTE, $12, $08, SOUND_CMD_NO_NOTE, $C4, $07, $41, SOUND_CMD_END
snd__effect_hit_player_light:
    .byte SOUND_CMD_NO_NOTE, $12, $08, SOUND_CMD_NO_NOTE, $D0, $3B, $43, SOUND_CMD_END
snd__effect_attack_04:
    .byte SOUND_CMD_NO_NOTE, $28, $99, SOUND_CMD_NO_NOTE, $6A, $6A, $21, SOUND_CMD_END
snd__effect_fly_large:
    .byte SOUND_CMD_NO_NOTE, $10, $84, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $06, $81
    .byte SOUND_CMD_NEXT_PATTERN
snd__effect_attack_01:
    .byte SOUND_CMD_NO_NOTE, $80, $4B, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $21, $81, SOUND_CMD_END
snd__effect_attack_02:
    .byte SOUND_CMD_NO_NOTE, $10, $86, SOUND_CMD_NO_NOTE, $F0, $F0, $81, SOUND_CMD_END
snd__effect_player_light_turn:
    .byte SOUND_CMD_NO_NOTE, $1E, $09, SOUND_CMD_NO_NOTE, $3E, $2A, $11, SOUND_CMD_END
snd__effect_player_dark_turn:
    .byte SOUND_CMD_NO_NOTE, $1E, $09, SOUND_CMD_NO_NOTE, $1F, $16, $11, SOUND_CMD_END
snd__effect_transport:
    .byte SOUND_CMD_NO_NOTE, $80, $03, SOUND_CMD_NO_NOTE, SOUND_CMD_NO_NOTE, $23, $11, SOUND_CMD_END
