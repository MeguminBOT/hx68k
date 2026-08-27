package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

typedef Sample = {
	final name:String;
	final data:Bytes;
	final driver:String;
	final rate:Int;
	final exact:Bool;
}

class Sounds {
	public static function rateOf(driver:String):Int {
		return switch (driver.toUpperCase()) {
			case "PCM" | "DEFAULT" | "": 16000;
			case "DPCM2": 22050;
			case "PCM4": 16000;
			case "XGM": 14000;
			case "XGM2": 13300;
			case _: throw new haxe.Exception(driver + " is not a sound driver this knows. "
				+ "Use PCM, DPCM2, PCM4, XGM or XGM2.");
		}
	}

	public static inline function alignOf(driver:String):Int {
		return driver.toUpperCase() == "DPCM2" ? 128 : 256;
	}

	public static inline function fillOf(driver:String):Int {
		return driver.toUpperCase() == "DPCM2" ? 136 : 0;
	}

	public static function convert(source:Bytes, driver:String, rate:Int):Bytes {
		final held:Int = rate > 0 ? rate : rateOf(driver);
		final pcm = new Wave(source).pcm(held);
		return driver.toUpperCase() == "DPCM2" ? Dpcm.pack(pcm) : pcm;
	}

	public static function made(each:Sample):{bytes:Array<Int>, count:Int} {
		final wave = new Wave(each.data);
		var pcm = wave.pcm(each.rate);
		if (each.driver == "DPCM2") pcm = Dpcm.pack(pcm);

		final align:Int = each.driver == "DPCM2" ? 128 : 256;
		final fill:Int = each.driver == "DPCM2" ? 136 : 0;
		final padded = Emitter.evened(Emitter.sized(pcm, align, fill));

		return {bytes: [for (i in 0...padded.length) padded.get(i)], count: pcm.length};
	}

	static function wav(rate:Int, bits:Int, channels:Int, count:Int,
			level:Int->Int->Int):Bytes {
		final width:Int = Std.int(bits / 8);
		final block:Int = width * channels;
		final length:Int = count * block;
		final out = Bytes.alloc(44 + length);

		out.blit(0, Bytes.ofString("RIFF"), 0, 4);
		setInt32(out, 4, 36 + length);
		out.blit(8, Bytes.ofString("WAVE"), 0, 4);
		out.blit(12, Bytes.ofString("fmt "), 0, 4);
		setInt32(out, 16, 16);
		setInt16(out, 20, 1);
		setInt16(out, 22, channels);
		setInt32(out, 24, rate);
		setInt32(out, 28, rate * block);
		setInt16(out, 32, block);
		setInt16(out, 34, bits);
		out.blit(36, Bytes.ofString("data"), 0, 4);
		setInt32(out, 40, length);

		for (index in 0...count) {
			for (channel in 0...channels) {
				final at:Int = 44 + (index * block) + (channel * width);
				final value:Int = level(index, channel);
				if (bits == 8) out.set(at, value & 0xFF);
				else setInt16(out, at, value & 0xFFFF);
			}
		}

		return out;
	}

	static inline function setInt16(out:Bytes, at:Int, value:Int):Void {
		out.set(at, value & 0xFF);
		out.set(at + 1, (value >> 8) & 0xFF);
	}

	static inline function setInt32(out:Bytes, at:Int, value:Int):Void {
		setInt16(out, at, value);
		setInt16(out, at + 2, value >> 16);
	}

	public static function constant(rate:Int, count:Int, value:Int):Bytes {
		return wav(rate, 16, 1, count, (i, c) -> value);
	}

	public static function ramp(rate:Int, count:Int):Bytes {
		return wav(rate, 16, 1, count, (i, c) -> (i * 211) - 16000);
	}

	static function tone(index:Int, rate:Int, hertz:Int):Int {
		return Std.int(28000 * Math.sin((2 * Math.PI * hertz * index) / rate));
	}

	public static function all():Array<Sample> {
		return [
			{
				name: "eight_bit_at_the_driver_rate",
				data: wav(16000, 8, 1, 300, (i, c) -> (i * 37) & 0xFF),
				driver: "PCM", rate: 16000, exact: true
			},
			{
				name: "sixteen_bit_at_the_driver_rate",
				data: wav(16000, 16, 1, 300, (i, c) -> ((i * 4111) & 0xFFFF) - 32768),
				driver: "PCM", rate: 16000, exact: true
			},
			{
				name: "sixteen_bit_at_both_ends_of_the_range",
				data: wav(16000, 16, 1, 264, (i, c) -> switch (i % 8) {
					case 0: -32768;
					case 1: -32767;
					case 2: 32767;
					case 3: 32766;
					case 4: -1;
					case 5: 0;
					case 6: 255;
					case _: -256;
				}),
				driver: "PCM", rate: 16000, exact: true
			},
			{
				name: "sixteen_bit_stereo_folded_to_one",
				data: wav(16000, 16, 2, 300, (i, c) -> c == 0 ? ((i * 4111) & 0xFFFF) - 32768
					: 32767 - ((i * 2777) & 0xFFFF)),
				driver: "PCM", rate: 16000, exact: true
			},
			{
				name: "eight_bit_stereo_folded_to_one",
				data: wav(16000, 8, 2, 300, (i, c) -> c == 0 ? (i * 37) & 0xFF : (255 - (i * 11)) & 0xFF),
				driver: "PCM", rate: 16000, exact: true
			},
			{
				name: "a_length_that_is_not_a_whole_block",
				data: wav(16000, 16, 1, 257, (i, c) -> ((i * 911) & 0xFFFF) - 32768),
				driver: "PCM", rate: 16000, exact: true
			},
			{
				name: "the_xgm_driver_rate",
				data: wav(14000, 16, 1, 400, (i, c) -> ((i * 4111) & 0xFFFF) - 32768),
				driver: "XGM", rate: 14000, exact: true
			},
			{
				name: "the_four_channel_driver_rate",
				data: wav(16000, 16, 1, 400, (i, c) -> ((i * 1777) & 0xFFFF) - 32768),
				driver: "PCM4", rate: 16000, exact: true
			},
			{
				name: "eight_kilohertz_through_the_pcm_driver",
				data: wav(8000, 16, 1, 300, (i, c) -> ((i * 4111) & 0xFFFF) - 32768),
				driver: "PCM", rate: 8000, exact: true
			},
			{
				name: "thirty_two_kilohertz_through_the_pcm_driver",
				data: wav(32000, 16, 1, 600, (i, c) -> ((i * 4111) & 0xFFFF) - 32768),
				driver: "PCM", rate: 32000, exact: true
			},
			{
				name: "the_dpcm_driver_at_its_own_rate",
				data: wav(22050, 16, 1, 500, (i, c) -> ((i * 2311) & 0xFFFF) - 32768),
				driver: "DPCM2", rate: 22050, exact: true
			},
			{
				name: "a_dpcm_ramp_that_outruns_the_delta_table",
				data: wav(22050, 16, 1, 400, (i, c) -> (i * 160) - 32768),
				driver: "DPCM2", rate: 22050, exact: true
			},
			{
				name: "halved_from_thirty_two_kilohertz",
				data: wav(32000, 16, 1, 600, (i, c) -> tone(i, 32000, 400)),
				driver: "PCM", rate: 16000, exact: false
			},
			{
				name: "doubled_from_eight_kilohertz",
				data: wav(8000, 16, 1, 300, (i, c) -> tone(i, 8000, 400)),
				driver: "PCM", rate: 16000, exact: false
			},
			{
				name: "brought_down_from_forty_four_one",
				data: wav(44100, 16, 1, 900, (i, c) -> tone(i, 44100, 400)),
				driver: "PCM", rate: 16000, exact: false
			},
			{
				name: "brought_down_with_nothing_a_resampler_can_hold",
				data: wav(32000, 16, 1, 600, (i, c) -> ((i * 4111) & 0xFFFF) - 32768),
				driver: "PCM", rate: 16000, exact: false
			}
		];
	}
}
#end
