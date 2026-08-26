package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

class Xgm {
	public var commands:Array<XgmCommand>;
	public var samples:Array<XgmSample>;
	public var pal:Int;

	public function new(from:Vgm) {
		commands = [];
		samples = [];
		pal = from.rate == 60 ? 0 : (from.rate == 50 ? 1 : -1);

		extractSamples(from);
		extractMusic(from);
		computeAllOffset();
	}

	function extractSamples(from:Vgm):Void {
		var index:Int = samples.length + 1;

		for (bank in from.sampleBanks) {
			for (sample in bank.samples) {
				if (index >= 64) break;
				final made = XgmSample.fromBank(bank, sample);
				if (made == null) continue;
				made.index = index++;
				samples.push(made);
			}
		}
	}

	function extractMusic(from:Vgm):Void {
		var loopOffset:Int = -1;
		var index:Int = 0;

		while (index < from.commands.length) {
			final frameCommands = new Array<VgmCommand>();
			var loopEnd:Bool = false;

			while (index < from.commands.length) {
				final command = from.commands[index];
				index++;

				if (command.isDataBlock()) continue;

				if (command.isLoopStart()) {
					if (loopOffset == -1) loopOffset = musicDataSize();
					continue;
				}
				if (command.isLoopEnd()) {
					loopEnd = true;
					continue;
				}
				if (command.isWait()) {
					if (pal == -1) {
						if (command.isWaitPal()) pal = 1;
						else if (command.isWaitNtsc()) pal = 0;
					}
					break;
				}
				if (command.isEnd()) break;

				frameCommands.push(command);
			}

			final made = new Array<XgmCommand>();
			var keyCommands = new Array<VgmCommand>();
			var port0Commands = new Array<VgmCommand>();
			var port1Commands = new Array<VgmCommand>();
			final psgCommands = new Array<VgmCommand>();
			final sampleCommands = new Array<VgmCommand>();
			var hasKeyCommand:Bool = false;

			for (command in frameCommands) {
				if (command.isStream()) {
					sampleCommands.push(command);
				} else if (command.isPsgWrite()) {
					psgCommands.push(command);
				} else if (command.isYmKeyWrite()) {
					keyCommands.push(command);
					hasKeyCommand = true;
				} else if (command.isYmWrite()) {
					if (hasKeyCommand) {
						if (port0Commands.length > 0)
							for (c in XgmCommand.port0Writes(port0Commands)) made.push(c);
						if (port1Commands.length > 0)
							for (c in XgmCommand.port1Writes(port1Commands)) made.push(c);
						if (keyCommands.length > 0)
							for (c in XgmCommand.keyWrites(keyCommands)) made.push(c);

						port0Commands = [];
						port1Commands = [];
						keyCommands = [];
						hasKeyCommand = false;
					}

					if (command.isYmPort0Write()) port0Commands.push(command);
					else port1Commands.push(command);
				}
			}

			if (port0Commands.length > 0)
				for (c in XgmCommand.port0Writes(port0Commands)) made.push(c);
			if (port1Commands.length > 0)
				for (c in XgmCommand.port1Writes(port1Commands)) made.push(c);
			if (keyCommands.length > 0)
				for (c in XgmCommand.keyWrites(keyCommands)) made.push(c);
			if (psgCommands.length > 0)
				for (c in XgmCommand.psgWrites(psgCommands)) made.push(c);
			if (sampleCommands.length > 0)
				throw new haxe.Exception("This VGM plays PCM, which hxres does not convert yet.");

			if (loopEnd && loopOffset != -1) {
				made.push(XgmCommand.loop(loopOffset));
				loopOffset = -1;
			}

			if (index >= from.commands.length) {
				if (loopOffset != -1) {
					made.push(XgmCommand.loop(loopOffset));
					loopOffset = -1;
				}
				made.push(XgmCommand.end());
			} else {
				made.push(XgmCommand.frame());
			}

			for (c in made) commands.push(c);
		}
	}

	public function computeAllOffset():Void {
		var offset:Int = 0;
		for (command in commands) {
			command.offset = offset;
			offset += command.size;
		}
	}

	public function musicDataSize():Int {
		var out:Int = 0;
		for (command in commands) out += command.size;
		return out;
	}

	public function sampleDataSize():Int {
		var out:Int = 0;
		for (sample in samples) out += sample.data.length;
		return out;
	}

	public function bytes():Bytes {
		final out = new BytesBuffer();
		out.add(Bytes.ofString("XGM "));

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
			out.addByte(0x00);
			out.addByte(0x00);
		}

		out.addByte((offset >> 8) & 0xFF);
		out.addByte((offset >> 16) & 0xFF);

		if (pal == -1) pal = 0;

		out.addByte(0x01);
		out.addByte(pal != 0 ? 1 : 0);

		for (sample in samples) out.add(sample.data);

		final length:Int = musicDataSize();
		out.addByte(length & 0xFF);
		out.addByte((length >> 8) & 0xFF);
		out.addByte((length >> 16) & 0xFF);
		out.addByte((length >> 24) & 0xFF);

		for (command in commands) out.addBytes(command.data, 0, command.size);

		return out.getBytes();
	}
}
#end
