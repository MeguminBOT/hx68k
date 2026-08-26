package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

class Picture {
	public final width:Int;
	public final height:Int;
	public final bits:Int;
	public final indexes:Null<Bytes>;
	public final colours:Null<Array<Int>>;
	public final palette:Null<Array<Int>>;
	public final declared:Int;

	public function new(width:Int, height:Int, bits:Int, indexes:Null<Bytes>, colours:Null<Array<Int>>,
			palette:Null<Array<Int>>, declared:Int) {
		this.width = width;
		this.height = height;
		this.bits = bits;
		this.indexes = indexes;
		this.colours = colours;
		this.palette = palette;
		this.declared = declared;
	}

	public inline function indexed():Bool {
		return indexes != null;
	}

	public function entries(mask:Int):Array<Int> {
		if (palette == null) throw new haxe.Exception("A true colour image has no palette of its own.");

		final out = new Array<Int>();
		for (colour in palette) {
			final a = (colour >> 28) & 0xF;
			final b = (colour >> 20) & 0xF;
			final g = (colour >> 12) & 0xF;
			final r = (colour >> 4) & 0xF;
			out.push(((a << 12) | (b << 8) | (g << 4) | r) & mask);
		}
		return out;
	}
}
#end
