package md;

import md.res.Music;
import md.res.Sample;

class Xgm {
	public static inline final XGM = 4;

	public static inline final SAMPLE_TABLE = 0xA01C00;

	public static inline final SAMPLE_SLOTS = 0x3F;

	public static inline final TABLE_BYTES = 0x100;

	public static inline final PLAY = 0x40;

	public static inline final PAUSE = 0x10;

	public static inline final RESUME = 0x20;

	public static inline final NO_SAMPLE = 0xFFFF00;

	static inline final ADDRESS = 0x00;

	static inline final CHANNELS = 0x04;

	static inline final LOOPS = 0x0C;

	static inline final PROTECT = 0x0D;

	static inline final MODIFYING = 0x0E;

	static inline final PENDING = 0x0F;

	static var wanted:UInt16 = 60;

	static var step:UInt16 = 60;

	static var counted:Int16 = 0;

	public static function loadDriver():Void {
		if (Z80Bus.loadedDriver() == XGM) return;

		System.disableInterrupts();
		Z80Bus.loadDriver(XGM, Memory.addressOf(md.res.Drivers.xgm), md.res.Drivers.xgmLength);

		Z80Bus.request();
		pointSample(0, Memory.addressOf(md.res.Drivers.xgmSilence), md.res.Drivers.xgmSilenceLength);
		Z80Bus.release();
		System.enableInterrupts();

		while (!Z80Bus.driverReady()) {}

		setTempo(60);
		Z80Bus.usesProtection((Z80Bus.PARAMETERS + PROTECT) & 0xFFFF);
	}

	static function pointSample(slot:Int, at:Int, length:Int):Void {
		final entry:Int = SAMPLE_TABLE + (slot * 4);
		Memory.writeU8(entry, (at >> 8) & 0xFF);
		Memory.writeU8(entry + 1, (at >> 16) & 0xFF);
		Memory.writeU8(entry + 2, (length >> 8) & 0xFF);
		Memory.writeU8(entry + 3, (length >> 16) & 0xFF);
	}

	public static function play(tune:Music):Void {
		loadDriver();

		final song:Int = Memory.addressOf(tune);
		final quiet:Int = Memory.addressOf(md.res.Drivers.xgmSilence);

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		var slot:Int = 0;
		while (slot < SAMPLE_SLOTS) {
			final offset:Int = slot * 4;
			var at:Int = (Memory.loadU8(song + offset) << 8)
				| (Memory.loadU8(song + offset + 1) << 16);

			at = at == NO_SAMPLE ? quiet : at + song + TABLE_BYTES;

			final entry:Int = SAMPLE_TABLE + offset + 4;
			Memory.writeU8(entry, (at >> 8) & 0xFF);
			Memory.writeU8(entry + 1, (at >> 16) & 0xFF);
			Memory.writeU8(entry + 2, Memory.loadU8(song + offset + 2));
			Memory.writeU8(entry + 3, Memory.loadU8(song + offset + 3));
			slot++;
		}

		var data:Int = song + TABLE_BYTES;
		data += Memory.loadU8(song + 0xFC) << 8;
		data += Memory.loadU8(song + 0xFD) << 16;
		data += 4;

		start(data);

		if (!was) Z80Bus.release();
		System.enableInterrupts();
	}

	public static function stop():Void {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		setMusicAddress(Memory.addressOf(md.res.Drivers.xgmStop));
		sendCommand(PLAY);
		setPendingFrames(3);

		if (!was) Z80Bus.release();
		System.enableInterrupts();
	}

	public static function pause():Void {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		sendCommand(PAUSE);
		setPendingFrames(0);

		if (!was) Z80Bus.release();
		System.enableInterrupts();
	}

	public static function resume():Void {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		if ((Memory.readU8(Z80Bus.COMMAND) & PLAY) == 0) {
			sendCommand(RESUME);
			setPendingFrames(0);
		}

		if (!was) Z80Bus.release();
		System.enableInterrupts();
	}

	public static function playing():Bool {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		final on:Bool = (Memory.readU8(Z80Bus.STATUS) & PLAY) != 0;

		if (!was) Z80Bus.release();
		System.enableInterrupts();
		return on;
	}

	public static function setSample(id:Int, sample:Sample, length:Int):Void {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		pointSample(id, Memory.addressOf(sample), length);

		if (!was) Z80Bus.release();
		System.enableInterrupts();
	}

	public static function playSample(id:Int, priority:Int, channel:Int):Void {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		final slot:Int = Z80Bus.PARAMETERS + CHANNELS + (channel * 2);
		Memory.writeU8(slot, priority & 0x0F);
		Memory.writeU8(slot + 1, id);
		Memory.writeU8(Z80Bus.COMMAND, Memory.readU8(Z80Bus.COMMAND) | (1 << channel));

		if (!was) Z80Bus.release();
		System.enableInterrupts();
	}

	public static function stopSample(channel:Int):Void {
		playSample(0, 0x0F, channel);
	}

	public static function samplesPlaying(channels:UInt16):Int {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		final on:Int = Memory.readU8(Z80Bus.STATUS) & channels;

		if (!was) Z80Bus.release();
		System.enableInterrupts();
		return on;
	}

	public static function setLoops(count:Int8):Void {
		loadDriver();

		System.disableInterrupts();
		final was:Bool = Z80Bus.requestAndReport();

		Memory.writeU8(Z80Bus.PARAMETERS + LOOPS, (count : Int) + 1);

		if (!was) Z80Bus.release();
		System.enableInterrupts();
	}

	public static inline function tempo():UInt16 {
		return wanted;
	}

	public static function setTempo(beats:UInt16):Void {
		wanted = beats;
		step = System.isPal() ? 50 : 60;
	}

	public static function advance():Void {
		if (Z80Bus.loadedDriver() != XGM) return;

		var left:Int = counted;
		final every:Int = step;
		var due:Int = 0;

		while (left <= 0) {
			due++;
			left += every;
		}

		counted = left - (wanted : Int);

		final was:Bool = Z80Bus.requestAndReport();
		addPendingFrames(due);
		if (!was) Z80Bus.release();
	}

	static inline function setMusicAddress(at:Int):Void {
		final where:Int = Z80Bus.PARAMETERS + ADDRESS;
		Memory.writeU8(where, at & 0xFF);
		Memory.writeU8(where + 1, (at >> 8) & 0xFF);
		Memory.writeU8(where + 2, (at >> 16) & 0xFF);
		Memory.writeU8(where + 3, (at >> 24) & 0xFF);
	}

	static inline function sendCommand(what:Int):Void {
		Memory.writeU8(Z80Bus.COMMAND, (Memory.readU8(Z80Bus.COMMAND) & 0x0F) | what);
	}

	static inline function start(data:Int):Void {
		setMusicAddress(data);
		sendCommand(PLAY);
		setPendingFrames(0);
	}

	static inline function setPendingFrames(count:Int):Void {
		holdPending();
		Memory.writeU8(Z80Bus.PARAMETERS + PENDING, count);
	}

	static inline function addPendingFrames(count:Int):Void {
		holdPending();
		final pending:Int = Z80Bus.PARAMETERS + PENDING;
		Memory.writeU8(pending, Memory.readU8(pending) + count);
	}

	static function holdPending():Void {
		final modifying:Int = Z80Bus.PARAMETERS + MODIFYING;

		while (true) {
			Z80Bus.request();
			Z80Bus.endReset();
			if (Memory.readU8(modifying) == 0) break;
			Z80Bus.release();
			Z80Bus.linger();
		}
	}
}
