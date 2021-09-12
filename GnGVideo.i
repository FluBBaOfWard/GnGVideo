;@ ASM header for the GnG Video emulator
;@

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (224)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

	.equ CHRSRCTILECOUNTBITS,	10
	.equ CHRDSTTILECOUNTBITS,	9
	.equ CHRGROUPTILECOUNTBITS,	3
	.equ CHRBLOCKCOUNT,			(1<<(CHRSRCTILECOUNTBITS - CHRGROUPTILECOUNTBITS))
	.equ CHRTILESIZEBITS,		4

	.equ BGSRCTILECOUNTBITS,	12
	.equ BGDSTTILECOUNTBITS,	10
	.equ BGGROUPTILECOUNTBITS,	3
	.equ BGBLOCKCOUNT,			(1<<(BGSRCTILECOUNTBITS - BGGROUPTILECOUNTBITS))
	.equ BGTILESIZEBITS,		5

	.equ SPRSRCTILECOUNTBITS,	12
	.equ SPRDSTTILECOUNTBITS,	10
	.equ SPRGROUPTILECOUNTBITS,	3
	.equ SPRBLOCKCOUNT,			(1<<(SPRSRCTILECOUNTBITS - SPRGROUPTILECOUNTBITS))
	.equ SPRTILESIZEBITS,		5

	gngptr		.req r12
						;@ GnGVideo.s
	.struct 0
scanline:		.long 0			;@ These 3 must be first in state.
nextLineChange:	.long 0
lineState:		.long 0

frameIrqFunc:	.long 0
latchIrqFunc:	.long 0

gngVideoState:					;@
gngVideoRegs:					;@ 0-4
scrollXReg:		.short 0		;@
scrollYReg:		.short 0		;@
flipReg:		.byte 0			;@
latchReg:		.byte 0			;@
bankReg:		.byte 0			;@
padding0:		.space 1

oldScrollX:		.short 0
oldScrollY:		.short 0

gfxReload:
chrMemReload:	.byte 0
bgMemReload:	.byte 0
sprMemReload:	.byte 0
padding1:		.space 1

chrMemAlloc:	.long 0
bgMemAlloc:		.long 0
sprMemAlloc:	.long 0

chrRomBase:		.long 0
chrGfxDest:		.long 0
bgrRomBase:		.long 0
bgrGfxDest:		.long 0
spriteRomBase:	.long 0

dirtyTiles:		.space 8
gfxRAM:			.long 0
paletteRAM:		.long 0
chrBlockLUT:	.long 0
bgBlockLUT:		.long 0
sprBlockLUT:	.long 0

gngVideoSize:

;@----------------------------------------------------------------------------
