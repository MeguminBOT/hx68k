package;

@:md.pool(4)
class Node {
	public var value:Int;
	public var next:Node;

	public function new(v:Int) {
		value = v;
		next = null;
	}
}
