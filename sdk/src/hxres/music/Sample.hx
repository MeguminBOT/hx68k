package hxres.music;

#if (macro || md_runtime)
class Sample {
	public var id:Int;
	public var dataOffset:Int;
	public var len:Int;
	public var rate:Int;

	public function new(id:Int, dataOffset:Int, len:Int, rate:Int) {
		this.id = id;
		this.dataOffset = dataOffset;
		this.len = len;
		this.rate = rate;
	}

	public inline function frameSize():Int {
		return Std.int(rate / 60);
	}
}
#end
