//---------------------------------------------------------------------------------------------------------------------
// Application constants
//---------------------------------------------------------------------------------------------------------------------
#importonce

.const VICMEM   = $8000             // start of video memory
.const CHRMEM1  = VICMEM + $0000    // start of lowert lower character set memory
.const CHRMEM2  = VICMEM + $0800    // start of upper case character set memory
.const SCNMEM   = VICMEM + $0400    // start of screen memory
.const SPTMEM   = SCNMEM + $07f8    // start of sprite pointer memory
.const GRPMEM   = VICMEM + $1000    // start of graphics memory
