package md;

import md.hw.Vdp as Ports;
import md.hw.Cpu;
import md.hw.Z80;

class Boot {
	public static inline final PLANE_A = 0xE000;

	public static inline final PLANE_B = 0xC000;

	public static inline final WINDOW = 0xD000;

	public static inline final SPRITES = 0xF400;

	public static inline final SCROLL = 0xF000;

	public static function begin():Void {
		while ((Ports.status() & Ports.DMA_BUSY) != 0) {}

		Vdp.setRegister(0, 0x04);
		Vdp.setRegister(1, 0x04);
		Vdp.setRegister(6, 0x00);
		Vdp.setRegister(7, 0x00);
		Vdp.setRegister(8, 0x00);
		Vdp.setRegister(9, 0x00);
		Vdp.setRegister(10, 0x01);
		Vdp.setRegister(11, 0x00);
		Vdp.setRegister(12, 0x81);
		Vdp.setRegister(14, 0x00);
		Vdp.setRegister(15, 0x02);
		Vdp.setRegister(17, 0x00);
		Vdp.setRegister(18, 0x00);

		Vdp.setScrollTable(SCROLL);
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
		Vdp.setEnable(true);
	}

	public static inline function hide():Void {
		Vdp.setEnable(false);
	}

	public static function listen():Void {
		Vdp.setVerticalInterrupt(true);
		Cpu.enableInterrupts();
	}

	public static function deafen():Void {
		Cpu.disableInterrupts();
		Vdp.setVerticalInterrupt(false);
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
