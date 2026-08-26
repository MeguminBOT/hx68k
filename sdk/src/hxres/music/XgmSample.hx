package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;

class XgmSample {
	public var index:Int;
	public var data:Bytes;
	public var originAddress:Int;

	public function new(index:Int, data:Bytes, originAddress:Int) {
		this.index = index;
		this.data = data;
		this.originAddress = originAddress;
	}

	public static function fromBank(bank:SampleBank, sample:Sample):XgmSample {
		throw new haxe.Exception("hxres does not extract PCM samples from a VGM yet.");
	}
}
#end
