package md;

enum abstract DmaTarget(Int) to Int {
	var Vram = 0;
	var Cram = 1;
	var Vsram = 2;
}

extern class Dma {
	@:native("DMA_init") static function init():Void;
	@:native("DMA_flushQueue") static function flush():Void;
	@:native("DMA_clearQueue") static function clear():Void;
	@:native("DMA_waitCompletion") static function wait():Void;

	@:native("DMA_transfer") static function transfer<T>(how:Transfer, to:DmaTarget, from:Vector<T>,
		at:UInt16, length:UInt16, step:UInt16):Bool;
	@:native("DMA_queueDma") static function queue<T>(to:DmaTarget, from:Vector<T>, at:UInt16,
		length:UInt16, step:UInt16):Bool;
	@:native("DMA_doVRamFill") static function fillVram(at:UInt16, length:UInt16, value:UInt8,
		step:Int16):Void;
	@:native("DMA_doVRamCopy") static function copyVram(from:UInt16, to:UInt16, length:UInt16,
		step:Int16):Void;

	@:native("DMA_canQueue") static function canQueue(to:DmaTarget, length:UInt16):Bool;
	@:native("DMA_getQueueSize") static function queued():UInt16;
	@:native("DMA_getMaxTransferSize") static function maxTransferSize():UInt16;
	@:native("DMA_setMaxTransferSize") static function setMaxTransferSize(words:UInt16):Void;
	@:native("DMA_setAutoFlush") static function setAutoFlush(on:Bool):Void;
}
