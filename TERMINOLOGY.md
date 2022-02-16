# Archon Terminology

The following terminology is used throughout the source code comments and memory location naming:

- `Icon`: An icon is a game piece, such as a Unicorn or Wizard.
- `Turn`: Archon is a turn based game. A player has a turn, the second player has a turn, the first player has another turn and so on.
- `Round`: A round is completed after both players have completed a single turn.
- `Light` and `Dark`: Archon comprises two sides. At the start of the game, light occupies the left of the board and dark, the right.
- `Pattern`: A pattern is a series of notes that can can be played or repeated to form music or sound effect.
- `Flag`: A flag is a memory location that is toggled between two (or more) states. Flags may be used to keep track of the current player turn, the selected AI side and so on. Often flags are toggled between a positive (0 to $7f) or negative ($80 to $ff) state however flags requiring more states may use different values (eg $00, $55, $aa, $ff for quad state) or ($00, $01, $80 for tri state). The values are generally chosen to test with the least number of operations. Eg `LDA FLAG; BEQ VALUE_IS_00; BPL VALUE_IS_01; BMI VALUE_IS_80`).
- `Intro`: Refers to the initial introduction animation displayed when the game first loads. This also includes the 'walk-on' where each piece walks on to the board before the options are displayed.
- `Board`: The chess board like game-play area of the game.
- `Square`: A single cell on the board. A sqaure can be occupied by a player and a square is challenged and the pieces enter the arena if two icons occupy the same square.
- `Game`: Actual game play on the game 'board'.
- `Challenge`: When two icons occupy the same square, they will initiate a challenge. The challenge will result in both icons being placed within the battle arena.
- `Arena`: Battle game played off-board to battle for a sqaure.
- `Attack`: An action made by an icon in the 'Arena' to attempt to kill the other icon. Eg firing a projectile or swinging a weaopn.
- `Projectile`: Refers to the animation or sprite used to inflict damage on the opponent during an attack. The word projectile isnt completely accurate though as knights and goblins don't throw the projectile. Banshees and Phoenix also surround themselves with their weapon. However for simplicity, as most icons do throw a projectile, we will use this term in all cases.
- `Strength`: The number of hit points an icon has. Hit points are reduced by each successful attack. The icon is killed when strength is 0 or less.
