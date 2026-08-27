package md;

import md.hw.Joypad as Ports;

class Pads {
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

	@:md.size(3) static var latest:Vector<UInt16>;

	@:md.size(3) static var previous:Vector<UInt16>;

	public static function init():Void {
		var port = 0;

		while (port < PORTS) {
			Ports.open(port);
			latest[port] = 0;
			previous[port] = 0;
			port++;
		}
	}

	public static function update():Void {
		var port = 0;

		while (port < PORTS) {
			previous[port] = latest[port];
			latest[port] = Ports.read(port);
			port++;
		}
	}

	public static inline function held(port:UInt16):UInt16 {
		return latest[port];
	}

	public static inline function pressed(port:UInt16):UInt16 {
		return latest[port] & ~previous[port];
	}

	public static inline function released(port:UInt16):UInt16 {
		return previous[port] & ~latest[port];
	}

	public static inline function live(port:UInt16):UInt16 {
		return Ports.read(port);
	}

	public static inline function portType(port:UInt16):PortType {
		return Ports.identify(port) == 0 ? PortType.Pad : PortType.Nothing;
	}

	public static inline function padType(port:UInt16):PadType {
		return Ports.identify(port) == 0 ? PadType.ThreeButton : PadType.Nothing;
	}
}
