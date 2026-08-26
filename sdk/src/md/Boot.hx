package md;

import md.hw.Vdp as Ports;
import md.hw.Z80;

class Boot {
	public static inline final PLANE_A = 0xE000;

	public static inline final PLANE_B = 0xC000;

	public static inline final WINDOW = 0xD000;

	public static inline final SPRITES = 0xF400;

	public static inline final SCROLL = 0xF000;

	public static function begin():Void {
		while ((Ports.status() & Ports.DMA_BUSY) != 0) {}

		Ports.register(0, 0x04);
		Ports.register(1, 0x04);
		Ports.register(2, PLANE_A >> 10);
		Ports.register(3, WINDOW >> 10);
		Ports.register(4, PLANE_B >> 13);
		Ports.register(5, SPRITES >> 9);
		Ports.register(6, 0x00);
		Ports.register(7, 0x00);
		Ports.register(8, 0x00);
		Ports.register(9, 0x00);
		Ports.register(10, 0x01);
		Ports.register(11, 0x00);
		Ports.register(12, 0x81);
		Ports.register(13, SCROLL >> 10);
		Ports.register(14, 0x00);
		Ports.register(15, 0x02);
		Ports.register(16, 0x01);
		Ports.register(17, 0x00);
		Ports.register(18, 0x00);

		Tilemap.setBase(Plane.A, PLANE_A);
		Tilemap.setBase(Plane.B, PLANE_B);
		Tilemap.setBase(Plane.Window, WINDOW);
		Tilemap.setPlaneSize(64, 32);
		SpriteTable.setBase(SPRITES);

		wipe(Ports.VRAM_WRITE, 0, 0x8000);
		wipe(Ports.CRAM_WRITE, 0, Palette.COLOURS);
		wipe(Ports.VSRAM_WRITE, 0, 40);

		Psg.reset();
		Fm.reset();
		Z80.reset(false);
		Joy.init();
	}

	public static inline function show():Void {
		Ports.register(1, 0x44);
	}

	public static inline function hide():Void {
		Ports.register(1, 0x04);
	}

	public static function waitVertical():Void {
		while (Ports.inVblank()) {}
		while (!Ports.inVblank()) {}
	}

	static function wipe(code:Int, at:Int, words:Int):Void {
		Ports.autoIncrement(2);
		Ports.address(code, at);

		var left:Int = words;
		while (left > 0) {
			Ports.write(0);
			left--;
		}
	}
}
