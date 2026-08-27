package hx68k.debug;

import hx68k.debug.md.BandwidthView;
import hx68k.debug.md.UsageView;
import hx68k.debug.md.VideoView;

class Views {
	public static function lines(view:View, limit:Int):Array<String> {
		final out = new Array<String>();
		for (row in view.rows(limit)) out.push(row.toString());
		return out;
	}

	public static function of(debugger:Debugger):Array<View> {
		return [
			new RegistersView(debugger),
			new DisassemblyView(debugger),
			new StackView(debugger),
			new VideoView(debugger),
			new UsageView(debugger),
			new BandwidthView(debugger)
		];
	}
}
