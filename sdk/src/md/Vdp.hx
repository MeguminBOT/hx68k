package md;

import md.hw.Vdp as Ports;

class Vdp {
	public static inline final REGISTERS = 24;

	public static inline final MODE = 0;

	public static inline final DISPLAY = 1;

	public static inline final BACKDROP = 7;

	public static inline final HORIZONTAL_COUNT = 10;

	public static inline final SCROLLING = 11;

	public static inline final WIDTH = 12;

	public static inline final INCREMENT = 15;

	public static inline final SHOWING = 0x40;

	public static inline final VERTICAL_INTERRUPT = 0x20;

	public static inline final HORIZONTAL_INTERRUPT = 0x10;

	public static inline final EXTERNAL_INTERRUPT = 0x08;

	public static inline final TALL = 0x08;

	public static inline final WIDE = 0x81;

	@:md.size(24) static var shadow:Vector<UInt8>;

	public static function setRegister(index:UInt16, value:UInt8):Void {
		if (index < REGISTERS) shadow[index] = value;
		Ports.register(index, value);
	}

	public static inline function register(index:UInt16):UInt8 {
		return shadow[index];
	}

	static inline function change(index:UInt16, mask:UInt8, on:Bool):Void {
		final was:Int = shadow[index];
		setRegister(index, on ? was | mask : was & ~mask);
	}

	public static inline function setEnable(on:Bool):Void {
		change(DISPLAY, SHOWING, on);
	}

	public static inline function isEnabled():Bool {
		return (shadow[DISPLAY] & SHOWING) != 0;
	}

	public static inline function setVerticalInterrupt(on:Bool):Void {
		change(DISPLAY, VERTICAL_INTERRUPT, on);
	}

	public static inline function setHorizontalInterrupt(on:Bool):Void {
		change(MODE, HORIZONTAL_INTERRUPT, on);
	}

	public static inline function setExternalInterrupt(on:Bool):Void {
		change(SCROLLING, EXTERNAL_INTERRUPT, on);
	}

	public static inline function setHorizontalInterruptCounter(lines:UInt8):Void {
		setRegister(HORIZONTAL_COUNT, lines);
	}

	public static inline function setBackgroundColour(index:UInt8):Void {
		setRegister(BACKDROP, index & 0x3F);
	}

	public static inline function backgroundColour():UInt8 {
		return shadow[BACKDROP] & 0x3F;
	}

	public static inline function setAutoIncrement(step:UInt8):Void {
		setRegister(INCREMENT, step);
	}

	public static inline function autoIncrement():UInt8 {
		return shadow[INCREMENT];
	}

	public static function setWidth320():Void {
		setRegister(WIDTH, shadow[WIDTH] | WIDE);
		Tilemap.setWindowColumns(64);
	}

	public static function setWidth256():Void {
		setRegister(WIDTH, shadow[WIDTH] & ~WIDE);
		Tilemap.setWindowColumns(32);
	}

	public static inline function width():UInt16 {
		return (shadow[WIDTH] & WIDE) == WIDE ? 320 : 256;
	}

	public static inline function setHeight240(tall:Bool):Void {
		change(DISPLAY, TALL, tall);
	}

	public static inline function height():UInt16 {
		return (shadow[DISPLAY] & TALL) != 0 ? 240 : 224;
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

	public static inline function scrollTable():UInt16 {
		return shadow[13] << 10;
	}

	public static inline function setScrollTable(at:UInt16):Void {
		setRegister(13, at >> 10);
	}

	public static function waitDma():Void {
		while ((Ports.status() & Ports.DMA_BUSY) != 0) {}
	}

	public static function waitFifo():Void {
		while ((Ports.status() & 0x0200) == 0) {}
	}

	public static function waitVBlank():Void {
		while (!Ports.inVblank()) {}
	}

	public static function waitVSync():Void {
		while (Ports.inVblank()) {}
		while (!Ports.inVblank()) {}
	}
}
