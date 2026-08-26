package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;

class LittleEndian {
	public static inline function int16(data:Bytes, offset:Int):Int {
		return (data.get(offset) & 0xFF) | ((data.get(offset + 1) & 0xFF) << 8);
	}

	public static inline function int24(data:Bytes, offset:Int):Int {
		return int16(data, offset) | ((data.get(offset + 2) & 0xFF) << 16);
	}

	public static inline function int32(data:Bytes, offset:Int):Int {
		return int24(data, offset) | ((data.get(offset + 3) & 0xFF) << 24);
	}

	public static inline function setInt16(data:Bytes, offset:Int, value:Int):Void {
		data.set(offset, value & 0xFF);
		data.set(offset + 1, (value >> 8) & 0xFF);
	}

	public static inline function setInt24(data:Bytes, offset:Int, value:Int):Void {
		setInt16(data, offset, value);
		data.set(offset + 2, (value >> 16) & 0xFF);
	}

	public static inline function setInt32(data:Bytes, offset:Int, value:Int):Void {
		setInt24(data, offset, value);
		data.set(offset + 3, (value >> 24) & 0xFF);
	}
}
#end
