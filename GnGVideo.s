// Ghosts'n Goblins Video Chip emulation

#ifdef __arm__

#ifdef GBA
#include "../Shared/gba_asm.h"
#elif NDS
#include "../Shared/nds_asm.h"
#endif
#include "../Equates.h"
#include "GnGVideo.i"

	.global gngVideoInit
	.global gngVideoReset
	.global gngSaveState
	.global gngLoadState
	.global gngGetStateSize
	.global doScanline
	.global copyScrollValues
	.global convertChrTileMap
	.global convertBGTileMap
	.global convertSpritesGnG
	.global gngIO_W
	.global gngLatchR


	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
gngVideoInit:				;@ Only need to be called once
;@----------------------------------------------------------------------------
	mov r1,#0xffffff00			;@ Build bg tile decode tbl
	ldr r2,=CHR_DECODE
ppi:
	ands r0,r1,#0x01
	movne r0,#0x10000000
	tst r1,#0x02
	orrne r0,r0,#0x01000000
	tst r1,#0x04
	orrne r0,r0,#0x00100000
	tst r1,#0x08
	orrne r0,r0,#0x00010000
	tst r1,#0x10
	orrne r0,r0,#0x00001000
	tst r1,#0x20
	orrne r0,r0,#0x00000100
	tst r1,#0x40
	orrne r0,r0,#0x00000010
	tst r1,#0x80
	orrne r0,r0,#0x00000001
	str r0,[r2],#4
	adds r1,r1,#1
	bne ppi

	bx lr
;@----------------------------------------------------------------------------
gngVideoReset:				;@ r0=frameIrqFunc, r1=latchIrqFunc, r2=ram+LUTs
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r2,lr}

	mov r0,gngptr
	ldr r1,=gngVideoSize/4
	bl memclr_					;@ Clear VDP state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia gngptr,{r0-r2}		;@ Reset scanline, nextChange & lineState

//	mov r0,#-1
	str r0,[gngptr,#gfxReload]

	ldmfd sp!,{r0-r2}
	cmp r0,#0
	adreq r0,dummyIrqFunc
	cmp r1,#0
	adreq r1,dummyIrqFunc
	str r0,[gngptr,#frameIrqFunc]
	str r1,[gngptr,#latchIrqFunc]

	str r2,[gngptr,#gfxRAM]
	sub r1,r2,#0x800
	str r1,[gngptr,#paletteRAM]
	add r1,r2,#0x3200
	str r1,[gngptr,#chrBlockLUT]
	add r1,r1,#CHRBLOCKCOUNT*4
	str r1,[gngptr,#bgBlockLUT]
	add r1,r1,#BGBLOCKCOUNT*4
	str r1,[gngptr,#sprBlockLUT]

//	mov r0,r2
//	mov r1,#0x3200
//	bl clrMemRnd
	ldmfd sp!,{lr}

dummyIrqFunc:
	bx lr
/*
;@----------------------------------------------------------------------------
clrMemRnd:		;@ r0=dst, r1=len
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}
	mov r4,r0
	mov r5,r1
clrRndLoop:
	mov r0,#0x200
	bl getRandomNumber
	strb r0,[r4],#1
	subs r5,r5,#1
	bne clrRndLoop

	ldmfd sp!,{r4-r5,pc}
*/
;@----------------------------------------------------------------------------
gngSaveState:			;@ In r0=destination, r1=gngptr. Out r0=state size.
	.type   gngSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r4,r0				;@ Store destination
	mov r5,r1				;@ Store gngptr (r1)

	ldr r1,[r5,#gfxRAM]
	mov r2,#0x3200
	bl memcpy

	add r0,r4,#0x3200
	add r1,r5,#gngVideoRegs
	mov r2,#8
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x3208
	bx lr

#ifdef GBA
	.section .ewram,"ax"
	.align 2
#endif
;@----------------------------------------------------------------------------
gngLoadState:			;@ In r0=gngptr, r1=source. Out r0=state size.
	.type   gngLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0				;@ Store gngptr (r0)
	mov r4,r1				;@ Store source

	ldr r0,[r5,#gfxRAM]
	mov r2,#0x3200
	bl memcpy

	add r0,r5,#gngVideoRegs
	add r1,r4,#0x3200
	mov r2,#8
	bl memcpy

	mov r0,#-1
	str r0,[r5,#gfxReload]
	ldrb r0,[r5,#bankReg]
	bl switchBank

	mov gngptr,r5
	bl endFrame

	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
gngGetStateSize:		;@ Out r0=state size.
	.type   gngGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	ldr r0,=0x3208
	bx lr

;@----------------------------------------------------------------------------
gngLatchR:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#0
	mov lr,pc
	ldr pc,[gngptr,#latchIrqFunc]
	ldrb r0,[gngptr,#latchReg]
	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
PaletteW:				;@ 0x3800-0x39FF
;@----------------------------------------------------------------------------
	ldr r2,[gngptr,#paletteRAM]
	strb r0,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
soundLatchW:			;@ 0x3A00
;@----------------------------------------------------------------------------
	strb r0,[gngptr,#latchReg]
	mov r0,#1
	ldr pc,[gngptr,#latchIrqFunc]
;@----------------------------------------------------------------------------
scrollW:				;@ 0x3B08-0x3B0B
;@----------------------------------------------------------------------------
	add r2,gngptr,#scrollXReg
	and r1,r1,#3
	strb r0,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
scrollXW:				;@ 0x3B08-09
;@----------------------------------------------------------------------------
	strh r0,[gngptr,#scrollXReg]
	bx lr
;@----------------------------------------------------------------------------
scrollYW:				;@ 0x3B0A-0B
;@----------------------------------------------------------------------------
	strh r0,[gngptr,#scrollYReg]
	bx lr
;@----------------------------------------------------------------------------
dmaW:					;@ 0x3C00
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
mainLatchW:				;@ 0x3D00-0x3D07
;@----------------------------------------------------------------------------
	ands r1,#0xFF
	beq flipW
	cmp r1,#0x01
	beq audioResetW
	bx lr
;@----------------------------------------------------------------------------
flipW:					;@ 0x3D00
;@----------------------------------------------------------------------------
	strb r0,[gngptr,#flipReg]	;@ Bit 0? screen flip
	bx lr
;@----------------------------------------------------------------------------
audioResetW:			;@ 0x3D01
;@----------------------------------------------------------------------------
	b resetSoundCpu
;@----------------------------------------------------------------------------
coinCounter0W:			;@ 0x3D02
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
coinCounter1W:			;@ 0x3D03
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
bankSwitchW:			;@ 0x3E00
;@----------------------------------------------------------------------------
	strb r0,[gngptr,#bankReg]
;@----------------------------------------------------------------------------
switchBank:				;@ In r0=bank, 4=0, 0=6, 1=7, 2=8, 3=9.
;@----------------------------------------------------------------------------
	cmp r0,#4
	and r1,r0,#3
	addne r1,r1,#6
	mov r0,#0x4
	b m6809Mapper0

;@----------------------------------------------------------------------------
reloadChrTiles:
;@----------------------------------------------------------------------------
	strb r0,[gngptr,#dirtyTiles+4]
	mov r0,#1<<(CHRDSTTILECOUNTBITS-CHRGROUPTILECOUNTBITS)
	str r0,[gngptr,#chrMemAlloc]
	mov r1,#1<<(32-CHRGROUPTILECOUNTBITS)		;@ r1=value
	strb r1,[gngptr,#chrMemReload]	;@ Clear bg mem reload.
	mov r0,r9					;@ r0=destination
	mov r2,#CHRBLOCKCOUNT		;@ 512 tile entries
	b memset_					;@ Prepare LUT
;@----------------------------------------------------------------------------
convertChrTileMap:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	add r6,r0,#0x80				;@ Destination + skip first 2 rows

	ldr r9,[gngptr,#chrBlockLUT]
	ldrb r0,[gngptr,#chrMemReload]
	cmp r0,#0
	blne reloadChrTiles

	ldrb r0,[gngptr,#dirtyTiles+4]	;@ Check dirty map
	cmp r0,#0
	ldmfdeq sp!,{r3-r11,pc}
	mov r0,#0
	strb r0,[gngptr,#dirtyTiles+4]
	ldr r4,[gngptr,#gfxRAM]
	add r4,r4,#0x2000
	add r4,r4,#0x40				;@ Skip first 2 rows

	bl chrMapRender
	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
reloadBGTiles:
;@----------------------------------------------------------------------------
	strb r0,[gngptr,#dirtyTiles+5]
	mov r0,#(1<<(BGDSTTILECOUNTBITS-BGGROUPTILECOUNTBITS))-1
	str r0,[gngptr,#bgMemAlloc]
	mov r1,#1<<(32-BGGROUPTILECOUNTBITS)		;@ r1=value
	strb r1,[gngptr,#bgMemReload]	;@ Clear bg mem reload.
	mov r0,r9					;@ r0=destination
	mov r2,#BGBLOCKCOUNT		;@ 512 tile entries
	b memset_					;@ Prepare LUT
;@----------------------------------------------------------------------------
convertBGTileMap:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	mov r6,r0					;@ Destination

	ldr r9,[gngptr,#bgBlockLUT]
	ldrb r0,[gngptr,#bgMemReload]
	cmp r0,#0
	blne reloadBGTiles

//	ldr r8,=(((1<<(BGGROUPTILECOUNTBITS + BGTILESIZEBITS)) - 1) << 16) + (BGGROUPTILECOUNTBITS + BGTILESIZEBITS)

	ldr r7,[gngptr,#scrollXReg]
	add r7,r7,#(SCREEN_WIDTH-GAME_WIDTH)/2
	mov r7,r7,lsr#4				;@ Just keep tile x index
	bic r7,r7,#0xFF00			;@ Mask out Y left overs
	ldr r0,[gngptr,#oldScrollX]
	eors r0,r0,r7
	strne r7,[gngptr,#oldScrollX]
	ldrbeq r0,[gngptr,#dirtyTiles+5]	;@ Check dirty map
	cmpeq r0,#0
	beq noChange
	mov r0,#0
	strb r0,[gngptr,#dirtyTiles+5]
	ldr r4,[gngptr,#gfxRAM]
	add r4,r4,#0x2800
	add r7,r7,#0x10000			;@ Skip first row
//	ldrb r0,[gngptr,#flipReg]
//	tst r0,#0x01				;@ Screen flip bit
//	bne flippedTileMap5849

//	ldr r3,=0x20000008			;@ Row modulo + tile vs color map offset
//	mov r11,#0x01000000			;@ Increase read
	bl bgrMapRender
noChange:
	ldmfd sp!,{r3-r11,pc}

flippedTileMap5849:
//	ldr r3,=0xE0000008			;@ Row modulo + tile vs color map offset
//	ldr r11,=0xFF000C00			;@ Decrease read, XY-flip
//	sub r4,r4,#1
//	add r4,r4,#0x800-0x20
//	bl bgrMapRender
//	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
checkFrameIRQ:
;@----------------------------------------------------------------------------
	mov r0,#1
	ldr pc,[gngptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
disableFrameIRQ:
;@----------------------------------------------------------------------------
	mov r0,#0
	ldr pc,[gngptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
frameEndHook:
	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#0
	stmia gngptr,{r0-r2}		;@ Reset scanline, nextChange & lineState

//	mov r0,#0					;@ Must return 0 to end frame.
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------

//	ldr r0,=g_dipSwitch2
//	ldrb r1,[r0]
//	bic r1,r1,#0x40				;@ VBL flag
//	strb r1,[r0]
	bx lr

;@----------------------------------------------------------------------------
lineStateTable:
	.long 0, newFrame			;@ zeroLine
	.long 239, endFrame			;@ Last visible scanline
	.long 240, checkFrameIRQ	;@ frameIRQ on
	.long 264, disableFrameIRQ	;@ frameIRQ off
	.long 272, frameEndHook		;@ totalScanlines
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2
;@----------------------------------------------------------------------------
redoScanline:
	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
doScanline:
;@----------------------------------------------------------------------------
	ldmia gngptr,{r1,r2}		;@ Read scanLine & nextLineChange
	subs r0,r1,r2
	addmi r1,r1,#1
	strmi r1,[gngptr,#scanline]
	bxmi lr
;@----------------------------------------------------------------------------
executeScanline:
;@----------------------------------------------------------------------------
	ldr r2,[gngptr,#lineState]
	ldmia r2!,{r0,r1}
	stmib gngptr,{r1,r2}		;@ Write nextLineChange & lineState
	stmfd sp!,{lr}
	adr lr,redoScanline
	bx r0

;@----------------------------------------------------------------------------
gngIO_W:				;@ (0x3800-0x3FFF), In r1= address, r0=value
;@----------------------------------------------------------------------------
	cmp r1,#0x3000
	bmi ramWrite
	cmp r1,#0x3800
	and r2,r1,#0x0700
	ldrpl pc,[pc,r2,lsr#6]
;@---------------------------
	b empty_IO_W
;@ io_write_tbl
	.long PaletteW			;@ 0x3800-0x38FF
	.long PaletteW			;@ 0x3900-0x39FF
	.long soundLatchW		;@ 0x3A00
	.long scrollW			;@ 0x3B00
	.long dmaW				;@ 0x3C00, copy sprite table to internal RAM?
	.long mainLatchW		;@ 0x3D00-0x3D07, Flip Screen, Coin write
	.long bankSwitchW		;@ 0x3E00
	.long empty_IO_W		;@ 0x3F00
;@----------------------------------------------------------------------------
ramWrite:				;@ Ram write ($2000-$2FFF)
;@----------------------------------------------------------------------------
	ldr r2,[gngptr,#gfxRAM]
	strb r0,[r2,r1]
	add r2,gngptr,#dirtyTiles
	mov r0,#-1
	strb r0,[r2,r1,lsr#11]
	bx lr
;@----------------------------------------------------------------------------
bgrMapRender:
	stmfd sp!,{lr}

	ldr r11,=0x00010001
	mov r10,#15
bgTrLoop2:
	mov r8,#16+1
bgTrLoop1:
	and r2,r7,#0x1f
	mov r2,r2,lsl#5
	and r0,r7,#0x1f0000
	orr r2,r2,r0,lsr#16
	ldrb r0,[r2,r4]!			;@ Read from GnG Tilemap RAM,  tttttttt
	ldrb r5,[r2,#0x400]			;@ Read from GnG Colormap RAM, ttxyPccc -> 0cccxytt

	and r1,r5,#0xC0				;@ Tilemap MSBs
	orr r0,r0,r1,lsl#2

	and r1,r5,#0x30				;@ XY bits
	and r5,r5,#0x0F				;@ Color bits
	orr r5,r1,r5,lsl#6

	mov r0,r0,lsl#2				;@ Convert 16x16 tile nr to 8x8 tile nr.
	bl getTilesFromCache

	orr r0,r0,r5,lsl#6			;@ Color + xy

	orr r0,r0,#0x20000			;@ Next tile
	orr r0,r0,r0,lsl#16
	movs r1,r0,lsl#5
	movmi r0,r0,ror#16			;@ X flip
	orrcs r0,r0,r11				;@ Y flip

	and r1,r7,#0x0f
	and r2,r7,#0xf0000
	orr r2,r1,r2,lsr#11
#ifdef NDS
	tst r7,#0x10				;@ Next horizontal map?
	addne r2,r2,#0x200
#endif
	mov r2,r2,lsl#2
	str r0,[r2,r6]!				;@ Write to GBA/NDS Tilemap RAM
	eor r1,r11,r0
	str r1,[r2,#0x40]			;@ Write to GBA/NDS Tilemap RAM

	eors r0,r0,r11,lsl#15
	movmi r0,r0,asr#31
	str r0,[r2,r11,lsr#4]!		;@ Write to GBA/NDS priority Tilemap RAM
	eor r1,r11,r0
	str r1,[r2,#0x40]			;@ Write to GBA/NDS priority Tilemap RAM

	add r7,r7,#1
	subs r8,r8,#1
	bne bgTrLoop1

	sub r7,r7,#16+1
	add r7,r7,#0x10000
	subs r10,r10,#1
	bne bgTrLoop2

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
tileCacheFull:
	strb r2,[gngptr,#bgMemReload]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
getTilesFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#BGGROUPTILECOUNTBITS		;@ Mask tile number
	bic r0,r0,r1,lsl#BGGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]		;@ Check cache, uncached = 0x10000000
	orrs r0,r0,r2,lsl#BGGROUPTILECOUNTBITS
	bxcc lr						;@ Allready cached
allocTiles:
	ldr r2,[gngptr,#bgMemAlloc]
	subs r2,r2,#1
	bmi tileCacheFull
	str r2,[gngptr,#bgMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#BGGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
renderTiles:
	stmfd sp!,{r0,r4-r6,lr}
	ldr r6,=CHR_DECODE
#ifdef ARM9
	ldrd r4,r5,[gngptr,#bgrRomBase]
#else
	ldr r4,[gngptr,#bgrRomBase]
	ldr r5,[gngptr,#bgrGfxDest]
#endif
	add r0,r5,r2,lsl#BGGROUPTILECOUNTBITS+5
	add r2,r4,r1,lsl#BGGROUPTILECOUNTBITS+3
	add r3,r2,#0x8000
	add r4,r3,#0x8000

renderTilesLoop:
	ldrb r1,[r2],#1				;@ Read 1st plane
	ldrb r5,[r3],#1				;@ Read 2nd plane
	ldr r1,[r6,r1,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r1,r1,r5,lsl#1
	ldrb r5,[r4],#1				;@ Read 3rd plane
	ldr r5,[r6,r5,lsl#2]
	orr r1,r1,r5,lsl#2
	str r1,[r0],#4

	tst r0,#0xfc
	bne renderTilesLoop

	ldmfd sp!,{r0,r4-r6,pc}

;@----------------------------------------------------------------------------
chrMapRender:
	stmfd sp!,{lr}

	mov r10,#28					;@ Skip top and bottom
chrTrLoop1:
	ldrb r5,[r4,#0x400]			;@ Read from GnG Colormap RAM, ttxycccc -> ccccxytt
	ldrb r0,[r4],#1				;@ Read from GnG Charmap RAM,  tttttttt

	mov r5,r5,ror#6
	orr r0,r0,r5,lsl#8

	bl getCharsFromCache

	and r1,r5,#0xC0000000		;@ xy flip
	orr r5,r5,r1,lsr#4
	orr r0,r0,r5,lsr#14			;@ Palette

	strh r0,[r6],#2				;@ Write to NDS Tilemap RAM

	tst r6,#0x03e
	bne chrTrLoop1

	subs r10,r10,#1
	bne chrTrLoop1
//	tst r6,#0x7c0
//	bne chrTrLoop1

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
charCacheFull:
	strb r2,[gngptr,#chrMemReload]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
getCharsFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#CHRGROUPTILECOUNTBITS		;@ Mask tile number
	bic r0,r0,r1,lsl#CHRGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]		;@ Check cache, uncached = 0x10000000
	orrs r0,r0,r2,lsl#CHRGROUPTILECOUNTBITS
	bxcc lr						;@ Allready cached
allocChars:
	ldr r2,[gngptr,#chrMemAlloc]
	subs r2,r2,#1
	bmi charCacheFull
	str r2,[gngptr,#chrMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#CHRGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
renderChars:
	stmfd sp!,{r0,r4-r8,lr}
	ldr r6,=CHR_DECODE
#ifdef ARM9
	ldrd r4,r5,[gngptr,#chrRomBase]
#else
	ldr r4,[gngptr,#chrRomBase]
	ldr r5,[gngptr,#chrGfxDest]
#endif
	add r4,r4,r1,lsl#CHRGROUPTILECOUNTBITS+4
	add r5,r5,r2,lsl#CHRGROUPTILECOUNTBITS+5

renderCharsLoop:
	ldrh r0,[r4],#2				;@ Read 1st & 2nd plane, left & right half.
	mvn r0,r0,ror#8
	and r1,r0,#0xFF
	mov r0,r0,lsr#24

	ldr r0,[r6,r0,lsl#2]
	orr r2,r0,r0,ror#16
	orr r2,r2,r2,lsl#1
	orr r0,r0,r0,lsr#15
	orr r0,r0,r2,lsr#14

	ldr r1,[r6,r1,lsl#2]
	orr r2,r1,r1,ror#16
	orr r2,r2,r2,lsl#1
	orr r1,r1,r1,lsr#15
	orr r1,r1,r2,lsr#14
	mov r0,r0,lsl#16
	mov r1,r1,lsl#16
	orr r0,r1,r0,lsr#16

	str r0,[r5],#4

	tst r5,#0xfc				;@ #0x80 8 8x8 tiles
	bne renderCharsLoop

	ldmfd sp!,{r0,r4-r8,pc}
;@----------------------------------------------------------------------------
copyScrollValues:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r7}
	mov r3,#0x20
	ldr r6,[gngptr,#scrollXReg]

//	ldrb r7,[gngptr,#flipReg]
//	tst r7,#0x01				;@ Screen flip bit
//	movne r7,#-1
//	moveq r7,#1
//	rsbne r6,r6,#0x1800
//	add r1,gngptr,#1
//	addne r1,r1,#0x1F

	mov r5,r6
setScrlLoop:
	stmia r0!,{r5,r6}
	stmia r0!,{r5,r6}
	stmia r0!,{r5,r6}
	stmia r0!,{r5,r6}
	subs r3,r3,#1
	bne setScrlLoop

	ldmfd sp!,{r4-r7}
	bx lr

;@----------------------------------------------------------------------------
reloadSprites:
;@----------------------------------------------------------------------------
	mov r1,#1<<(32-SPRGROUPTILECOUNTBITS)	;@ r1=value
	strb r1,[gngptr,#sprMemReload]			;@ Clear spr mem reload.
	mov r0,r9								;@ r0=destination
	mov r2,#SPRBLOCKCOUNT					;@ Number of tile entries
	b memset_								;@ Prepare LUT
;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x800		;@ 0x800=AGB OBJ priority 2
;@----------------------------------------------------------------------------
convertSpritesGnG:			;@ In r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	mov r11,r0					;@ Destination
	mov r8,#96					;@ Number of sprites
//	ldrb r0,[gngptr,#scrollXReg+1]
//	tst r0,#0x80				;@ Sprites enabled?
//	beq dm7

	ldr r9,[gngptr,#sprBlockLUT]
	ldrb r0,[gngptr,#sprMemReload]
	cmp r0,#0
	blne reloadSprites

	ldr r10,[gngptr,#gfxRAM]
	add r10,r10,#0x1e00

	ldr r7,=gScaling
	ldrb r7,[r7]
	cmp r7,#UNSCALED			;@ Do autoscroll
	ldreq r7,=0x01000000		;@ No scaling
//	ldrne r7,=0x00DB6DB6		;@ 192/224, 6/7, scaling. 0xC0000000/0xE0 = 0x00DB6DB6.
//	ldrne r7,=0x00B6DB6D		;@ 160/224, 5/7, scaling. 0xA0000000/0xE0 = 0x00B6DB6D.
	ldrne r7,=(SCREEN_HEIGHT<<21)/(GAME_HEIGHT>>3)		;@ 192/240, 12/15, scaling. 0xC0000000/0xF0 = 0x00DB6DB6.
	mov r0,#0
	ldreq r0,=yStart			;@ First scanline?
	ldrbeq r0,[r0]
	add r6,r0,#0x08

	mov r5,#0x40000000			;@ 16x16 size
	orrne r5,r5,#0x0100			;@ Scaling

//	ldrb r4,[gngptr,#irqControl]
//	tst r4,#0x08				;@ Flip enabled?
//	orrne r5,#0x30000000		;@ flips
//	rsbne r7,r7,#0
//	rsbne r6,r0,#0xE8

dm5:
	ldr r4,[r10],#4				;@ GnG OBJ, r4=Xpos,Ypos,Attrib,Tile.
	mov r0,r4,lsr#16			;@ Mask Y
	ands r0,r0,#0xFF			;@ Check yPos 0
	beq skipSprite

	and r1,r4,#0x00000100		;@ Xpos msb
	orr r1,r1,r4,lsr#24			;@ XPos
//	tst r7,#0x80000000			;@ Is scaling negative (flip)?
	sub r1,r1,#(GAME_WIDTH-SCREEN_WIDTH)/2
//	rsbne r1,r1,#(GAME_WIDTH-16)-(GAME_WIDTH-SCREEN_WIDTH)/2			;@ Flip Xpos
	mov r1,r1,lsl#23

	sub r0,r0,r6
	mul r0,r7,r0				;@ Y scaling
	sub r0,r0,#0x07800000		;@ -8, + 0.5
	add r0,r5,r0,lsr#24			;@ YPos + size + scaling
	orr r0,r0,r1,lsr#7			;@ XPos

	and r1,r4,#0x00000C00		;@ X/Yflip
	orr r0,r0,r1,lsl#18
	str r0,[r11],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	and r1,r4,#0x00FF
	and r0,r4,#0xC000
	orr r0,r1,r0,lsr#6
	mov r0,r0,lsl#2				;@ Convert 16x16 tile nr to 8x8 tile nr.
	bl getSpriteFromCache		;@ Jump to spr copy, takes tile# in r0, gives new tile# in r0

	and r1,r4,#0x3000			;@ Color
	orr r0,r1,r0
	orr r0,r0,#PRIORITY			;@ Priority
	strh r0,[r11],#4			;@ Store OBJ Atr 2. Pattern, prio & palette.
dm3:
	subs r8,r8,#1
	bne dm5
	ldmfd sp!,{r4-r11,pc}
skipSprite:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	b dm3

dm7:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	subs r8,r8,#1
	bne dm7
	ldmfd sp!,{r4-r11,pc}

;@----------------------------------------------------------------------------
spriteCacheFull:
	strb r2,[gngptr,#sprMemReload]
	mov r2,#1<<(SPRDSTTILECOUNTBITS-SPRGROUPTILECOUNTBITS)
	str r2,[gngptr,#sprMemAlloc]
	ldmfd sp!,{r4-r11,pc}
;@----------------------------------------------------------------------------
getSpriteFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#SPRGROUPTILECOUNTBITS
	bic r0,r0,r1,lsl#SPRGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]
	orrs r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS		;@ Check cache, uncached = 0x20000000
	bxcc lr										;@ Allready cached
alloc16x16x2:
	ldr r2,[gngptr,#sprMemAlloc]
	subs r2,r2,#1
	bmi spriteCacheFull
	str r2,[gngptr,#sprMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
do16:
	stmfd sp!,{r0,r4-r8,lr}
	ldr r6,=CHR_DECODE
	mov r7,#0xf
	ldr r0,=SPRITE_GFX			;@ r0=GBA/NDS SPR tileset
	add r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS+5	;@ x 128 bytes x 4 tiles

	ldr r2,[gngptr,#spriteRomBase]
	add r2,r2,r1,lsl#SPRGROUPTILECOUNTBITS+4
	add r3,r2,#0x10000

spr16Loop:
	ldrb r4,[r2],#1				;@ Read 1st & 2nd plane, right half.
	ldrb r5,[r3],#1				;@ Read 3rd & 4th plane, right half.
	ldr r4,[r6,r4,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r7,r4,r5,lsl#2

	ldrb r4,[r2],#1				;@ Read 1st & 2nd plane, left half.
	ldrb r5,[r3],#1				;@ Read 3rd & 4th plane, left half.
	ldr r4,[r6,r4,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r4,r4,r5,lsl#2

	orr r4,r4,r4,lsr#15
	orr r7,r7,r7,lsr#15
	mvn r4,r4,lsl#16
	mvn r7,r7,lsl#16
	and r4,r4,r7,ror#16
	str r4,[r0],#4

	tst r0,#0x1c
	bne spr16Loop

	tst r0,#0x20
	addne r2,r2,#0x10
	addne r3,r3,#0x10
	bne spr16Loop

	tst r0,#0x40
	subne r2,r2,#0x20
	subne r3,r3,#0x20
	bne spr16Loop

	tst r0,#0x80				;@ Allways 2 16x16 tiles
	bne spr16Loop

	ldmfd sp!,{r0,r4-r8,pc}

;@----------------------------------------------------------------------------

#ifdef GBA
	.section .sbss						;@ For the GBA
#else
	.section .bss
#endif
CHR_DECODE:
	.space 0x400

#endif // #ifdef __arm__
