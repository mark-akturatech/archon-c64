//---------------------------------------------------------------------------------------------------------------------
// Game specific constants.
//---------------------------------------------------------------------------------------------------------------------
#importonce

//---------------------------------------------------------------------------------------------------------------------
// Keyboard key constants.

.const KEY_NONE = $40  // Matrix code returned from LSTX if no key pressed
.const KEY_F3 = $05 // F3 KEY
.const KEY_F5 = $06 // F5 KEY
.const KEY_F7 = $03 // F7 KEY
.const KEY_Q = $Bf // Q key

//---------------------------------------------------------------------------------------------------------------------
// Miscellaneous constants.

// Sprite constants.
.const BYTES_PER_SPRITE = 64; // Bytes consumed by each sprite
.const BYTERS_PER_ICON_SPRITE = 54; // Stored icon sprites are not full height and therefore consume less memory.
.const BYTERS_PER_PROJECTILE_SPRITE = 8; // Projectile sprites are tiny and monochromatic.
// Address VICMEM+15*BYTES_PER_SPRITE contains a contiguous 64 bytes of 0's athat can be used as a blank sprite.
.const EMPTY_SPRITE_BLOCK = 15

// Text screen constants.
.const NUM_SCREEN_COLUMNS = 40; // $28
.const NUM_SCREEN_ROWS = 25; // $19

// Flag constants.
.const FLAG_DISABLE = $00; // Off
.const FLAG_ENABLE = $80; // Enabled
.const FLAG_ENABLE_FF = $FF // Some logic uses FF for Enabled. Shouldn't as $80 will work fine.

// Player fot data color flags.
.const NUM_PLAYERS = 2 // Total bumber of players
.const PLAYER_LIGHT_COLOR_STATE = $55 // Value loaded in to character dot data to represent character color 1
.const PLAYER_DARK_COLOR_STATE = $AA // Value loaded in to character dot data to represent character color 2

// Phase cycle constants.
.const PHASE_LENGTH = 7 // Number of color phases
.const PHASE_MIDDLE = floor(PHASE_LENGTH/2) // Middle phase (used as the intial phase at the start of the game)
.const PHASE_CYCLE_LENGTH = PHASE_LENGTH*2 // Length of colour cycle (7 colors forward, then 7 colors in reverse)

// Time constants.
.const JIFFIES_PER_SECOND = 64 // Approximate number of jiffies per second.

//---------------------------------------------------------------------------------------------------------------------
// Icon constants.

// Icon type IDs.
.const VALKYRIE = $00
.const ARCHER = $01
.const GOLEM = $02
.const KNIGHT = $03
.const UNICORN = $04
.const DJINNI = $06
.const WIZARD = $08
.const PHOENIX = $0A
.const MANTICORE = $12
.const BANSHEE = $13
.const GOBLIN = $14
.const TROLL = $15
.const BASILISK = $17
.const SHAPESHIFTER = $19
.const SORCERESS = $1B
.const DRAGON = $1D
.const AIR_ELEMENTAL = $24
.const FIRE_ELEMENTAL = $25
.const EARTH_ELEMENTAL = $26
.const WATER_ELEMENTAL = $27

// Character icon offset.
// Offsets are used to determine the correct sprite set and character dot data.
.const VALKYRIE_OFFSET = $04
.const ARCHER_OFFSET = $02
.const GOLEM_OFFSET = $03
.const KNIGHT_OFFSET = $07
.const UNICORN_OFFSET = $00
.const DJINNI_OFFSET = $05
.const WIZARD_OFFSET = $01
.const PHOENIX_OFFSET = $06
.const MANTICORE_OFFSET = $0A
.const BANSHEE_OFFSET = $0E
.const GOBLIN_OFFSET = $0F
.const TROLL_OFFSET = $0B
.const BASILISK_OFFSET = $08
.const SHAPESHIFTER_OFFSET = $0C
.const SORCERESS_OFFSET = $09
.const DRAGON_OFFSET = $0D
.const AIR_ELEMENTAL_OFFSET = $10
.const FIRE_ELEMENTAL_OFFSET = $11
.const EARTH_ELEMENTAL_OFFSET = $12
.const WATER_ELEMENTAL_OFFSET = $13

// Miscellaneous icon constants.
.const NUM_ICON_TYPES = 16 // Total number of different types of icons
.const ICON_CAN_FLY = $80
.const ICON_CAN_CAST = $40
.const ICON_CAN_THRUST = $20 // Icon attack is a local sword or club attack
.const ICON_CAN_TRANSFORM = $40 // Icon attack is a surround attack (scream/fire)
.const ICON_SLOW_SPEED = $40 // Speed of slow icons (like Golem or Earth Elemental)

//---------------------------------------------------------------------------------------------------------------------
// Sound constants.

.const NUM_VOICES = 3 // Total number of voices available on the SID
.const SOUND_CMD_NO_NOTE = $00 // Stop note
.const SOUND_CMD_SET_DELAY = $FB // Set delay
.const SOUND_CMD_RELEASE_NOTE = $FC // Immediate release
.const SOUND_CMD_NEXT_STATE = $FD // End state - used to trigger code at points in the music
.const SOUND_CMD_NEXT_PATTERN = $FE // Go to next pattern (or repeat current pattern)
.const SOUND_CMD_END = $FF // End pattern and turn off voice

//---------------------------------------------------------------------------------------------------------------------
// String constants.

.const STRING_CMD_END = $FF         // End of string
.const STRING_CMD_NEWLINE = $80     // New line (row and column offset follow)

.const STRING_NO_SPELLS = 00
.const STRING_CANNOT_MOVE = 01
.const STRING_CHALLENGE_FOE = 02
.const STRING_LIMIT_MOVED = 03
.const STRING_SQUARE_OCCUPIED = 04
.const STRING_SPELL_DONE = 05
.const STRING_LIGHT_WINS = 06
.const STRING_DARK_WINS = 07
.const STRING_TIE = 08
.const STRING_REVERED_TIME = 09
.const STRING_HEAL_WHICH = 10
.const STRING_TELEPORT_WHICH = 11
.const STRING_TELEPORT_WHERE = 12
.const STRING_TRANSPOSE_WHICH = 13
.const STRING_EXCHANGE_WHICH = 14
.const STRING_REVIVE_WHICH = 15
.const STRING_CHARMED_WHERE = 16
.const STRING_IMPRISON_WHICH = 17
.const STRING_NO_CHARMED = 18
.const STRING_ICONS_ALL_ALIVE = 19
.const STRING_ICON_IMPRISONED = 20
.const STRING_AIR = 21
.const STRING_FIRE = 22
.const STRING_WATER = 23
.const STRING_EARTH = 24
.const STRING_SEND_WHERE = 25
.const STRING_WIZARD = 26
.const STRING_SOURCERESS = 27
.const STRING_TELEPORT = 44
.const STRING_HEAL = 45
.const STRING_SHIFT_TIME = 46
.const STRING_EXCHANGE = 47
.const STRING_SUMMON_ELEMENTAL = 48
.const STRING_REVIVE = 49
.const STRING_IMPRISON = 50
.const STRING_CEASE = 51
.const STRING_CHARMED_PROOF = 52
.const STRING_SPELL_WASTED = 53
.const STRING_SELECT_SPELL = 54
.const STRING_COMPUTER = 55
.const STRING_LIGHT = 56
.const STRING_TWO_PLAYER = 57
.const STRING_FIRST = 58
.const STRING_DARK = 59
.const STRING_READY = 60
.const STRING_PRESS = 61
.const STRING_SPELL_CANCELED = 62
.const STRING_GAME_ENDED = 63
.const STRING_STALEMATE = 64
.const STRING_ELEMENT_APPEARS = 65
.const STRING_SPELL_CONJURED = 66
.const STRING_PRESS_RUN = 67
.const STRING_F7 = 68
.const STRING_F5 = 69
.const STRING_F3 = 70

//---------------------------------------------------------------------------------------------------------------------
// Board constants.

.const BOARD_NUM_COLS = 9
.const BOARD_NUM_ROWS = 9
.const BOARD_SIZE = BOARD_NUM_COLS*BOARD_NUM_ROWS
.const BOARD_NUM_PLAYER_PIECES = BOARD_NUM_COLS*2
.const BOARD_TOTAL_NUM_PIECES = BOARD_NUM_PLAYER_PIECES*2
.const BOARD_NUM_MAGIC_SQUARES = 5
.const BOARD_EMPTY_SQUARE = FLAG_ENABLE
.const BOARD_DARK_SQUARE = $00
.const BOARD_LIGHT_SQUARE = $60
.const BOARD_VARY_SQUARE = $E0

//---------------------------------------------------------------------------------------------------------------------
// Spell constants.

.const NUM_SPELLS = 7
.const SPELL_UNUSED = $FD
.const SPELL_USED = $FE
.const DEAD_ICON_SLOT_UNUSED = $FF

.const SPELL_ID_TELEPORT = $00
.const SPELL_ID_HEAL = $01
.const SPELL_ID_SHIFT_TIME = $02
.const SPELL_ID_EXCHANGE = $03
.const SPELL_ID_SUMMON_ELEMENTAL = $04
.const SPELL_ID_REVIVE = $05
.const SPELL_ID_IMPRISON = $06
.const SPELL_ID_CEASE = $07

.const ACTION_SELECT_ICON = $80
.const ACTION_SELECT_SQUARE = $81
.const ACTION_SELECT_PLAYER_ICON = $82
.const ACTION_SELECT_CHALLENGE_ICON = $83
.const ACTION_SELECT_CHARMED_SQUARE = $84
.const ACTION_SELECT_OPPOSING_ICON = $85
.const ACTION_SELECT_FREE_PLAYER_ICON = $86
.const ACTION_SELECT_REVIVE_ICON = $87

//---------------------------------------------------------------------------------------------------------------------
// Challenge constants.

.const NUM_BARRIER_TYPES = 3
.const NUMBER_CHALLENGE_SPRITES = 4; // 2 player icos + 2 projectiles
