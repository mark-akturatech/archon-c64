//---------------------------------------------------------------------------------------------------------------------
// Standard C64 memory and IO addresses using "MAPPING THE Commodore 64" constants names.
//---------------------------------------------------------------------------------------------------------------------
// Addresses use labels defined in http://unusedino.de/ec64/technical/project64/mapping_c64.html.
#importonce

//---------------------------------------------------------------------------------------------------------------------
// Video memory configuration

// Define video bank memory constants
.var videoBankCode = List().add(%11, %10, %01, %00).lock()
.var videoBankAddress = List().add($0000, $4000, $8000, $C000).lock()
.var videoBankGrphMemOffset = List().add($2000, $1000, $2000, $1000).lock()

// Set the video memory bank:
// Bank 0 - configuration: %11; memory offset: $0000
// Bank 1 - configuration: %10; memory offset: $4000
// Bank 2 - configuration: %01; memory offset: $8000
// Bank 3 - configuration: %00; memory offset: $C000
.const videoBank = 1;
.const VICBANK = videoBankCode.get(videoBank)
.const VICMEM = videoBankAddress.get(videoBank)
.const VICGOFF = videoBankGrphMemOffset.get(videoBank);

// Derive applications specific video bank constants
.const CHRMEM1 = VICMEM+$0000  // start of character set memory for intro (half set only)
.const CHRMEM2 = VICMEM+$0800  // start of character set memory for board (full set)
.const SCNMEM = VICMEM+$0400    // start of screen memory (overlaps bottom half CHRMEM1 as CHRMEM1 is a half set)
.const SPTMEM = SCNMEM+$03F8    // start of sprite location memory
.const GRPMEM = VICMEM+VICGOFF  // start of graphics/sprite memory

//---------------------------------------------------------------------------------------------------------------------
// Memory Addresses

// Processor
.const R6510    = $01   // Processort port
.const VARTAB   = $2D   // Used for zero page loops
.const ARYTAB   = $2F   // Used for zero page loops
.const STREND   = $31   // Used for zero page loops
.const CURLIN   = $39   // Used for zero page loops
.const OLDLIN   = $3B   // Used for zero page loops
.const OLDTXT   = $3D   // Used for zero page loops
.const DATLIN   = $3F   // Used for zero page loops
.const DATPTR   = $41   // Used for zero page loops
.const VARPNT   = $47   // Used for zero page loops
.const FORPNT   = $49   // Used for zero page loops
.const TIME     = $A0   // Software jiffy clock
.const LSTX     = $C5   // Matrix Coordinate of Last Key Pressed, 64=None Pressed
.const FREEZP   = $FB   // Four Free Bytes of Zero Page for User Programs
.const CINV     = $0314 // Vector to IRQ Interrupt Routine
.const CBINV    = $0316 // Vector: BRK Instruction Interrupt

// VIC
.const SP0X     = $D000 // Sprite 0 Horizontal Position
.const SP0Y     = $D001 // Sprite 0 Vertical Position
.const SP1X     = $D002 // Sprite 1 Horizontal Position
.const SP1Y     = $D003 // Sprite 1 Vertical Position
.const SP2X     = $D004 // Sprite 2 Horizontal Position
.const SP2Y     = $D005 // Sprite 2 Vertical Position
.const SP3X     = $D006 // Sprite 3 Horizontal Position
.const SP3Y     = $D007 // Sprite 3 Vertical Position
.const SP4X     = $D008 // Sprite 4 Horizontal Position
.const SP4Y     = $D009 // Sprite 4 Vertical Position
.const SP5X     = $D00A // Sprite 5 Horizontal Position
.const SP5Y     = $D00B // Sprite 5 Vertical Position
.const SP6X     = $D00C // Sprite 6 Horizontal Position
.const SP6Y     = $D00D // Sprite 6 Vertical Position
.const SP7X     = $D00E // Sprite 7 Horizontal Position
.const SP7Y     = $D00F // Sprite 7 Vertical Position
.const MSIGX    = $D010 // Most Significant Bits of Sprites 0-7 Horizontal Position
.const SCROLY   = $D011 // Vertical Fine Scrolling and Control Register
.const RASTER   = $D012 // Read Current Raster Scan Line/Write Line to Compare for Raster IRQ
.const SPENA    = $D015 // Sprite display enable
.const SCROLX   = $D016 // VIC Control Register 2
.const YXPAND   = $D017 // Sprite Vertical Expansion Register
.const VMCSB    = $D018 // VIC Memory Control Register
.const VICIRQ   = $D019 // VIC Interrupt Flag Register
.const IRQMASK  = $D01A // IRQ Mask Register
.const SPMC     = $D01C // Sprite multi-colour select
.const XXPAND   = $D01D // Sprite X horizontal expand
.const SPSPCL   = $D01E // Sprite to Sprite Collision Register
.const SPBGCL   = $D01F // Sprite to Foreground Collision Register
.const EXTCOL   = $D020 // Border Color Register
.const BGCOL0   = $D021 // Background Color 0
.const BGCOL1   = $D022 // Background Color 1
.const BGCOL2   = $D023 // Background Color 2
.const BGCOL3   = $D024 // Background Color 2
.const SPMC0    = $D025 // Sprite Multicolor Register 0
.const SPMC1    = $D026 // Sprite Multicolor Register 1
.const SP0COL   = $D027 // Sprite 0 Color Register
.const SP1COL   = $D028 // Sprite 1 Color Register
.const SP2COL   = $D029 // Sprite 2 Color Register
.const SP3COL   = $D02A // Sprite 3 Color Register
.const COLRAM   = $D800 // Start of Color RAM

// Joystick
.const CIAPRA   = $DC00 // CIA Port A register

// SID
.const FRELO1   = $D400 // Voice 1 Frequency Control (low byte)
.const FREHI1   = $D401 // Voice 1 Frequency Control (high byte)
.const PWHI1    = $D403 // Voice 1 Pulse Waveform Width (high nybble)
.const VCREG1   = $D404 // Voice 1 Control Register
.const FRELO2   = $D407 // Voice 2 Frequency Control (low byte)
.const FREHI2   = $D408 // Voice 2 Frequency Control (high byte)
.const PWHI2    = $D40A // Voice 2 Pulse Waveform Width (high nybble)
.const VCREG2   = $D40B // Voice 2 Control Register
.const FRELO3   = $D40E // Voice 3 Frequency Control (low byte)
.const FREHI3   = $D40F // Voice 3 Frequency Control (high byte)
.const PWHI3    = $D411 // Voice 3 Pulse Waveform Width (high nybble)
.const VCREG3   = $D412 // Voice 3 Control Register
.const SIGVOL   = $D418 // Volume and Filter Select Register
.const RANDOM   = $D41B // Read Oscillator 3/Random Number Generator

// CIA2
.const CI2PRA   = $DD00 // Port A access
.const C2DDRA   = $DD02 // Port A direction

// Kernel
.const STOP     = $FFE1 // Check the STOP key

