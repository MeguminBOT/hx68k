package md;

class Copy {
	@:md.body("	if(count <= 0) return into;

	__asm__ __volatile__ (
		\"1:\\n\\tmove.w (%1)+,(%0)+\\n\\tsubq.w #1,%2\\n\\tbne.s 1b\"
		: \"+a\" (into), \"+a\" (from), \"+d\" (count)
		:
		: \"memory\", \"cc\"
	);

	return into;")
	public static function words(into:Int, from:Int, count:Int):Int {
		return 0;
	}

	@:md.body("	if(count <= 0) return into;

	__asm__ __volatile__ (
		\"1:\\n\\tmove.b (%1)+,(%0)+\\n\\tsubq.w #1,%2\\n\\tbne.s 1b\"
		: \"+a\" (into), \"+a\" (from), \"+d\" (count)
		:
		: \"memory\", \"cc\"
	);

	return into;")
	public static function bytes(into:Int, from:Int, count:Int):Int {
		return 0;
	}
}
