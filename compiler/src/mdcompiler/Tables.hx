package mdcompiler;

#if (macro || md_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;

class Tables {
	public static inline final QUARTER = 91;

	public static inline final SCALE = 64;

	macro public static function sine():Array<Field> {
		final fields = Context.getBuildFields();
		final at = Context.currentPos();
		final values:Array<Expr> = [];

		for(degree in 0...QUARTER) {
			final turn = degree * Math.PI / 180.0;
			values.push({expr: EConst(CInt(Std.string(Math.round(Math.sin(turn) * SCALE)))), pos: at});
		}

		fields.push({
			name: "QUARTER_TURN",
			access: [APublic, AStatic, AInline, AFinal],
			kind: FVar(macro :Int, macro $v{QUARTER}),
			pos: at
		});

		fields.push({
			name: "quarter",
			access: [AStatic],
			meta: [{name: ":romData", params: [{expr: EArrayDecl(values), pos: at}], pos: at}],
			kind: FVar(macro :md.Vector<md.Int16>, null),
			pos: at
		});

		return fields;
	}
}

#end
