package md;

import md.hw.Vdp as Ports;

class Vdp {
	public static inline final REGISTERS = 24;

	public static inline final DEFAULT_SCROLL = 0xF000;

	public static inline final SHOWING = 0x40;

	public static inline final VERTICAL_INTERRUPT = 0x20;

	public static inline final HORIZONTAL_INTERRUPT = 0x10;

	public static inline final EXTERNAL_INTERRUPT = 0x08;

	public static inline final TALL = 0x08;

	public static inline final WIDE = 0x81;

	@:md.size(24) static var shadow:Vector<UInt8>;

	public static function setRegister(index:VdpRegister, value:UInt8):Void {
		if ((index : Int) < REGISTERS) shadow[index] = value;
		Ports.register(index, value);
	}

	public static inline function register(index:VdpRegister):UInt8 {
		return shadow[index];
	}

	static inline function change(index:VdpRegister, mask:UInt8, on:Bool):Void {
		final was:Int = shadow[index];
		setRegister(index, on ? was | mask : was & ~mask);
	}

	public static inline function setEnabled(on:Bool):Void {
		change(VdpRegister.Display, SHOWING, on);
	}

	public static inline function isEnabled():Bool {
		return (shadow[VdpRegister.Display] & SHOWING) != 0;
	}

	public static inline function setVerticalInterrupt(on:Bool):Void {
		change(VdpRegister.Display, VERTICAL_INTERRUPT, on);
	}

	public static inline function setHorizontalInterrupt(on:Bool):Void {
		change(VdpRegister.Mode, HORIZONTAL_INTERRUPT, on);
	}

	public static inline function setExternalInterrupt(on:Bool):Void {
		change(VdpRegister.Scrolling, EXTERNAL_INTERRUPT, on);
	}

	public static inline function setHorizontalInterruptCounter(lines:UInt8):Void {
		setRegister(VdpRegister.HorizontalInterrupt, lines);
	}

	public static inline function setBackgroundColor(index:UInt8):Void {
		setRegister(VdpRegister.Background, index & 0x3F);
	}

	public static inline function backgroundColor():UInt8 {
		return shadow[VdpRegister.Background] & 0x3F;
	}

	public static inline function setAutoIncrement(step:UInt8):Void {
		setRegister(VdpRegister.AutoIncrement, step);
	}

	public static inline function autoIncrement():UInt8 {
		return shadow[VdpRegister.AutoIncrement];
	}

	public static function setWide(on:Bool):Void {
		setRegister(VdpRegister.Width,
			on ? shadow[VdpRegister.Width] | WIDE : shadow[VdpRegister.Width] & ~WIDE);
		Tilemap.setWindowColumns(on ? 64 : 32);
	}

	public static inline function width():UInt16 {
		return (shadow[VdpRegister.Width] & WIDE) == WIDE ? 320 : 256;
	}

	public static inline function setTall(on:Bool):Void {
		change(VdpRegister.Display, TALL, on);
	}

	public static inline function height():UInt16 {
		return (shadow[VdpRegister.Display] & TALL) != 0 ? 240 : 224;
	}

	public static inline function scanline():UInt16 {
		return (Ports.counter() >> 8) & 0xFF;
	}

	public static function setHorizontalScroll(plane:Plane, value:Int16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.VRAM_WRITE, scrollTable() + (plane == Plane.B ? 2 : 0));
		Ports.write(value & 0x3FF);
	}

	public static function setVerticalScroll(plane:Plane, value:Int16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.VSRAM_WRITE, plane == Plane.B ? 2 : 0);
		Ports.write(value & 0x3FF);
	}

	public static inline final COLUMN_SCROLL = 0x04;

	public static inline final SCROLL_MODE = 0x03;

	public static function setHorizontalScrollMode(mode:ScrollMode):Void {
		final was:Int = shadow[VdpRegister.Scrolling];
		setRegister(VdpRegister.Scrolling, (was & ~SCROLL_MODE) | (mode : Int));
	}

	public static inline function horizontalScrollMode():ScrollMode {
		return shadow[VdpRegister.Scrolling] & SCROLL_MODE;
	}

	public static inline function setColumnScroll(on:Bool):Void {
		change(VdpRegister.Scrolling, COLUMN_SCROLL, on);
	}

	public static inline function isColumnScroll():Bool {
		return (shadow[VdpRegister.Scrolling] & COLUMN_SCROLL) != 0;
	}

	public static inline function scrollTable():UInt16 {
		return shadow[VdpRegister.HorizontalScroll] << 10;
	}

	public static inline function setScrollTable(at:UInt16):Void {
		setRegister(VdpRegister.HorizontalScroll, at >> 10);
	}

	public static function waitFifo():Void {
		while ((Ports.status() & 0x0200) == 0) {}
	}

	public static function waitBlanking():Void {
		while (!Ports.inVblank()) {}
	}

	public static function waitFrame():Void {
		if (isEnabled()) {
			while (Ports.inVblank()) {}
			while (!Ports.inVblank()) {}
			return;
		}

		while ((Ports.counter() >> 8) == 0) {}
		while ((Ports.counter() >> 8) != 0) {}
	}
}
