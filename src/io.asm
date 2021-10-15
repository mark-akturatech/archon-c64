//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
// C64 I/O constants
//
// Inspired by C64-Mark
// https://github.com/C64-Mark/Attack-of-the-Mutant-Camels/blob/master/Original/IO.asm
//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------
#importonce

// Processor
.const R6510    = $01   // Processort port
.const LSTX     = $C5;  // Matrix Coordinate of Last Key Pressed, 64=None Pressed
.const FREEZP   = $FB;  // Four Free Bytes of Zero Page for User Programs
.const CINV     = $0314 // Vector to IRQ Interrupt Routine
.const CBINV    = $0316 // Vector: BRK Instruction Interrupt

// VIC
.const  SP0X    = $D000 // Sprite 0 Horizontal Position
.const  SP0Y    = $D001 // Sprite 0 Vertical Position
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

// SID
.const  SIGVOL  = $D418 // Volume and Filter Select Register

// CIA2
.const  CI2PRA  = $DD00 // Port A access
.const  C2DDRA  = $DD02 // Port A direction

// Kernel
.const  STOP   = $FFE1 // check the STOP key
