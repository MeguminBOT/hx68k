package md;

extern class Pool {
	static function free<T>(value:T):Void;
	static function reset<T>(cls:Class<T>):Void;
	static function live<T>(cls:Class<T>):Int;
}
