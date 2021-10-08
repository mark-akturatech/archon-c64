
//----------------------------------------------------------
// Notes:
// - bk 6100: triggers after decryption
// - bk 623e: triggers just before intro page is shown
// - bk 6243: triggers after intro page closed

//----------------------------------------------------------









/*
load tape copy
then run, break 6100.

6126 jsr 4700



6100...
  jsr 4700...
  jst 632d

  .C:4700  A9 80       LDA #$80
.C:4702  8D A7 02    STA $02A7
.C:4705  AD 14 03    LDA $0314
.C:4708  8D CE BC    STA $BCCE
.C:470b  AD 15 03    LDA $0315
.C:470e  8D CF BC    STA $BCCF

// move 4400-45ff to 095d-0b5c
.C:4711  A9 00       LDA #$00
.C:4713  85 FB       STA $FB
.C:4715  A9 44       LDA #$44
.C:4717  85 FC       STA $FC
.C:4719  A9 5D       LDA #$5D
.C:471b  85 FD       STA $FD
.C:471d  A9 09       LDA #$09
.C:471f  85 FE       STA $FE
.C:4721  A2 02       LDX #$02
.C:4723  A0 00       LDY #$00
.C:4725  B1 FB       LDA ($FB),Y
.C:4727  91 FD       STA ($FD),Y
.C:4729  C8          INY
.C:472a  D0 F9       BNE $4725
.C:472c  E6 FC       INC $FC
.C:472e  E6 FE       INC $FE
.C:4730  CA          DEX
.C:4731  D0 F2       BNE $4725

// move 4600-467f to 0b5d-0bdc
.C:4733  B1 FB       LDA ($FB),Y
.C:4735  91 FD       STA ($FD),Y
.C:4737  C8          INY
.C:4738  C0 51       CPY #$51
.C:473a  90 F7       BCC $4733

// move 5000-59ff to 0bae-1bad
.C:473c  A9 AE       LDA #$AE
.C:473e  85 FD       STA $FD
.C:4740  A9 0B       LDA #$0B
.C:4742  85 FE       STA $FE
.C:4744  A9 50       LDA #$50
.C:4746  85 FC       STA $FC
.C:4748  A9 00       LDA #$00
.C:474a  85 FB       STA $FB
.C:474c  A8          TAY
.C:474d  A2 10       LDX #$10
.C:474f  B1 FB       LDA ($FB),Y
.C:4751  91 FD       STA ($FD),Y
.C:4753  C8          INY
.C:4754  D0 F9       BNE $474F
.C:4756  E6 FC       INC $FC
.C:4758  E6 FE       INC $FE
.C:475a  CA          DEX
.C:475b  D0 F2       BNE $474F
.C:475d  4C 66 47    JMP $4766

C:4760  77 83 8d 93  2c a8


.C:4766  A2 05       LDX #$05
.C:4768  BD 60 47    LDA $4760,X
.C:476b  9D 34 03    STA $0334,X   
.C:476e  CA          DEX
.C:476f  10 F7       BPL $4768
.C:4771  60          RTS





.C:632D LDA $DD02
.C:6330  09 03       ORA #$03
.C:6332  8D 02 DD    STA $DD02
.C:6335  AD 00 DD    LDA $DD00
.C:6338  29 FC       AND #$FC
.C:633a  09 02       ORA #$02
.C:633c  8D 00 DD    STA $DD00
.C:633f  A9 12       LDA #$12
.C:6341  8D 18 D0    STA $D018
.C:6344  A5 01       LDA $01
.C:6346  29 FE       AND #$FE
.C:6348  85 01       STA $01
.C:634a  78          SEI
.C:634b  A9 8E       LDA #$8E
.C:634d  8D CC BC    STA $BCCC
.C:6350  A9 63       LDA #$63
.C:6352  8D CD BC    STA $BCCD


.C:6355  AD 1A D0    LDA $D01A
.C:6358  29 7E       AND #$7E
.C:635a  8D 1A D0    STA $D01A

.C:635d  A9 7E       LDA #$7E
.C:635f  20 8B BC    JSR $BC8B

BC8B  8D 14 03   STA  $0314                 Vector: Hardware Interrupt (IRQ)
BC8E  8D 16 03   STA  $0316                 Vector: Break Interrupt
BC91  A9 63      LDA  #$63                  
BC93  8D 17 03   STA  $0317                 Vector: Break Interrupt
BC96  60         RTS  

6364  8D 15 03   STA  $0315                 Vector: Hardware Interrupt (IRQ)

6367  AD 11 D0   LDA  $D011                 VIC control register
636A  29 7F      AND  #$7F                  
636C  8D 11 D0   STA  WD011                 VIC control register
636F  A9 FB      LDA  #$FB                  
6371  8D 12 D0   STA  $D012                 Reading/Writing IRQ balance value
6374  AD 1A D0   LDA  WD01A                 IRQ mask register
W6377:
6377  09 81      ORA  #$81                  
6379  8D 1A D0   STA  WD01A                 IRQ mask register
637C  58         CLI                        
637D  60         RTS              

interrupt
.C:637e  AD 19 D0    LDA $D019
.C:6381  29 01       AND #$01
.C:6383  F0 06       BEQ $638B
.C:6385  8D 19 D0    STA $D019
.C:6388  6C CC BC    JMP ($BCCC)
.C:638b  6C CE BC    JMP ($BCCE)



637E  AD 19 D0   LDA  $D019                 Interrupt indicator register
6381  29 01      AND  #$01                  
6383  F0 06      BEQ  $638B                 
6385  8D 19 D0   STA  WD019                 Interrupt indicator register
6388  6C CC BC   JMP  (WBCCC) // 638e              Routine: INT function  
W638B:
638B  6C CE BC   JMP  ($BCCE) // ea31
*/

/*
6133  A9 D3      LDA  #$D3                  
6135  85 FD      STA  $FD                   
6137  A9 BC      LDA  #$BC                  
6139  85 FE      STA  W00FE                 Free 0 page for user program
613B  A2 03      LDX  #$03                  
613D  A9 00      LDA  #$00                  
613F  A8         TAY                        
6140  91 FD      STA  ($FD),Y               
6142  C8         INY                        
6143  D0 FB      BNE  $6140                 
6145  E6 FE      INC  W00FE                 Free 0 page for user program
6147  CA         DEX                        
6148  D0 F6      BNE  W6140 
*/

/*
9333  A9 00      LDA  #$00                  
9335  85 FD      STA  $FD                   
9337  A9 44      LDA  #$44                  
9339  85 FE      STA  W00FE                 Free 0 page for user program
933B  A2 03      LDX  #$03                  
933D  A9 00      LDA  #$00                  
933F  A8         TAY                        
9340  91 FD      STA  ($FD),Y               
9342  C8         INY                        
9343  D0 FB      BNE  $9340                 
9345  E6 FE      INC  W00FE                 Free 0 page for user program
9347  CA         DEX                        
9348  D0 F6      BNE  W9340                 
934A  91 FD      STA  ($FD),Y               
934C  C8         INY                        
934D  C0 E8      CPY  #$E8                  
934F  90 F9      BCC  $934A                 
9351  60         RTS  

C:6133  A9 D3       LDA #$D3
.C:6135  85 FD       STA $FD
.C:6137  A9 BC       LDA #$BC
.C:6139  85 FE       STA $FE
.C:613b  A2 03       LDX #$03
.C:613d  A9 00       LDA #$00
.C:613f  A8          TAY
.C:6140  91 FD       STA ($FD),Y
.C:6142  C8          INY
.C:6143  D0 FB       BNE $6140
.C:6145  E6 FE       INC $FE
.C:6147  CA          DEX
.C:6148  D0 F6       BNE $6140

.C:9333  A9 00       LDA #$00
.C:9335  85 FD       STA $FD
.C:9337  A9 44       LDA #$44
.C:9339  85 FE       STA $FE
.C:933b  A2 03       LDX #$03
.C:933d  A9 00       LDA #$00
.C:933f  A8          TAY
.C:9340  91 FD       STA ($FD),Y
.C:9342  C8          INY
.C:9343  D0 FB       BNE $9340
.C:9345  E6 FE       INC $FE
.C:9347  CA          DEX
.C:9348  D0 F6       BNE $9340
.C:934a  91 FD       STA ($FD),Y
.C:934c  C8          INY
.C:934d  C0 E8       CPY #$E8
.C:934f  90 F9       BCC $934A
.C:9351  60          RTS

.C:8dd3  A9 00       LDA #$00
.C:8dd5  85 FD       STA $FD
.C:8dd7  A9 50       LDA #$50
.C:8dd9  85 FE       STA $FE
.C:8ddb  A2 10       LDX #$10
.C:8ddd  A9 00       LDA #$00
.C:8ddf  A8          TAY
.C:8de0  91 FD       STA ($FD),Y
.C:8de2  C8          INY
.C:8de3  D0 FB       BNE $8DE0
.C:8de5  E6 FE       INC $FE
.C:8de7  CA          DEX
.C:8de8  D0 F6       BNE $8DE0
.C:8dea  A2 07       LDX #$07
.C:8dec  8D 10 D0    STA $D010
.C:8def  9D 00 D0    STA $D000,X
.C:8df2  CA          DEX
.C:8df3  10 FA       BPL $8DEF
.C:8df5  60          RTS


*/