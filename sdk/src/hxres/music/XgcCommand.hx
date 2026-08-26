package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;

class XgcCommand {
	public static inline final PSG_TONE = 0x10;
	public static inline final PSG_ENV = 0x18;
	public static inline final PCM = 0x50;
	public static inline final STATE = 0x60;
	public static inline final FRAME_SKIP = 0x7D;
	public static inline final FRAME_SIZE = 1;

	public static function frameSize(size:Int):XgmCommand {
		final held = Bytes.alloc(1);
		held.set(0, size & 0xFF);
		return XgmCommand.raw(FRAME_SIZE, held, 1);
	}

	public static function frameSkip():XgmCommand {
		final held = Bytes.alloc(1);
		held.set(0, FRAME_SKIP);
		return new XgmCommand(held, 1);
	}

	public static inline function isFrameSize(command:XgmCommand):Bool {
		return command.command == FRAME_SIZE;
	}

	public static function setFrameSize(command:XgmCommand, value:Int):Void {
		command.data.set(0, value & 0xFF);
	}

	public static function convert(from:Array<XgmCommand>):Array<XgmCommand> {
		final out = new Array<XgmCommand>();
		for (command in from) for (made in convertSingle(command)) out.push(made);
		return out;
	}

	public static function convertSingle(command:XgmCommand):Array<XgmCommand> {
		final out = new Array<XgmCommand>();

		switch (command.type()) {
			case XgmCommand.PSG:
				final envelope = new Array<Int>();
				final tone = new Array<Int>();
				final count:Int = (command.data.get(0) & 0xF) + 1;

				for (step in 0...count) {
					final value:Int = command.data.get(step + 1) & 0xFF;
					if ((value & 0x91) == 0x91) envelope.push(value);
					else tone.push(value);
				}

				if (envelope.length > 0) for (c in chunked(envelope, 4, PSG_ENV)) out.push(c);
				if (tone.length > 0) for (c in chunked(tone, 8, PSG_TONE)) out.push(c);

			case XgmCommand.YM2612_REGKEY:
				final values = new Array<Int>();
				final count:Int = (command.data.get(0) & 0xF) + 1;
				for (step in 0...count) values.push(command.data.get(step + 1) & 0xFF);
				for (c in chunked(values, 6, XgmCommand.YM2612_REGKEY)) out.push(c);

			case _:
				out.push(command);
		}

		return out;
	}

	public static function stateCommands(state:Array<Int>):Array<XgmCommand> {
		final out = new Array<XgmCommand>();
		var index:Int = 0;

		while (index < state.length) {
			final pairs:Int = Std.int((state.length - index) / 2);
			final taken:Int = pairs < 16 ? pairs : 16;
			final held = Bytes.alloc((taken * 2) + 1);
			held.set(0, STATE | (taken - 1));

			for (step in 0...taken) {
				held.set((step * 2) + 1, state[index + (step * 2)] & 0xFF);
				held.set((step * 2) + 2, state[index + (step * 2) + 1] & 0xFF);
			}

			out.push(new XgmCommand(held, (taken * 2) + 1));
			index += taken * 2;
		}

		return out;
	}

	static function chunked(values:Array<Int>, most:Int, kind:Int):Array<XgmCommand> {
		final out = new Array<XgmCommand>();
		var index:Int = 0;

		while (index < values.length) {
			final left:Int = values.length - index;
			final taken:Int = left < most ? left : most;
			final held = Bytes.alloc(taken + 1);
			held.set(0, kind | (taken - 1));
			for (step in 0...taken) held.set(step + 1, values[index + step] & 0xFF);
			out.push(new XgmCommand(held, taken + 1));
			index += taken;
		}

		return out;
	}
}
#end
