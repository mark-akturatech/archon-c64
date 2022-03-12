# Archon Interesting Discoveries

## Intro

- Press `Q` will jump straight to options settings (skips icon walk on).
- Press `F3`, `F5` - will jump straight to options settings and select that option.
- Press `F7` will immediately start the game with default options (2 player, light first).
- Memory address `$A907` has 40 empty characters (`$00`) that are displayed under the author's names. One some screenshots of Archon this text contains a copywrite message "COPYRIGHT (C) 1983 FREE FALL ASSOCIATES" but this has been removed in my copy of the source.
- The intro has it's own character set (although only half a set). It is used to draw the EA and Free fall logos.
- The music played during the into has special commands that cause the intro to advance to a different state at certain points in the music (eg animate the logo or display chase scene etc).

## Sprites

- Sprites are smaller than usual - 54 bytes instead of 64. This is because only 54 bytes are needed to render a sprite big enough to fit within a square. It also uses less memory.
- There are a lot of sprites. Each icon has several animation frames for each direction, the attack weapon/projectile and the attack stance.
- Each icon is made up of 15 sprites (except shapeshifter). Each direction (east, north, south) comprises 4 sprites making up animation frames for walking/flying etc, and attack frames for north, south, east, north east and south east.
- Note that there are no sprites for west direction - the sprite copy algorithm takes a parameter that allows the sprite to be horizontally mirrored on copy, thus providing west direction sprites.
- The shapeshifter only uses 10 sprites as it doesn't need any sprites for a challenge battle.
- The "ARCHON" sprite at the top of the board during gameplay is dynamically created using the character set dot data for each letter. Change address `$9274` to any 6 letters to display any string you like and it'll be displayed at the top of the board.

## Game play

- Press `Q` will quit the current game and return back to the options setting.
- The number of moves of each icon is shown below (address `$8AC7`):
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB
  04, C3, 03, 03, 83, 84, 85, 03, 03, C3, 03, 03, 85, 84, 83, 03
  ```
  +$80 is added if icon can fly (ie jump over other icons); +$40 is added if icon can cast spells (if $C0 means can fly and cast).
  The addresses can be modified however it cannot be increased above 5 as it will cause a buffer overrun.
  Interestingly, you can add flying and spell casting to any character you want. So change a sworder to $C5 and all sworders can now move 5 squares, cast spells (although there is only one spell usage table) and fly.
- Icons regenerate 1 lost hit point per round when on strongest board color (eg light on white and dark on black).
- Icons on magic squares regenerate 1 lost hit point after each round.
- It looks like the game was initially designed to have two additional colors in the board phases, but logic was introduced to skip two of them (in brackets below)...
  ```
  BLACK, BLUE, (RED), PURPLE, GREEN, (YELLOW), CYAN, WHITE
  ```
  The additional colors can be enabled by writing a `$00` to addresses `$6599` and `$65D0`.
- You can draw a game if the last two icons challenge and both kill each other in battle.
- You can stalemate a game if both players have 3 or less icons and a challenge hasn't occurred within 12 rounds.
- Address `$8AFF` contains each initial icon for light and dark players. The icons are ordered light row 1, light row 2, etc and then dark row 1, dark row 2. So is VALKYRIE, ARCHER, GOLUM, KNIGHT, UNICORN, KNIGHT etc.
The addresses use the icon offset. You can change these without any consequence. Eg modify so you have unicorns instead of Knights or 5 Golemns.
  The icon offsets are defined below:
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB
  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 0A, 0B, 0C, 0D, 0E, 0F
  ```
- The outro music (music played after the game has finished) just plays the first and last last pattern of the intro music.

## Battle Arena

- The initial strength of each icon is shown below (address `$8AB3`):
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
  09, 0A, 05, 0F, 08, 0F, 0C, 05, 06, 0A, 08, 0E, 0A, 11, 08, 05, 0C, 0A, 11, 0E
  ```
  The addresses can be modified however values above $11 can cause display issues.
- The damage caused by each icon is shown below (address `$8A9F`):
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
  07, 0A, 05, 0A, 07, 06, 02, 05, 09, 08, 04, 0A, 00, 0B, 01, 05, 05, 09, 09, 06
  ```
  $00 is for shapeshifter as it inherits opponent damage.
  The addresses can be modified without issue up to $FF.
- The speed of an icon's projectile is shown below (address `$8A8B`):
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
  07, 05, 04, 03, 03, 04, 40, 20, 07, 06, 03, 03, 00, 04, 40, 20, 04, 05, 03, 03
  ```
  $20 is a non projectile directional weapon; $40 is a non projectile non-directional weapon; $01-$07 is the speed of a projectile
  $00 is for shapeshifter as it inherits opponent speed.
  The addresses can be modified however high projectile speeds may skip too many pixels during each frame and the projectile could jump over the opponent.
  This is a fun table to play with. You can modify a knight for example by changing to $0F and now the knight can throw it's sword really fast.
- The icon attack recovery speed is shown below (address `$8AD7`):
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
  3C, 50, 50, 64, 50, 5A, 64, 28, 3C, 50, 50, 64, 00, 78, 64, 28, 46, 3C, 64, 64
  ```
  The speed is the count of jiffies (1/60th second) to wait before the icon can attack again.
  The value can be changed without issue, however the wait time should be longer than it takes to fire across the screen.
  Setting a Knight to 01 makes it a pretty tough opponent.
- Shape Shifters will assume the initial strength of the icon they are fighting. This means they don't really need to heal and have an advantage over pieces with damage. However, if a Shape Shifter challenges an elemental, the Shape Shifter will have a strength of 10, which is less than most elementals.
- Pieces will receive an negative strength adjustment when defending the caster magic square based on the number of spells already cast by the spell caster. The caster magic square is the square that the spell caster initially starts the game on. I think the idea here is that the spell caster weakens the square as they cast spells, making the square harder to defend.
## Notes

The following acronyms are used in the above tables:
 - UN=Unicorn, WZ=Wizard, AR=Archer, GM=Golem, VK=Valkyrie, DJ=Djinni, PH=Phoenix, KN=Knight, BK=Basilisk, SR=Sourceress, MC=Manticore, TL=Troll, SS=Shape Shifter, DG=Dragon, BS=Banshee, GB=Goblin, AE=Air Elemental, FE=Fire Elemental, EE=Earth Elemental, WE=Water Elemental
