# Archon Terminology

The following terminology is used throughout the source code comments and memory location naming:

- `Icon`: An icon is a game piece, such as a Unicorn or Wizard.
- `Turn`: Archon is a turn based game. A player has a turn, the second player has a turn, the first player has another
  turn and so on.
- `Round`: A round is completed after both players have completed a single turn.
- `Light` and `Dark`: Archon comprises two sides. At the start of the game, light occupies the east of the board and
   dark, the right.
- `Pattern`: A pattern is a series of notes that can can be played or repeated to form music or sound effect.
- `Flag`: A flag is a memory location that is toggled between two (or more) states. Flags may be used to keep track
  of the current player turn, the selected AI side and so on. Often flags are toggled between a positive (0 to $7f) or
  negative ($80 to $ff) state however flags requiring more states may use different values (eg $00, $55, $aa, $ff for
  quad state) or ($00, $01, $80 for tri state). The values are generally chosen to test with the least number of
  operations. Eg `LDA FLAG; BEQ VALUE_IS_00; BPL VALUE_IS_01; BMI VALUE_IS_80`).
