package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;

class VgmCommand {
	public static inline final DATA_BLOCK = 0x67;
	public static inline final END = 0x66;
	public static inline final SEEK = 0xE0;
	public static inline final WRITE_SN76489 = 0x50;
	public static inline final WRITE_YM2612_PORT0 = 0x52;
	public static inline final WRITE_YM2612_PORT1 = 0x53;
	public static inline final WAIT_NTSC_FRAME = 0x62;
	public static inline final WAIT_PAL_FRAME = 0x63;
	public static inline final STREAM_CONTROL = 0x90;
	public static inline final STREAM_DATA = 0x91;
	public static inline final STREAM_FREQUENCY = 0x92;
	public static inline final STREAM_START_LONG = 0x93;
	public static inline final STREAM_STOP = 0x94;
	public static inline final STREAM_START = 0x95;
	public static inline final LOOP_START = 0x30;
	public static inline final LOOP_END = 0x31;
	public static inline final WRITE_RF5C68 = 0xB0;
	public static inline final WRITE_RF5C164 = 0xB1;

	public var data:Bytes;
	public var offset:Int;
	public var command:Int;
	public var size:Int;
	public var time:Int;

	function new(data:Bytes, offset:Int, command:Int, time:Int) {
		this.data = data;
		this.offset = offset;
		this.time = time;

		if (data == null) {
			this.command = command;
			this.size = 1;
		} else {
			this.command = data.get(offset) & 0xFF;
			this.size = computeSize();
		}
	}

	public static function made(command:Int, time:Int):VgmCommand {
		return new VgmCommand(null, 0, command, time);
	}

	public static function read(data:Bytes, offset:Int, time:Int):VgmCommand {
		return new VgmCommand(data, offset, 0, time);
	}

	public static function ym(port:Int, register:Int, value:Int):VgmCommand {
		final held = Bytes.alloc(3);
		held.set(0, port == 0 ? WRITE_YM2612_PORT0 : WRITE_YM2612_PORT1);
		held.set(1, register & 0xFF);
		held.set(2, value & 0xFF);
		return read(held, 0, 0);
	}

	function computeSize():Int {
		return switch (command) {
			case 0x4F | 0x50: 2;
			case 0x51 | 0x52 | 0x53 | 0x54 | 0x55 | 0x56 | 0x57 | 0x58 | 0x59 | 0x5A | 0x5B | 0x5C
				| 0x5D | 0x5E | 0x5F: 3;
			case 0x61: 3;
			case 0x62 | 0x63: 1;
			case 0x66: 1;
			case 0x67: 7 + LittleEndian.int32(data, offset + 0x03);
			case 0x68: 12 + LittleEndian.int24(data, offset + 0x09);
			case 0x90: 5;
			case 0x91: 5;
			case 0x92: 6;
			case 0x93: 11;
			case 0x94: 2;
			case 0x95: 5;
			case _: switch (command >> 4) {
					case 0x3: 2;
					case 0x4: 3;
					case 0x7: 1;
					case 0x8: 1;
					case 0xA: 3;
					case 0xB: 3;
					case 0xC: 4;
					case 0xD: 4;
					case 0xE: 5;
					case 0xF: 5;
					case _: 1;
				}
		}
	}

	public function bytes():Bytes {
		final out = Bytes.alloc(size);
		if (data == null) out.set(0, command);
		else out.blit(0, data, offset, size);
		return out;
	}

	public inline function at(index:Int):Int {
		return data.get(offset + index) & 0xFF;
	}

	public inline function isDataBlock():Bool return command == DATA_BLOCK;

	public inline function dataBankId():Int return at(2);

	public inline function dataBlockLength():Int return LittleEndian.int32(data, offset + 3);

	public inline function isSeek():Bool return command == SEEK;

	public inline function seekAddress():Int return isSeek() ? LittleEndian.int32(data, offset + 0x01) : -1;

	public inline function isEnd():Bool return command == END;

	public inline function isLoopStart():Bool return command == LOOP_START;

	public inline function isLoopEnd():Bool return command == LOOP_END;

	public inline function isPcm():Bool return (command & 0xF0) == 0x80;

	public inline function isWait():Bool {
		return isShortWait() || (command >= 0x61 && command <= 0x63);
	}

	public inline function isWaitNtsc():Bool return command == 0x62;

	public inline function isWaitPal():Bool return command == 0x63;

	public inline function isShortWait():Bool return (command & 0xF0) == 0x70;

	public function waitValue():Int {
		if (isShortWait()) return (command & 0x0F) + 1;
		if (isPcm()) return command & 0x0F;
		return switch (command) {
			case 0x61: LittleEndian.int16(data, offset + 0x01);
			case 0x62: 0x2DF;
			case 0x63: 0x372;
			case _: 0;
		}
	}

	public inline function isPsgWrite():Bool return command == WRITE_SN76489;

	public inline function isPsgEnvelopeWrite():Bool {
		return isPsgWrite() && (psgValue() & 0x91) == 0x91;
	}

	public inline function isPsgToneWrite():Bool return isPsgWrite() && !isPsgEnvelopeWrite();

	public inline function psgValue():Int return isPsgWrite() ? at(1) : -1;

	public inline function isYmPort0Write():Bool return command == WRITE_YM2612_PORT0;

	public inline function isYmPort1Write():Bool return command == WRITE_YM2612_PORT1;

	public inline function isYmWrite():Bool return isYmPort0Write() || isYmPort1Write();

	public inline function ymPort():Int {
		return isYmPort0Write() ? 0 : (isYmPort1Write() ? 1 : -1);
	}

	public inline function ymChannel():Int {
		if (isYmPort0Write()) return ymRegister() & 3;
		if (isYmPort1Write()) return (ymRegister() & 3) + 3;
		return -1;
	}

	public inline function ymRegister():Int return isYmWrite() ? at(1) : -1;

	public inline function ymValue():Int return isYmWrite() ? at(2) : -1;

	public inline function isYmKeyWrite():Bool return isYmPort0Write() && ymRegister() == 0x28;

	public inline function isYmKeyOffWrite():Bool {
		return isYmKeyWrite() && (ymValue() & 0xF0) == 0x00;
	}

	public inline function isYmKeyOnWrite():Bool {
		return isYmKeyWrite() && (ymValue() & 0xF0) != 0x00;
	}

	public function ymKeyChannel():Int {
		if (!isYmKeyWrite()) return -1;
		var register:Int = ymValue() & 0x7;
		if (register == 3 || register == 7) return -1;
		if (register >= 4) register--;
		return register;
	}

	public inline function isYm0x2XWrite():Bool {
		return isYmPort0Write() && (ymRegister() & 0xF0) == 0x20;
	}

	public inline function isYmTimersWrite():Bool return isYmPort0Write() && ymRegister() == 0x27;

	public inline function isYmTimersPlainWrite():Bool {
		return isYmTimersWrite() && (ymValue() & 0xC0) == 0x00;
	}

	public inline function isDacEnabled():Bool return isYmPort0Write() && ymRegister() == 0x2B;

	public inline function isDacEnabledOn():Bool {
		return isDacEnabled() && (ymValue() & 0x80) == 0x80;
	}

	public inline function isDacEnabledOff():Bool {
		return isDacEnabled() && (ymValue() & 0x80) == 0x00;
	}

	public inline function isStream():Bool {
		return isStreamControl() || isStreamData() || isStreamFrequency() || isStreamStart()
			|| isStreamStartLong() || isStreamStop();
	}

	public inline function isStreamControl():Bool return command == STREAM_CONTROL;

	public inline function isStreamData():Bool return command == STREAM_DATA;

	public inline function isStreamFrequency():Bool return command == STREAM_FREQUENCY;

	public inline function isStreamStart():Bool return command == STREAM_START;

	public inline function isStreamStartLong():Bool return command == STREAM_START_LONG;

	public inline function isStreamStop():Bool return command == STREAM_STOP;

	public inline function streamId():Int return isStream() ? at(1) : -1;

	public inline function streamBankId():Int return isStreamData() ? at(2) : -1;

	public inline function streamBlockId():Int return isStreamStart() ? at(2) : -1;

	public inline function streamFrequency():Int {
		return isStreamFrequency() ? LittleEndian.int32(data, offset + 2) : -1;
	}

	public inline function streamSampleAddress():Int {
		return isStreamStartLong() ? LittleEndian.int32(data, offset + 2) : -1;
	}

	public inline function streamSampleSize():Int {
		return isStreamStartLong() ? LittleEndian.int32(data, offset + 7) : -1;
	}

	public inline function isRf5c68Control():Bool {
		return command == WRITE_RF5C68 || command == WRITE_RF5C164;
	}

	public function isSame(other:VgmCommand):Bool {
		if (other == null) return false;
		if (command != other.command || size != other.size) return false;
		for (i in 0...size) {
			final mine:Int = data == null ? command : at(i);
			final theirs:Int = other.data == null ? other.command : other.at(i);
			if (mine != theirs) return false;
		}
		return true;
	}
}
#end
