package md;

import md.hw.Vdp as Ports;

class Tilemap {
	public static inline final DEFAULT_A = 0xE000;

	public static inline final DEFAULT_B = 0xC000;

	public static inline final DEFAULT_WINDOW = 0xD000;

	public static inline final PRIORITY = 0x8000;

	public static inline final FLIP_VERTICAL = 0x1000;

	public static inline final FLIP_HORIZONTAL = 0x0800;

	public static inline final INDEX = 0x07FF;

	static var baseA:UInt16 = DEFAULT_A;

	static var baseB:UInt16 = DEFAULT_B;

	static var baseWindow:UInt16 = DEFAULT_WINDOW;

	static var planeColumns:UInt16 = 64;

	static var planeRows:UInt16 = 32;

	static var planeShift:UInt16 = 6;

	static var windowColumns:UInt16 = 64;

	static var windowShift:UInt16 = 6;

	public static inline function entry(index:UInt16, palette:UInt16, priority:Bool,
			flipHorizontal:Bool, flipVertical:Bool):UInt16 {
		return (index & INDEX)
			| ((palette & 3) << 13)
			| (priority ? PRIORITY : 0)
			| (flipVertical ? FLIP_VERTICAL : 0)
			| (flipHorizontal ? FLIP_HORIZONTAL : 0);
	}

	public static inline function columns():UInt16 {
		return planeColumns;
	}

	public static inline function rows():UInt16 {
		return planeRows;
	}

	public static inline function windowColumnCount():UInt16 {
		return windowColumns;
	}

	public static function setPlaneSize(width:UInt16, height:UInt16):Void {
		var value = 0;

		if (width >= 128) {
			planeColumns = 128;
			planeShift = 7;
			planeRows = 32;
			value = 0x03;
		} else if (width >= 64) {
			planeColumns = 64;
			planeShift = 6;
			value = 0x01;

			if (height >= 64) {
				planeRows = 64;
				value |= 0x10;
			} else {
				planeRows = 32;
			}
		} else {
			planeColumns = 32;
			planeShift = 5;

			if (height >= 128) {
				planeRows = 128;
				value = 0x30;
			} else if (height >= 64) {
				planeRows = 64;
				value = 0x10;
			} else {
				planeRows = 32;
			}
		}

		Vdp.setRegister(16, value);
	}

	public static function setWindowColumns(count:UInt16):Void {
		if (count >= 64) {
			windowColumns = 64;
			windowShift = 6;
			return;
		}

		windowColumns = 32;
		windowShift = 5;
	}

	public static function setBase(plane:Plane, at:UInt16):Void {
		switch (plane) {
			case Plane.A:
				baseA = at;
				Vdp.setRegister(2, at >> 10);

			case Plane.B:
				baseB = at;
				Vdp.setRegister(4, at >> 13);

			case Plane.Window:
				baseWindow = at;
				Vdp.setRegister(3, at >> 10);
		}
	}

	public static function base(plane:Plane):UInt16 {
		switch (plane) {
			case Plane.B:
				return baseB;

			case Plane.Window:
				return baseWindow;

			case _:
				return baseA;
		}
	}

	public static function address(plane:Plane, x:UInt16, y:UInt16):UInt16 {
		switch (plane) {
			case Plane.B:
				return baseB + (((x & (planeColumns - 1)) + ((y & (planeRows - 1)) << planeShift)) << 1);

			case Plane.Window:
				return baseWindow + (((x & (windowColumns - 1)) + ((y & 31) << windowShift)) << 1);

			case _:
				return baseA + (((x & (planeColumns - 1)) + ((y & (planeRows - 1)) << planeShift)) << 1);
		}
	}

	public static inline function setCell(plane:Plane, cell:UInt16, x:UInt16, y:UInt16):Void {
		Ports.tilemap(address(plane, x, y), cell);
	}

	public static function cell(plane:Plane, x:UInt16, y:UInt16):UInt16 {
		Ports.address(Ports.VRAM_READ, address(plane, x, y));
		return Ports.read();
	}

	public static function fill(plane:Plane, cell:UInt16, x:UInt16, y:UInt16, width:UInt16,
			height:UInt16):Void {
		Ports.autoIncrement(2);

		final stride:Int = (plane == Plane.Window ? windowColumns : planeColumns) << 1;
		final one:Int = cell;
		final pair:Int = (one << 16) | one;
		var at:Int = address(plane, x, y);
		var row:Int = height;

		while (row > 0) {
			Ports.address(Ports.VRAM_WRITE, at);

			var groups:Int = width >> 3;
			while (groups > 0) {
				Memory.writeU32(Ports.DATA, pair);
				Memory.writeU32(Ports.DATA, pair);
				Memory.writeU32(Ports.DATA, pair);
				Memory.writeU32(Ports.DATA, pair);
				groups--;
			}

			var rest:Int = width & 7;
			while (rest > 0) {
				Ports.write(cell);
				rest--;
			}

			at += stride;
			row--;
		}
	}

	public static function setFromResource(plane:Plane, from:md.res.TileMap, base:UInt16,
			x:UInt16, y:UInt16):Bool {
		if (from.compression != 0) return false;

		final across:Int = from.across;
		final down:Int = from.down;
		final cells = from.data;
		var row:Int = 0;

		while (row < down) {
			Ports.autoIncrement(2);
			Ports.address(Ports.VRAM_WRITE, address(plane, x, y + row));

			final start:Int = row * across;
			var column:Int = 0;
			while (column < across) {
				Ports.write(base + cells[start + column]);
				column++;
			}

			row++;
		}

		return true;
	}

	public static function drawImage(plane:Plane, from:md.res.Image, base:UInt16, x:UInt16,
			y:UInt16):Bool {
		if (!Patterns.setFromResource(base & INDEX, from.tileset)) return false;

		Palette.setFromResource((base >> 9) & 0x30, from.palette);
		return setFromResource(plane, from.tilemap, base, x, y);
	}

	public static function fillIncrementing(plane:Plane, cell:UInt16, x:UInt16, y:UInt16,
			width:UInt16, height:UInt16):Void {
		Ports.autoIncrement(2);

		final stride:Int = (plane == Plane.Window ? windowColumns : planeColumns) << 1;
		var next:Int = cell;
		var at:Int = address(plane, x, y);
		var row:Int = height;

		while (row > 0) {
			Ports.address(Ports.VRAM_WRITE, at);

			var column:Int = width;
			while (column > 0) {
				Ports.write(next);
				next++;
				column--;
			}

			at += stride;
			row--;
		}
	}

	public static inline function clear(plane:Plane, x:UInt16, y:UInt16, width:UInt16,
			height:UInt16):Void {
		fill(plane, 0, x, y, width, height);
	}

	public static function clearPlane(plane:Plane):Void {
		if (plane == Plane.Window) {
			fill(plane, 0, 0, 0, windowColumns, 32);
			return;
		}

		fill(plane, 0, 0, 0, planeColumns, planeRows);
	}

	public static function setRow(plane:Plane, from:Vector<UInt16>, x:UInt16, y:UInt16,
			width:UInt16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.VRAM_WRITE, address(plane, x, y));

		var i:Int = 0;
		while (i < width) {
			Ports.write(from[i]);
			i++;
		}
	}

	public static function setColumn(plane:Plane, from:Vector<UInt16>, x:UInt16, y:UInt16,
			height:UInt16):Void {
		final stride:Int = (plane == Plane.Window ? windowColumns : planeColumns) << 1;
		var at:Int = address(plane, x, y);

		var i:Int = 0;
		while (i < height) {
			Ports.tilemap(at, from[i]);
			at += stride;
			i++;
		}
	}
}
