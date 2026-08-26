package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

class Xgc {
	public var commands:Array<XgmCommand>;
	public var samples:Array<XgmSample>;
	public var pal:Int;

	public function new(from:Xgm) {
		commands = [];
		samples = from.samples.copy();
		pal = from.pal;

		extractMusic(from);
		shiftSamples();
	}

	function extractMusic(from:Xgm):Void {
		var ymOld:Ym2612 = null;
		var ymState = new Ym2612();

		commands.push(XgcCommand.frameSize(0));
		commands.push(XgcCommand.frameSize(0));
		commands.push(XgcCommand.frameSize(0));

		final loopCommand = loopPointedCommand(from);
		var loopOffset:Int = -1;
		var loopEnd:Bool = false;
		var index:Int = 0;

		while (index < from.commands.length) {
			final frameCommands = new Array<XgmCommand>();

			while (index < from.commands.length) {
				final command = from.commands[index];
				index++;

				if (command == loopCommand && loopOffset == -1) loopOffset = musicDataSize();

				if (command.isEnd()) continue;
				if (command.isLoop()) {
					loopEnd = true;
					continue;
				}
				if (command.isFrame()) break;

				frameCommands.push(command);
			}

			ymOld = ymState;
			ymState = ymOld.copy();

			var sizeCommand = XgcCommand.frameSize(0);
			final made = [sizeCommand];

			var ymOther = new Array<XgmCommand>();
			var ymKey = new Array<XgmCommand>();
			final ymMade = new Array<XgmCommand>();
			final psg = new Array<XgmCommand>();
			final other = new Array<XgmCommand>();
			var hasKeyCommand:Bool = false;

			for (command in frameCommands) {
				if (command.isPsgWrite()) {
					psg.push(command);
				} else if (command.isRegKeyWrite()) {
					ymKey.push(command);
					hasKeyCommand = true;
				} else if (command.isYmWrite()) {
					if (hasKeyCommand) {
						if (ymOther.length > 0)
							for (c in XgcCommand.convert(ymOther)) ymMade.push(c);
						if (ymKey.length > 0) for (c in XgcCommand.convert(ymKey)) ymMade.push(c);
						ymOther = [];
						ymKey = [];
						hasKeyCommand = false;
					}

					final port:Int = command.isPort0Write() ? 0 : 1;
					for (step in 0...command.writeCount()) {
						ymState.set(port, command.data.get((step * 2) + 1) & 0xFF,
							command.data.get((step * 2) + 2) & 0xFF);
					}

					final trimmed = command.isPort0Write() ? command.withoutRegister(0x2B) : command;
					if (trimmed != null) ymOther.push(trimmed);
				} else {
					other.push(command);
				}
			}

			if (ymOther.length > 0) for (c in XgcCommand.convert(ymOther)) ymMade.push(c);
			if (ymKey.length > 0) for (c in XgcCommand.convert(ymKey)) ymMade.push(c);

			if (psg.length > 0) for (c in XgcCommand.convert(psg)) made.push(c);
			for (c in ymMade) made.push(c);
			if (other.length > 0) for (c in XgcCommand.convert(other)) made.push(c);

			final change = stateChange(ymState, ymOld);
			if (change.length > 0) for (c in XgcCommand.stateCommands(change)) made.push(c);

			if (loopEnd && loopOffset != -1) {
				made.push(XgcCommand.frameSkip());
				made.push(XgmCommand.loop(loopOffset));
				loopOffset = -1;
			}

			if (index >= from.commands.length) {
				if (loopOffset != -1) {
					made.push(XgcCommand.frameSkip());
					made.push(XgmCommand.loop(loopOffset));
					loopOffset = -1;
				} else {
					made.push(XgmCommand.end());
				}
			}

			var size:Int = 0;
			var step:Int = 0;
			while (step < made.length) {
				final command = made[step];

				if ((size + command.size) >= 250) {
					made.insert(step, XgcCommand.frameSkip());
					XgcCommand.setFrameSize(sizeCommand, size + 1);
					sizeCommand = XgcCommand.frameSize(0);
					made.insert(step + 1, sizeCommand);
					size = 1;
					step += 2;
					continue;
				}

				size += command.size;
				step++;
			}

			XgcCommand.setFrameSize(sizeCommand, size);

			for (c in made) commands.push(c);
		}

		computeAllOffset();
		computeAllFrameSize();
	}

	function loopPointedCommand(from:Xgm):XgmCommand {
		for (command in from.commands) {
			if (!command.isLoop()) continue;
			final wanted:Int = (command.data.get(1) & 0xFF) | ((command.data.get(2) & 0xFF) << 8)
				| ((command.data.get(3) & 0xFF) << 16);
			for (held in from.commands) if (held.offset == wanted) return held;
			return null;
		}
		return null;
	}

	function shiftSamples():Void {
		var loopCommand:XgmCommand = null;
		for (command in commands) {
			if (command.isLoop()) {
				loopCommand = command;
				break;
			}
		}

		var pointed:XgmCommand = null;
		if (loopCommand != null) {
			final wanted:Int = (loopCommand.data.get(1) & 0xFF)
				| ((loopCommand.data.get(2) & 0xFF) << 8)
				| ((loopCommand.data.get(3) & 0xFF) << 16);
			for (held in commands) if (held.offset == wanted) {
				pointed = held;
				break;
			}
		}

		computeAllOffset();
		computeAllFrameSize();

		if (loopCommand != null && pointed != null) {
			loopCommand.data.set(1, pointed.offset & 0xFF);
			loopCommand.data.set(2, (pointed.offset >> 8) & 0xFF);
			loopCommand.data.set(3, (pointed.offset >> 16) & 0xFF);
		}
	}

	static function stateChange(current:Ym2612, old:Ym2612):Array<Int> {
		final out = new Array<Int>();
		var address:Int = 0x44;

		for (port in 0...2) {
			var register:Int = 0x80;
			while (register < 0x90) {
				if (current.isDiff(old, port, register)) {
					out.push(address);
					out.push(current.get(port, register));
				}

				address++;
				if ((register & 3) == 2) register += 2;
				else register++;
			}
		}

		if (current.isDiff(old, 0, 0x2B)) {
			out.push(0x60);
			out.push(current.get(0, 0x2B));
		}

		return out;
	}

	public function computeAllOffset():Void {
		var offset:Int = 0;
		for (command in commands) {
			command.offset = offset;
			offset += command.size;
		}
	}

	public function computeAllFrameSize():Void {
		var sizeCommand:XgmCommand = null;
		var size:Int = 0;

		for (command in commands) {
			if (XgcCommand.isFrameSize(command)) {
				if (sizeCommand != null) XgcCommand.setFrameSize(sizeCommand, size);
				sizeCommand = command;
				size = 1;
			} else {
				size += command.size;
			}
		}

		if (sizeCommand != null) XgcCommand.setFrameSize(sizeCommand, size);
	}

	public function musicDataSize():Int {
		var out:Int = 0;
		for (command in commands) out += command.size;
		return out;
	}

	public function bytes():Bytes {
		final out = new BytesBuffer();

		var offset:Int = 0;
		for (sample in samples) {
			final length:Int = sample.data.length;
			out.addByte((offset >> 8) & 0xFF);
			out.addByte((offset >> 16) & 0xFF);
			out.addByte((length >> 8) & 0xFF);
			out.addByte((length >> 16) & 0xFF);
			offset += length;
		}
		for (_ in samples.length...0x3F) {
			out.addByte(0xFF);
			out.addByte(0xFF);
			out.addByte(0x01);
			out.addByte(0x00);
		}

		out.addByte((offset >> 8) & 0xFF);
		out.addByte((offset >> 16) & 0xFF);
		out.addByte(0x00);
		out.addByte(pal != 0 ? 1 : 0);

		for (sample in samples) out.add(sample.data);

		final length:Int = musicDataSize();
		out.addByte(length & 0xFF);
		out.addByte((length >> 8) & 0xFF);
		out.addByte((length >> 16) & 0xFF);
		out.addByte((length >> 24) & 0xFF);

		for (command in commands) {
			if (XgcCommand.isFrameSize(command)) {
				out.addBytes(command.data, 0, command.size);
			} else {
				out.addByte((command.data.get(0) << 1) & 0xFF);
				if (command.size > 1) out.addBytes(command.data, 1, command.size - 1);
			}
		}

		return out.getBytes();
	}
}
#end
