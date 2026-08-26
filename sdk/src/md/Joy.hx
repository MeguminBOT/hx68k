package md;

import md.hw.Joypad as Port;

class Joy {
	public static inline final PORTS = 3;

	public static inline final UP = 0x0001;

	public static inline final DOWN = 0x0002;

	public static inline final LEFT = 0x0004;

	public static inline final RIGHT = 0x0008;

	public static inline final B = 0x0010;

	public static inline final C = 0x0020;

	public static inline final A = 0x0040;

	public static inline final START = 0x0080;

	public static inline final DIRECTIONS = 0x000F;

	public static inline final BUTTONS = 0x00F0;

	public static inline final PORT_PAD = 0x0D;

	public static inline final PORT_NOTHING = 0x0F;

	public static inline final PAD_THREE_BUTTON = 0x00;

	public static inline final PAD_NOTHING = 0x0F;

	@:md.size(3) static var held:Vector<UInt16>;

	@:md.size(3) static var before:Vector<UInt16>;

	public static function init():Void {
		var port = 0;

		while (port < PORTS) {
			Port.open(port);
			held[port] = 0;
			before[port] = 0;
			port++;
		}
	}

	public static function update():Void {
		var port = 0;

		while (port < PORTS) {
			before[port] = held[port];
			held[port] = Port.read(port);
			port++;
		}
	}

	public static inline function read(port:UInt16):UInt16 {
		return held[port];
	}

	public static inline function pressed(port:UInt16):UInt16 {
		return held[port] & ~before[port];
	}

	public static inline function released(port:UInt16):UInt16 {
		return before[port] & ~held[port];
	}

	public static inline function now(port:UInt16):UInt16 {
		return Port.read(port);
	}

	public static inline function portType(port:UInt16):UInt8 {
		return Port.identify(port) == 0 ? PORT_PAD : PORT_NOTHING;
	}

	public static inline function padType(port:UInt16):UInt8 {
		return Port.identify(port) == 0 ? PAD_THREE_BUTTON : PAD_NOTHING;
	}
}
