package md;

import md.hw.Vdp as Ports;
import md.hw.Cpu;
import md.hw.Z80;

class Boot {
	public static function begin():Void {
		Dma.wait();

		Vdp.setRegister(0, 0x04);
		Vdp.setRegister(1, 0x14);
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

		Vdp.setScrollTable(Vdp.DEFAULT_SCROLL);
		Tilemap.setBase(Plane.A, Tilemap.DEFAULT_A);
		Tilemap.setBase(Plane.B, Tilemap.DEFAULT_B);
		Tilemap.setBase(Plane.Window, Tilemap.DEFAULT_WINDOW);
		Tilemap.setPlaneSize(64, 32);
		SpriteTable.setBase(SpriteTable.DEFAULT_AT);

		Dma.fillVram(0, 0x8000, 0, 1);
		Dma.wait();
		Dma.fillVram(0x8000, 0x8000, 0, 1);
		Dma.wait();

		wipe(Ports.CRAM_WRITE, 0, Palette.COLORS);
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
