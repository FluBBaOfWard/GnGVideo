// Ghosts'n Goblins Video Chip emulation

#ifndef GNGVIDEO_HEADER
#define GNGVIDEO_HEADER

#ifdef __cplusplus
extern "C" {
#endif

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (224)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

typedef struct {
	u32 scanline;
	u32 nextLineChange;
	u32 lineState;

	void *frameIrqFunc;
	void *latchIrqFunc;

//gngVState:
//gngVRegs:					// 0-4
	u16 scrollXReg;				// Scroll X
	u16 scrollYReg;				// Scroll X
	u8 flipReg;					// Flip screen
	u8 latchReg;				// Latch
	u8 bankReg;					// Bank switch
	u8 padding0[1];

	u16 oldScrollX;				// Old Scroll X
	u16 oldScrollY;				// Old Scroll X

	u8 chrMemReload;
	u8 bgMemReload;
	u8 sprMemReload;
	u8 padding1[1];

	u32 chrMemAlloc;
	u32 bgMemAlloc;
	u32 sprMemAlloc;

	u32 *chrRomBase;
	u32 *chrGfxDest;
	u32 *bgrRomBase;
	u32 *bgrGfxDest;
	u32 *spriteRomBase;

	u8 dirtyTiles[8];
	u8 *gfxRAM;
	u32 *chrBlockLUT;
	u32 *bgBlockLUT;
	u32 *sprBlockLUT;
} GNGVideo;

void gngVideoReset(void *frameIrqFunc(), void *latchIrqFunc(), u8 *ram);

/**
 * Saves the state of the GNGVideo chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The GNGVideo chip to save.
 * @return The size of the state.
 */
int gngSaveState(void *destination, const GNGVideo *chip);

/**
 * Loads the state of the GNGVideo chip from the source.
 * @param  *chip: The GNGVideo chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int gngLoadState(GNGVideo *chip, const void *source);

/**
 * Gets the state size of a GNGVideo chip.
 * @return The size of the state.
 */
int gngGetStateSize(void);

void convertChrTileMap(void *destination);
void convertBGTileMap(void *destination);
void convertSpritesGnG(void *destination);
void doScanline(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // GNGVIDEO_HEADER
