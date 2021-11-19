//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// Application constants
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
#importonce

//---------------------------------------------------------------------------------------------------------------------
// Build control
//---------------------------------------------------------------------------------------------------------------------

#define INCLUDE_INTRO // comment to build the application without the introduction/title sequence

//---------------------------------------------------------------------------------------------------------------------
// Keyboard key constants
//---------------------------------------------------------------------------------------------------------------------

.const KEY_NONE = $40  // Matrix code returned from LSTX if no key pressed
.const KEY_F3 = $05 // F3 KEY
.const KEY_F5 = $06 // F5 KEY
.const KEY_F7 = $03 // F7 KEY
.const KEY_Q = $Bf // Q key

//---------------------------------------------------------------------------------------------------------------------
// Miscellaneous constants
//---------------------------------------------------------------------------------------------------------------------

// Bytes consumed by each sprite
.const BYTES_PER_SPRITE = 64;

// Characters per screen row
.const CHARS_PER_SCREEN_ROW = 40;

// Flag constants
.const FLAG_DISABLE = $00; // Off
.const FLAG_ENABLE = $80; // Enabled

//---------------------------------------------------------------------------------------------------------------------
// Character piece constants
//---------------------------------------------------------------------------------------------------------------------

// Character piece type IDs.
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

// Character piece offset.
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

//---------------------------------------------------------------------------------------------------------------------
// Sound constants
//---------------------------------------------------------------------------------------------------------------------

.const SOUND_CMD_NO_NOTE = $00    // Stop note
.const SOUND_CMD_SET_DELAY = $FB    // Set delay
.const SOUND_CMD_RELEASE_NOTE = $FC // Immediate release
.const SOUND_CMD_NEXT_STATE = $FD   // End state - used to trigger code at points in the music
.const SOUND_CMD_NEXT_PHRASE = $FE  // Go to next phrase (or repeat current phrase)
.const SOUND_CMD_END = $FF          // End phrase and turn off voice

//---------------------------------------------------------------------------------------------------------------------
// String constants
//---------------------------------------------------------------------------------------------------------------------

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
.const STRING_SUMMON_ELEMENTAAL = 48
.const STRING_REVIVE = 49
.const STRING_IMPROSON = 50
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
// Game constants
//---------------------------------------------------------------------------------------------------------------------

.const BOARD_NUM_COLS = 9
.const BOARD_NUM_ROWS = 9
.const BOARD_NUM_PIECES = BOARD_NUM_COLS * 2 * 2 // Each side has 2 columns full of pieces
