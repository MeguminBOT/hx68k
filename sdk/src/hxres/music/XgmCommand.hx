package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;

class XgmCommand {
	public static inline final FRAME = 0x00;
	public static inline final PSG = 0x10;
	public static inline final YM2612_PORT0 = 0x20;
	public static inline final YM2612_PORT1 = 0x30;
	public static inline final YM2612_REGKEY = 0x40;
	public static inline final PCM = 0x50;
	public static inline final LOOP = 0x7E;
	public static inline final END = 0x7F;

	public var data:Bytes;
	public var offset:Int;
	public var command:Int;
	public var size:Int;

	public function new(data:Bytes, size:Int) {
		this.data = data;
		this.size = size;
		this.command = data.get(0) & 0xFF;
		this.offset = -1;
	}

	public static function loop(where:Int):XgmCommand {
		final held = Bytes.alloc(4);
		held.set(0, LOOP);
		held.set(1, where & 0xFF);
		held.set(2, (where >> 8) & 0xFF);
		held.set(3, (where >> 16) & 0xFF);
		return new XgmCommand(held, 4);
	}

	public static function frame():XgmCommand {
		final held = Bytes.alloc(1);
		held.set(0, FRAME);
		return new XgmCommand(held, 1);
	}

	public static function end():XgmCommand {
		final held = Bytes.alloc(1);
		held.set(0, END);
		return new XgmCommand(held, 1);
	}

	public static function raw(command:Int, data:Bytes, size:Int):XgmCommand {
		final out = new XgmCommand(data, size);
		out.command = command;
		return out;
	}

	public function type():Int {
		if (command == FRAME) return FRAME;
		if (command == LOOP) return LOOP;
		if (command == END) return END;
		return command & 0xF0;
	}

	public inline function isFrame():Bool return command == FRAME;

	public inline function isLoop():Bool return command == LOOP;

	public inline function isEnd():Bool return command == END;

	public static function keyWrites(from:Array<VgmCommand>):Array<XgmCommand> {
		return chunked(from, 16, 1, function(held:Bytes, at:Int, source:VgmCommand):Int {
			held.set(at, source.ymValue());
			return at + 1;
		}, YM2612_REGKEY);
	}

	public static function port0Writes(from:Array<VgmCommand>):Array<XgmCommand> {
		return chunked(from, 16, 2, register, YM2612_PORT0);
	}

	public static function port1Writes(from:Array<VgmCommand>):Array<XgmCommand> {
		return chunked(from, 16, 2, register, YM2612_PORT1);
	}

	public static function psgWrites(from:Array<VgmCommand>):Array<XgmCommand> {
		return chunked(from, 16, 1, function(held:Bytes, at:Int, source:VgmCommand):Int {
			held.set(at, source.psgValue());
			return at + 1;
		}, PSG);
	}

	public inline function isPsgWrite():Bool return (command & 0xF0) == PSG;

	public inline function isPort0Write():Bool return (command & 0xF0) == YM2612_PORT0;

	public inline function isPort1Write():Bool return (command & 0xF0) == YM2612_PORT1;

	public inline function isYmWrite():Bool return isPort0Write() || isPort1Write();

	public inline function isRegKeyWrite():Bool return (command & 0xF0) == YM2612_REGKEY;

	public inline function writeCount():Int return (data.get(0) & 0x0F) + 1;

	public function withoutRegister(register:Int):XgmCommand {
		final count:Int = writeCount();
		final held = Bytes.alloc((count * 2) + 1);
		var at:Int = 1;

		for (step in 0...count) {
			final which:Int = data.get((step * 2) + 1) & 0xFF;
			if (which == register) continue;
			held.set(at, which);
			held.set(at + 1, data.get((step * 2) + 2) & 0xFF);
			at += 2;
		}

		final kept:Int = Std.int(at / 2);
		if (kept == count) return this;
		if (kept == 0) return null;

		held.set(0, (data.get(0) & 0xF0) | (kept - 1));
		return new XgmCommand(held.sub(0, (kept * 2) + 1), (kept * 2) + 1);
	}

	static function register(held:Bytes, at:Int, source:VgmCommand):Int {
		held.set(at, source.ymRegister());
		held.set(at + 1, source.ymValue());
		return at + 2;
	}

	static function chunked(from:Array<VgmCommand>, most:Int, each:Int,
			write:Bytes->Int->VgmCommand->Int, kind:Int):Array<XgmCommand> {
		final out = new Array<XgmCommand>();
		var index:Int = 0;

		while (index < from.length) {
			final taken:Int = from.length - index < most ? from.length - index : most;
			final held = Bytes.alloc((taken * each) + 1);
			held.set(0, kind | (taken - 1));

			var at:Int = 1;
			for (step in 0...taken) at = write(held, at, from[index + step]);

			out.push(new XgmCommand(held, (taken * each) + 1));
			index += taken;
		}

		return out;
	}
}
#end
