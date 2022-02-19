.filenamespace resources
//---------------------------------------------------------------------------------------------------------------------
// Contains text strings used in the intro.
//---------------------------------------------------------------------------------------------------------------------

// A8C3
// A .... Game
txt__intro_3:
    .byte $10, $13 // Start on row $10 column $13
    .text "A"
    .byte STRING_CMD_NEWLINE, $18, $11
    .text "GAME"
    .byte STRING_CMD_END

// A87F
// Top half of "Free Fall" logo.
txt__intro_4:
    .byte $0b
    .byte $64, $65, $68, $69, $6c, $6d, $6c, $6d, $00, $64, $65, $60, $61, $70, $71, $70, $71
    .byte STRING_CMD_END

// A892
// Bottom half of "Free Fall" logo.
txt__intro_5:
    .byte $0b // Start on column $0b. Row is supplied in logic as string is repeated on multiple rows.
    .byte $66, $67, $6a, $6b, $6e, $6f, $6e, $6f, $00, $66, $67, $62, $63, $72, $73, $72, $73
    .byte STRING_CMD_END

// A8CE
// By Anne Wesfall and Jon Freeman & Paul Reiche III
txt__intro_0:
    .byte $08, $0c // Start on row $08 column $0c
    .text @"BY\$00ANNE\$00WESTFALL"
    .byte STRING_CMD_NEWLINE, $0a, $0b // Move to row $0a column $0b
    .text @"AND\$00JON\$00FREEMAN"
    .byte STRING_CMD_NEWLINE, $0c, $0d // Move to row $0c column $0d
    .text @"\$40\$00PAUL\$00REICHE\$00III"
    .byte STRING_CMD_END

// A907
// Emptry string under authors - presumably here to allow text to be added for test versions etc
txt__intro_1:
    .byte $0f, $01 // Start on row $0f column $01
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00
    .byte STRING_CMD_END

// A931
// Electronic Arts Logo
txt__intro_2:
    .byte $12, $01 // Start on row $12 column $01
    .byte $16, $17, $17, $18, $19, $1a, $1b, $1c
    .byte STRING_CMD_NEWLINE, $13, $01 // Move to row $13 column $01
    .byte $1e, $1f, $1f, $20, $1f, $1f, $21, $22, $23
    .byte STRING_CMD_NEWLINE, $14, $01 // Move to row $14 column $01
    .byte $24, $25, $25, $26, $27, $28, $29, $2a, $3f, $1d
    .byte STRING_CMD_NEWLINE, $15, $01 // Move to row $15 column $01
    .byte $2b, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2d, $2e
    .byte STRING_CMD_NEWLINE, $16, $01 // Move to row $16 column $01
    .byte $2f, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e
    .byte STRING_CMD_END