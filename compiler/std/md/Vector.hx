package md;

extern class VectorData<T> {}

extern class VectorTools {
	static function length<T>(v:VectorData<T>):Int;
	static function get<T>(v:VectorData<T>, index:Int):T;
	static function set<T>(v:VectorData<T>, index:Int, value:T):T;
}

abstract Vector<T>(VectorData<T>) {
	public var length(get, never):Int;

	extern inline function get_length():Int {
		return VectorTools.length(this);
	}

	@:arrayAccess extern inline function get(index:Int):T {
		return VectorTools.get(this, index);
	}

	@:arrayAccess extern inline function set(index:Int, value:T):T {
		return VectorTools.set(this, index, value);
	}
}
