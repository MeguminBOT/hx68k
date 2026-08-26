package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

class Vgm {
	public var commands:Array<VgmCommand>;
	public var sampleBanks:Array<SampleBank>;
	public var version:Int;
	public var offsetStart:Int;
	public var offsetEnd:Int;
	public var lenInSample:Int;
	public var loopStart:Int;
	public var loopLenInSample:Int;
	public var rate:Int;

	final data:Bytes;
	final offset:Int;

	public function new(data:Bytes, offset:Int) {
		if (data.getString(offset, 4) != "Vgm ")
			throw new haxe.Exception("Not a VGM file: the first four bytes are not 'Vgm '.");

		this.data = data;
		this.offset = offset;

		version = data.get(offset + 8) & 0xFF;

		offsetStart = version >= 0x50 ? LittleEndian.int32(data, offset + 0x34) + (offset + 0x34)
			: offset + 0x40;
		offsetEnd = LittleEndian.int32(data, offset + 0x04) + (offset + 0x04);
		lenInSample = LittleEndian.int32(data, offset + 0x18);

		loopStart = LittleEndian.int32(data, offset + 0x1C);
		if (loopStart != 0) loopStart += offset + 0x1C;
		loopLenInSample = LittleEndian.int32(data, offset + 0x20);

		rate = LittleEndian.int32(data, offset + 0x24);
		if (rate != 50) rate = 60;

		if (LittleEndian.int32(data, offset + 0x14) != 0)
			throw new haxe.Exception("This VGM carries GD3 tags, which hxres does not read yet.");

		commands = [];
		sampleBanks = [];
		parse();

		for (command in commands) {
			if (command.isDataBlock() || command.isStream())
				throw new haxe.Exception("This VGM carries PCM data blocks or stream commands, "
					+ "which hxres does not convert yet.");
		}
	}

	function parse():Void {
		var time:Int = 0;
		var loopTimeStart:Int = -1;
		var at:Int = offsetStart;

		while (at < offsetEnd) {
			if (loopTimeStart == -1 && loopStart != 0 && at >= loopStart) {
				commands.push(VgmCommand.made(VgmCommand.LOOP_START, time));
				loopTimeStart = time;
			}

			final command = VgmCommand.read(data, at, time);
			time += command.waitValue();
			at += command.size;

			if (!command.isEnd()) commands.push(command);

			if (loopTimeStart >= 0 && loopLenInSample != 0
				&& (time - loopTimeStart) > loopLenInSample) {
				commands.push(VgmCommand.made(VgmCommand.LOOP_END, time));
				loopTimeStart = -2;
			}

			if (command.isEnd()) break;
		}

		if (loopTimeStart >= 0 && loopLenInSample != 0) {
			final delta:Int = loopLenInSample - (time - loopTimeStart);

			if (delta > Std.int(44100 / 100)) {
				commands.push(VgmCommand.made(rate == 60 ? VgmCommand.WAIT_NTSC_FRAME
					: VgmCommand.WAIT_PAL_FRAME, time));
				time += rate == 60 ? Std.int(44100 / 60) : Std.int(44100 / 50);
			}

			commands.push(VgmCommand.made(VgmCommand.LOOP_END, time));
			loopTimeStart = -2;
		}

		commands.push(VgmCommand.made(VgmCommand.END, time));
	}

	public function computeLenFrom(from:VgmCommand):Int {
		var out:Int = 0;
		var counting:Bool = from == null;

		for (command in commands) {
			if (command == from) counting = true;
			if (counting) out += command.waitValue();
		}
		return out;
	}

	public inline function computeLen():Int {
		return computeLenFrom(null);
	}

	public function timeOf(wanted:VgmCommand):Int {
		var out:Int = 0;
		for (command in commands) {
			if (command == wanted) return out;
			out += command.waitValue();
		}
		return 0;
	}

	public inline function frameOf(wanted:VgmCommand):Int {
		return Std.int(timeOf(wanted) / Std.int(44100 / rate));
	}

	public function convertWaits():Void {
		final out = new Array<VgmCommand>();
		final limit:Float = 44100 / rate;
		final minLimit:Float = limit - ((limit * 15) / 100);
		final waitCommand:Int = rate == 60 ? VgmCommand.WAIT_NTSC_FRAME : VgmCommand.WAIT_PAL_FRAME;

		var held:Float = 0;
		var time:Int = 0;

		for (command in commands) {
			final wait:Int = command.waitValue();
			var stamp:Int = time;

			if (!command.isWait()) out.push(command);
			else held += wait;

			while (held > minLimit) {
				out.push(VgmCommand.made(waitCommand, stamp));
				held -= limit;
				stamp = Std.int(stamp + limit);
			}

			time += wait;
		}

		commands = out;
	}

	public function cleanCommands():Void {
		final out = new Array<VgmCommand>();

		var ymOld = new Ym2612();
		var psgOld = new Psg();

		var start:Int = 0;
		var end:Int = 0;
		var command:VgmCommand = null;

		do {
			end = start;
			do {
				command = commands[end];
				end++;
			} while (end < commands.length && !command.isWait() && !command.isEnd());

			final psgState = psgOld.copy();
			var ymState = ymOld.copy();

			final optimized = new Array<VgmCommand>();
			var keyOnOff = new Array<VgmCommand>();
			final ymMerged = new Array<VgmCommand>();
			final last = new Array<VgmCommand>();
			var hasKeyCommand:Bool = false;

			for (index in start...end) {
				final held = commands[index];

				if (held.isDataBlock() || held.isStream() || held.isLoopStart()
					|| held.isLoopEnd()) {
					optimized.push(held);
					if (held.isLoopStart()) {
						ymOld = new Ym2612();
						psgOld = new Psg();
					}
				} else if (held.isPsgWrite()) {
					psgState.write(held.psgValue());
				} else if (held.isYmWrite()) {
					if (held.isYmKeyWrite()) {
						keyOnOff.push(held);
						hasKeyCommand = true;
					} else if (hasKeyCommand) {
						for (c in ymOld.delta(ymState)) ymMerged.push(c);
						for (c in keyOnOff) ymMerged.push(c);
						keyOnOff = [];

						ymOld = ymState;
						ymState = ymOld.copy();
						hasKeyCommand = false;
					}

					ymState.set(held.ymPort(), held.ymRegister(), held.ymValue());
				} else if (held.isWait() || held.isSeek()) {
					last.push(held);
				}
			}

			var hasStreamStart:Bool = false;
			var hasStreamRate:Bool = false;
			var back:Int = optimized.length - 1;
			while (back >= 0) {
				final held = optimized[back];
				if (held.isStreamStartLong()) {
					if (hasStreamStart) optimized.splice(back, 1);
					hasStreamStart = true;
				} else if (held.isStreamFrequency()) {
					if (hasStreamRate) optimized.splice(back, 1);
					hasStreamRate = true;
				}
				back--;
			}

			for (c in ymMerged) optimized.push(c);
			for (c in ymOld.delta(ymState)) optimized.push(c);
			for (c in keyOnOff) optimized.push(c);
			for (c in psgOld.delta(psgState)) optimized.push(c);
			for (c in last) optimized.push(c);

			for (c in optimized) out.push(c);

			ymOld = ymState;
			psgOld = psgState;
			start = end;
		} while (end < commands.length && !command.isEnd());

		out.push(VgmCommand.made(VgmCommand.END, -1));
		commands = out;
	}

	public function cleanSamples():Void {
		for (bank in sampleBanks) {
			var index:Int = bank.samples.length - 1;
			while (index >= 0) {
				if (!bank.isUsedBy(commands, bank.samples[index])) bank.samples.splice(index, 1);
				index--;
			}
		}
	}

	public function fixKeyCommands():Void {
		final maxDelta:Int = Std.int(Std.int(44100 / rate) / 4);
		final keyOffTime = [for (_ in 0...6) -1];
		final keyOnTime = [for (_ in 0...6) -1];
		var delayed = new Array<VgmCommand>();

		var index:Int = 0;
		while (index < commands.length) {
			final command = commands[index];

			if (command.isWait()) {
				if (delayed.length > 0) {
					for (offset in 0...delayed.length) commands.insert(index + 1 + offset, delayed[offset]);
					index += delayed.length;
					delayed = [];
				}

				for (channel in 0...6) {
					keyOffTime[channel] = -1;
					keyOnTime[channel] = -1;
				}
			} else if (command.isYmKeyWrite()) {
				final channel:Int = command.ymKeyChannel();

				if (channel != -1) {
					if (command.isYmKeyOffWrite()) {
						keyOffTime[channel] = command.time;

						if (keyOnTime[channel] != -1 && command.time != -1
							&& (command.time - keyOnTime[channel]) > maxDelta) {
							commands.splice(index, 1);
							index--;
							if (!holdsKeyOff(delayed, channel)) delayed.push(command);
						}
					} else {
						keyOnTime[channel] = command.time;
					}
				}
			}

			index++;
		}
	}

	static function holdsKeyOff(list:Array<VgmCommand>, channel:Int):Bool {
		for (command in list)
			if (command.isYmKeyOffWrite() && command.ymKeyChannel() == channel) return true;
		return false;
	}

	public function bytes():Bytes {
		final head = Bytes.alloc(0x80);
		head.blit(0, Bytes.ofString("Vgm "), 0, 4);
		head.set(0x08, 0x60);
		head.set(0x09, 0x01);
		LittleEndian.setInt32(head, 0x0C, 0x00369E99);
		head.set(0x24, rate);
		head.set(0x28, 0x09);
		head.set(0x2A, 0x10);
		LittleEndian.setInt32(head, 0x2C, 0x00750AB5);
		LittleEndian.setInt32(head, 0x34, 0x4C);

		final body = new BytesBuffer();
		var loopCommand:VgmCommand = null;
		var loopOffset:Int = 0;

		for (command in commands) {
			if (command.isLoopStart()) {
				loopCommand = command;
				loopOffset = (0x80 + body.length) - 0x1C;
			} else if (!command.isLoopEnd()) {
				body.add(command.bytes());
			}
		}

		final out = Bytes.alloc(0x80 + body.length);
		out.blit(0, head, 0, 0x80);
		out.blit(0x80, body.getBytes(), 0, out.length - 0x80);

		if (loopCommand != null) {
			LittleEndian.setInt32(out, 0x1C, loopOffset);
			LittleEndian.setInt32(out, 0x20, computeLenFrom(loopCommand));
		}

		LittleEndian.setInt32(out, 0x04, out.length - 4);
		LittleEndian.setInt32(out, 0x18, computeLen() - 1);

		return out;
	}
}
#end
