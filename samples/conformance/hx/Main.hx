package;

import md.Debug;
import md.Fix16;
import md.Format;
import md.Int16;
import md.Int8;
import md.Pool;
import md.Probe;
import md.System;
import md.UInt16;
import md.UInt32;
import md.Text;
import md.UInt8;
import md.Vector;

class Main {
	@:md.size(8) static var slots:Vector<Int>;
	@:md.size(16) static var buffer:Vector<UInt8>;
	@:romData([3, 1, 4, 1, 5, 9, 2, 6]) static var digitsOfPi:Vector<Int>;

	static var counter:Int = 0;
	static var four:Int = 4;
	static var six:Int = 6;
	static var three:Int = 3;
	@:md.section(".data") static var placed:Int = 7;
	static var sideEffect:Int = 0;

	@:md.main
	static function main():Void {
		final n = Probe.seed();

		Probe.report((7 + 5) * 3 - 11);
		Probe.report(Std.int(1000 / 7));
		Probe.report(1000 % 7);
		Probe.report(Std.int(-1000 / 7));
		Probe.report(-1000 % 7);
		Probe.report(1 << 20);
		Probe.report(-1048576 >> 8);
		Probe.report(-1048576 >>> 8);
		Probe.report(0x0F0F0F0F & 0x00FFFF00);
		Probe.report(0x0F0F0F0F | 0x00FFFF00);
		Probe.report(0x0F0F0F0F ^ 0x00FFFF00);
		Probe.report(~0x12345678);
		Probe.report(2 + 3 * 4 - Std.int(6 / 2));
		Probe.report(comparisons(5 * n, 7 * n));
		Probe.report(shortCircuit(n));
		Probe.report(ifChain(25 * n));
		Probe.report(sumTo(100 * n));
		Probe.report(doWhile(10 * n));
		Probe.report(nested(9 * n));
		Probe.report(breakContinue(100 * n));
		Probe.report(switchOn(3 * n));
		Probe.report(fib(20 * n));
		Probe.report(staticMutation(100 * n));
		Probe.report(-2147483647 - 1);
		Probe.report(unary(42 * n));
		Probe.report(incrementSemantics(10 * n));
		Probe.report(instanceDispatch(5 * n));
		Probe.report(chain(n));
		Probe.report(poolReuse(n));
		Probe.report(poolExhaust(n));
		Probe.report(int8Wrap(200 * n));
		Probe.report(uint8Wrap(300 * n));
		Probe.report(int16Wrap(40000 * n));
		Probe.report(uint16Wrap(70000 * n));
		Probe.report(uint32Shift(-2 * n));
		Probe.report(vectorSum(n));
		Probe.report(fixedPoint(n));
		Probe.report(stateMachine(n));
		Probe.report(payload(n));
		Probe.report(color(n));
		Probe.report(phase(n));
		Probe.report(romResidency(n));
		Probe.report(romTable(n));
		Probe.report(textLength(n));
		Probe.report(formatting(n));
		Probe.report(virtualDispatch(n));
		Probe.report(finalDispatch(n));
		Probe.report(inheritedField(n));
		Probe.report(interfaceCall(n));
		Probe.report(boundsGuard(n));
		Probe.report(precedenceMix(n));
		Probe.report(precedenceCompare(n));
		Probe.report(romConstant(n));

		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
	}

	static function comparisons(a:Int, b:Int):Int {
		final ok = (a < b) && (b > a) && (a <= 5) && (b >= 7) && (a != b) && !(a == b);
		return ok ? 1 : 0;
	}

	static function bump():Bool {
		sideEffect = sideEffect + 1;
		return true;
	}

	static function shortCircuit(n:Int):Int {
		sideEffect = 0;
		if ((n < 0) && bump()) {
			sideEffect = sideEffect + 100;
		}
		if ((n > 0) || bump()) {
			sideEffect = sideEffect + 0;
		}
		return sideEffect == 0 ? 1 : 0;
	}

	static function ifChain(x:Int):Int {
		if (x < 10) return 10;
		else if (x < 20) return 20;
		else if (x < 30) return 30;
		else return 40;
	}

	static function sumTo(n:Int):Int {
		var s = 0;
		var i = 1;
		while (i <= n) {
			s += i;
			i++;
		}
		return s;
	}

	static function doWhile(n:Int):Int {
		var k = 0;
		do {
			k++;
		} while (k < n);
		return k;
	}

	static function nested(n:Int):Int {
		var acc = 0;
		var i = 1;
		while (i <= n) {
			var j = 1;
			while (j <= n) {
				acc += i * j;
				j++;
			}
			i++;
		}
		return acc;
	}

	static function breakContinue(n:Int):Int {
		var s = 0;
		var i = 0;
		while (true) {
			i++;
			if (i > n) break;
			if ((i & 1) == 1) continue;
			s += i;
		}
		return s;
	}

	static function switchOn(v:Int):Int {
		var r = 0;
		switch (v) {
			case 1: r = 100;
			case 2: r = 200;
			case 3: r = 300;
			default: r = -1;
		}
		return r;
	}

	static function fib(n:Int):Int {
		if (n < 2) return n;
		return fib(n - 1) + fib(n - 2);
	}

	static function staticMutation(n:Int):Int {
		counter = 0;
		var i = 0;
		while (i < n) {
			counter += i;
			i++;
		}
		return counter;
	}

	static function instanceDispatch(a:Int):Int {
		final c = new Counter(a);
		c.twice(10);
		c.add(1);
		return c.get();
	}

	static function chain(n:Int):Int {
		Pool.reset(Node);

		var head:Node = null;
		var i = 1;
		while (i <= 4) {
			final node = new Node(i * n);
			node.next = head;
			head = node;
			i++;
		}

		var digits = 0;
		var p = head;
		while (p != null) {
			digits = digits * 10 + p.value;
			p = p.next;
		}
		return digits;
	}

	static function poolReuse(n:Int):Int {
		Pool.reset(Node);

		final a = new Node(11 * n);
		final b = new Node(22 * n);
		Pool.free(a);
		final c = new Node(33 * n);

		return (a == c ? 1000 : 0) + Pool.live(Node) * 100 + c.value + b.value;
	}

	static function poolExhaust(n:Int):Int {
		Pool.reset(Node);

		var i = 0;
		while (i < 4) {
			new Node(i * n);
			i++;
		}

		final overflow = new Node(99 * n);
		return (overflow == null ? 10 : 0) + Pool.live(Node);
	}

	static function int8Wrap(v:Int):Int {
		final x:Int8 = v;
		return x;
	}

	static function uint8Wrap(v:Int):Int {
		final x:UInt8 = v;
		return x;
	}

	static function int16Wrap(v:Int):Int {
		final x:Int16 = v;
		return x;
	}

	static function uint16Wrap(v:Int):Int {
		final x:UInt16 = v;
		return x;
	}

	static function uint32Shift(v:Int):Int {
		final x:UInt32 = v;
		return x >> 1;
	}

	static function vectorSum(n:Int):Int {
		var i = 0;
		while (i < slots.length) {
			slots[i] = (i + 1) * n;
			i++;
		}

		var total = 0;
		i = 0;
		while (i < slots.length) {
			total += slots[i];
			i++;
		}
		return total + slots.length;
	}

	static function fixedPoint(n:Int):Int {
		final three = Fix16.of(3 * n);
		final half:Fix16 = Fix16.of(1) / Fix16.of(2);
		final scaled = three * Fix16.of(5);
		return scaled.toInt() * 100 + (half + half).toInt();
	}

	static function stateMachine(n:Int):Int {
		var state = State.Idle;
		var total = 0;
		var i = 0;

		while (i < 6) {
			state = step(state, i * n);
			total = total * 10 + rank(state);
			i++;
		}
		return total;
	}

	static function step(state:State, tick:Int):State {
		return switch (state) {
			case Idle: Running(tick);
			case Running(ticks): ticks > 6 ? Done(ticks) : Running(ticks + tick);
			case Done(code): Done(code);
		}
	}

	static function rank(state:State):Int {
		return switch (state) {
			case Idle: 0;
			case Running(_): 1;
			case Done(_): 2;
		}
	}

	static function payload(n:Int):Int {
		final done = State.Done(42 * n);
		return switch (done) {
			case Done(code): code;
			case Running(ticks): ticks;
			case Idle: -1;
		}
	}

	static function color(n:Int):Int {
		final c = Color.Green;
		return switch (c) {
			case Red: 1;
			case Green: 2 * n;
			case Blue: 3;
		}
	}

	static function phase(n:Int):Int {
		final p:Phase = Play;
		return switch (p) {
			case Boot: 10;
			case Play: 20 * n;
			case Over: 30;
		}
	}

	static function romResidency(n:Int):Int {
		var score = 0;
		if ((Text.address("HX68K CONFORMANCE") & 0xFFFFFF) < 0x400000) score += 1;
		if ((Text.pointer(digitsOfPi) & 0xFFFFFF) < 0x400000) score += 2;
		if ((Text.pointer(buffer) & 0xFFFFFF) >= 0xFF0000) score += 4;
		return score * n;
	}

	static function romTable(n:Int):Int {
		var total = 0;
		var i = 0;
		while (i < digitsOfPi.length) {
			total = total * 10 + digitsOfPi[i];
			i++;
		}
		return total * n;
	}

	static function textLength(n:Int):Int {
		final label = "HX68K";
		return Text.length(label) * 100 + Text.charAt(label, 0) * n;
	}

	static function formatting(n:Int):Int {
		final end = Format.writeInt(-4207 * n, buffer, 0);
		final digits = (Text.charAt(Text.of(buffer), 1) - 48) * 100
			+ (Text.charAt(Text.of(buffer), 2) - 48) * 10
			+ (Text.charAt(Text.of(buffer), 3) - 48);
		return end * 1000 + digits;
	}

	static function interfaceCall(n:Int):Int {
		final a:Sized = new Square(4 * n);
		final b:Sized = new Gauge(5 * n);
		return a.span() * 100 + b.span();
	}

	@:md.noinline static function romConstant(n:Int):Int {
		return (digitsOfPi[2] * 10 + digitsOfPi[5] + placed) * n;
	}

	static function precedenceMix(n:Int):Int {
		return (four | six & three) * n;
	}

	static function precedenceCompare(n:Int):Int {
		return (four & six == 4 ? 7 : 3) * n;
	}

	static function boundsGuard(n:Int):Int {
		final before = Debug.boundsHits;
		slots[9 * n] = 1;
		final alias = slots;
		alias[12 * n] = 2;
		return (Debug.boundsHits - before) * 10 + slots.length;
	}

	static function virtualDispatch(n:Int):Int {
		final a:Shape = new Square(3 * n);
		final b:Shape = new Ring(5 * n);
		return a.area() + b.area();
	}

	static function finalDispatch(n:Int):Int {
		final t = new Tile(10 * n);
		final s:Shape = t;
		return t.area() * 100 + s.area();
	}

	static function inheritedField(n:Int):Int {
		final c = new Ring(6 * n);
		return c.size * c.spokes + c.tag();
	}

	static function unary(a:Int):Int {
		return -a;
	}

	static function incrementSemantics(a:Int):Int {
		var x = a;
		final b = x++;
		final c = ++x;
		return x + b + c;
	}
}
