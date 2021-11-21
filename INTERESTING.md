# Archon Interesting Discoveries

## Intro

- Press `Q` will jump straight to options settings page (skips icon walk on).
- Press `F3`, `F5` - will jump straight to options settings page and select that option.
- Press `F7` will immediately start the game with default options (2 player, light first).
- Memory address `$A907` has 40 empty characters (`$00`) that are displayed under the author's names. This can be
  easily modified to display any message you want (up to one line long).
- The intro page has it's own character set (although only half a set). It is used to drag EA and Free fall logos.
- The music played during the into has special commands that cause the intro to advance to a different state at
  certain points in the music (eg animate the logo or display chase scene etc).

## Sprites

- Sprites are smaller than usual - 54 bytes instead of 64. This is because only 54 bytes are needed to render a
  sprite big enough to fit within a board square. It also uses less memory.
- Each icon is made up of 15 sprites (except shapeshifter). Each direction (right, up, down) comprises 4 sprites
  making up animation frames for walking/flying etc, 1 for shoot up, 2 animation frames for shoot right and 1 for
  shoot left.
- Note that there are no sprites for left direction - the sprite copy algoritm takes a parameter that allows the
  sprite to be horizontally mirrored on copy, thus providing left direction sprites.
- The shapeshifter only uses 10 sprites as it doesnt need any sprites for battle.
- The "ARCHON" sprite at the top of the baord during gameplay is dynamically created using the character set dot data
  for each letter. Change address `$9274` to any 6 letters to display any string you like.

## Game play

- Press `Q` will quit the current game and return back to the options setting page.
- The initial strength of each icon is shown below (address `$8AB3`):
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB, AE, FE, EE, WE
  09, 10, 05, 15, 08, 15, 12, 05, 06, 10, 08, 14, 10, 17, 08, 05, 12, 10, 17, 14
  ```
  The addresses can be modifed without any issues.
- The number of moves of each icon is shown below (address `$8AC7`):
  ```
  UC, WZ, AR, GM, VK, DJ, PH, KN, BK, SR, MC, TL, SS, DG, BS, GB
  04, c3, 03, 03, 83, 84, 85, 03, 03, c3, 03, 03, 85, 84, 83, 03
  ```
  +$80 is added if icon can fly; +$40 is added if icon can cast spells (if $c0 means can fly and cast).
- Icons regenerate 1 lost hit point when on strogest board color (eg light on white and dark on black).
- Icons on magic squares regenerate 1 lost hitpoint after each round.
- It looks like the game was initially designed to have two additional colors in the board phases, but logic was
  introduced to skip two of them (in brackets below)...
  ```
  BLACK, BLUE, (RED), PURPLE, GREEN, (YELLOW), CYAN, WHITE
  ```
  The additional colors can be enabled by writing a `$00` to addresses `$6599` and `$65D0`.
- You can draw a game if the last two icons battle and both kill each other in battle.
- You can stalemate a game if both players have 3 or less icons and a battle hasn't occured within 12 rounds.
- Address `$8AFF` contains each initial icon for light and dark players. The icons are ordered light row 1, light
  row 2, etc and then dark row 1, dark row 2. So is VALKYRIE, ARCHER, GOLUM, KNIGHT, UNICORN, KNIGHT etc. The addresses
  use the icon offset. You can change these without any consequence. Eg modify so you have unicorns instead of
  Knights or 5 Golumns.
