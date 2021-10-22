//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// C64 I/O and memory constants
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
#importonce

// Processor
.const R6510    = $01   // Processort port
.const VARTAB   = $2D   // Used for zero page loops
.const ARYTAB   = $2F   // Used for zero page loops
.const STREND   = $31   // Used for zero page loops
.const OLDTXT   = $3D   // Used for zero page loops
.const DATLIN   = $3F   // Used for zero page loops
.const DATPTR   = $41   // Used for zero page loops
.const FORPNT   = $49   // Used for zero page loops
.const LSTX     = $C5   // Matrix Coordinate of Last Key Pressed, 64=None Pressed
.const FREEZP   = $FB   // Four Free Bytes of Zero Page for User Programs
.const CINV     = $0314 // Vector to IRQ Interrupt Routine
.const CBINV    = $0316 // Vector: BRK Instruction Interrupt

// VIC
.const  SP0X    = $D000 // Sprite 0 Horizontal Position
.const  SP0Y    = $D001 // Sprite 0 Vertical Position
.const  SP1X    = $D002 // Sprite 1 Horizontal Position
.const  SP1Y    = $D003 // Sprite 1 Vertical Position
.const  SP2X    = $D004 // Sprite 2 Horizontal Position
.const  SP2Y    = $D005 // Sprite 2 Vertical Position
.const  SP3X    = $D006 // Sprite 3 Horizontal Position
.const  SP3Y    = $D007 // Sprite 3 Vertical Position
.const  SP4X    = $D008 // Sprite 4 Horizontal Position
.const  SP4Y    = $D009 // Sprite 4 Vertical Position
.const  SP5X    = $D00A // Sprite 5 Horizontal Position
.const  SP5Y    = $D00B // Sprite 5 Vertical Position
.const  SP6X    = $D00C // Sprite 6 Horizontal Position
.const  SP6Y    = $D00D // Sprite 6 Vertical Position
.const  SP7X    = $D00E // Sprite 7 Horizontal Position
.const  SP7Y    = $D00F // Sprite 7 Vertical Position
.const  MSIGX   = $D010 // Most Significant Bits of Sprites 0-7 Horizontal Position
.const  SCROLY  = $D011 // Vertical Fine Scrolling and Control Register
.const  RASTER  = $D012 // Read Current Raster Scan Line/Write Line to Compare for Raster IRQ
.const  SPENA   = $D015 // Sprite display enable
.const  SCROLX  = $D016 // VIC Control Register 2
.const  VMCSB   = $D018 // VIC Memory Control Register
.const  VICIRQ  = $D019 // VIC Interrupt Flag Register
.const  IRQMASK = $D01A // IRQ Mask Register
.const  SPMC    = $D01C // Sprite multi-colour select
.const  XXPAND  = $D01D // Sprite X horizontal expand
.const  EXTCOL  = $D020 // Border Color Register
.const  BGCOL0  = $D021 // Background Color 0
.const  SPMC0   = $D025 // Sprite Multicolor Register 0
.const  SPMC1   = $D026 // Sprite Multicolor Register 1
.const  SP0COL  = $D027 // Sprite 0 Color Register
.const  COLRAM  = $D800 // Start of Color RAM

// SID
.const  FRELO1  = $D400 // Voice 1 Frequency Control (low byte)
.const  FRELO2  = $D407 // Voice 2 Frequency Control (low byte)
.const  FRELO3  = $D40E // Voice 3 Frequency Control (low byte)
.const  SIGVOL  = $D418 // Volume and Filter Select Register

// CIA2
.const  CI2PRA  = $DD00 // Port A access
.const  C2DDRA  = $DD02 // Port A direction

// Kernel
.const  STOP   = $FFE1 // Check the STOP key
