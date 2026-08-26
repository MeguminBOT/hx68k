package hxres;

#if (macro || md_runtime)
import hxres.Sprite.Aim;
class Grid {
	final slots:Array<Array<Null<Sprite>>>;
	final offsetX:Int;
	final offsetY:Int;
	final across:Int;
	final down:Int;

	public function new(offsetX:Int, offsetY:Int, across:Int, down:Int) {
		this.offsetX = offsetX;
		this.offsetY = offsetY;
		this.across = across;
		this.down = down;

		slots = new Array<Array<Null<Sprite>>>();
		for (_ in 0...down) {
			final row = new Array<Null<Sprite>>();
			for (_ in 0...across) row.push(null);
			slots.push(row);
		}
	}

	public inline function set(x:Int, y:Int, value:Sprite):Void {
		slots[y][x] = value;
	}

	public function used(x:Int, y:Int, fused:Bool):Bool {
		if (x < 0 || y < 0) return false;
		if (y >= down || x >= across) return false;
		final slot = slots[y][x];
		return slot != null && (fused || slot.single());
	}

	public function occupied():Int {
		var count = 0;
		for (row in slots) for (slot in row) if (slot != null) count++;
		return count;
	}

	public function merge(aim:Aim):Void {
		for (j in 0...down) {
			for (i in 0...across) {
				final slot = slots[j][i];
				if (slot != null && slot.single()) mergeAt(i, j, aim);
			}
		}
	}

	public function sprites():Array<Sprite> {
		final seen = new Array<Sprite>();
		for (j in 0...down) {
			for (i in 0...across) {
				final slot = slots[j][i];
				if (slot != null) seen.push(slot);
			}
		}
		return HashOrder.of(seen, sprite -> sprite.rect);
	}

	function mergeAt(x:Int, y:Int, aim:Aim):Void {
		var wide = 1;
		while (wide < 4 && used(x + wide, y, false)) wide++;

		var tall = 1;
		while (tall < 4) {
			var whole = true;
			for (i in 0...wide) if (!used(x + i, y + tall, false)) {
				whole = false;
				break;
			}
			if (!whole) break;

			if (wide != 4 && (used(x - 1, y + tall, false) || used(x + wide, y + tall, false))) break;

			tall++;
		}

		if (wide <= 1 && tall <= 1) return;

		final merged = Sprite.sized(offsetX + (x * 8), offsetY + (y * 8), wide * 8, tall * 8, aim);
		for (j in y...y + tall) for (i in x...x + wide) slots[j][i] = merged;
	}
}
#end
