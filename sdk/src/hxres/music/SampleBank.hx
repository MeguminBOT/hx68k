package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;

class SampleBank {
	public var samples:Array<Sample>;
	public var data:Bytes;
	public var offset:Int;
	public var len:Int;
	public var id:Int;

	public function new(id:Int, data:Bytes, offset:Int, len:Int) {
		this.id = id;
		this.data = data;
		this.offset = offset;
		this.len = len;
		this.samples = [];
	}

	public function sampleByOffset(dataOffset:Int):Sample {
		for (sample in samples) {
			if (dataOffset >= sample.dataOffset && dataOffset < (sample.dataOffset + sample.len))
				return sample;
		}
		return null;
	}

	public function sampleById(wanted:Int):Sample {
		for (sample in samples) if (sample.id == wanted) return sample;
		return null;
	}

	public function isUsedBy(commands:Array<VgmCommand>, sample:Sample):Bool {
		final shortest:Int = sample.len - 50 > 0 ? sample.len - 50 : 0;
		final longest:Int = sample.len + 50;
		var currentBank:Int = -1;

		for (command in commands) {
			if (command.isStreamData()) currentBank = command.streamBankId();
			if (id != currentBank) continue;

			if (command.isStreamStart()) {
				if (sample.id == command.streamBlockId()) return true;
			} else if (command.isStreamStartLong()) {
				final length:Int = command.streamSampleSize();
				if (sample.dataOffset == command.streamSampleAddress() && length >= shortest
					&& length <= longest) return true;
			}
		}

		return false;
	}
}
#end
