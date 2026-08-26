package md.hw;

extern class Cpu {
	@:native("md_interrupts_on") static function enableInterrupts():Void;
	@:native("md_interrupts_off") static function disableInterrupts():Void;
}
