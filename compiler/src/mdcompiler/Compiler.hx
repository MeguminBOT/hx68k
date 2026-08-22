package mdcompiler;

#if (macro || md_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

import reflaxe.DirectToStringCompiler;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;

using StringTools;
using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.OperatorHelper;
using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.TypedExprHelper;

class Compiler extends DirectToStringCompiler {
	public static inline final HEADER = "hx.h";
	public static inline final ENTRY = "hx_entry.c";

	static inline final P_PROLOGUE = 0;
	static inline final P_INCLUDES = 5;
	static inline final P_TYPEDEFS = 7;
	static inline final P_STRUCTS = 8;
	static inline final P_GLOBALS = 10;
	static inline final P_PROTOS = 20;
	static inline final P_EPILOGUE = 90;

	static final IDENT = ~/[^A-Za-z0-9_]/g;

	var entryPoint:Null<String> = null;
	var includes:Map<String, Bool> = [];
	var vectorSizes:Map<Int, String> = [];

	public override function onCompileStart() {
		entryPoint = null;
		includes = [];

		final main = getMainModule();
		if(main != null) addModuleTypeForCompilation(main);

		setExtraFile(HEADER, "");
		appendToExtraFile(HEADER, "#ifndef _HX_H_\n#define _HX_H_\n\n#include <genesis.h>", P_PROLOGUE);
		appendToExtraFile(HEADER, "#endif", P_EPILOGUE);
	}

	public override function onCompileEnd() {
		final entry = entryPoint;
		if(entry == null) {
			Context.error("No entry point. Mark a static function with @:md.main.", Context.currentPos());
			return;
		}
		setExtraFile(ENTRY, '#include "${HEADER}"\n\nint main(bool hardReset)\n{\n\t(void)hardReset;\n\t${entry}();\n\treturn 0;\n}\n');
	}

	static function safe(s:String):String {
		return IDENT.replace(s, "_");
	}

	function classPrefix(c:ClassType):String {
		return safe(c.globalName());
	}

	function noteInclude(t:BaseType) {
		for(entry in t.meta.extract(":md.include")) {
			switch(entry.params[0].expr) {
				case EConst(CString(s)):
					if(!includes.exists(s)) {
						includes.set(s, true);
						appendToExtraFile(HEADER, '#include "$s"\n', P_INCLUDES);
					}
				case _:
					Context.error("@:md.include requires a constant String.", entry.pos);
			}
		}
	}

	function fieldName(c:ClassType, cf:ClassField, isStatic:Bool):String {
		final native = cf.getNameOrNative();
		return c.isExtern ? native : classPrefix(c) + "_" + safe(native);
	}

	function varName(v:TVar):String {
		return safe(v.name);
	}

	function toC(t:Type, pos:haxe.macro.Expr.Position):String {
		return switch(t) {
			case TAbstract(aRef, params) if(aRef.get().name == "Vector" && aRef.get().pack.join(".") == "md"):
				toC(params[0], pos) + "*";

			case TInst(cRef, params) if(cRef.get().name == "VectorData"):
				toC(params[0], pos) + "*";

			case TAbstract(aRef, params): {
				final a = aRef.get();
				final native = a.meta.extract(":md.type")[0];
				if(native != null) {
					switch(native.params[0].expr) {
						case EConst(CString(s)): s;
						case _: Context.error("@:md.type requires a constant String.", native.pos);
					}
				} else switch(a.name) {
					case "Int": "s32";
					case "Bool": "bool";
					case "Void": "void";
					case "Single" | "Float":
						Context.error("Floating point is not available on the 68000. Use Int or a fixed-point type.", pos);
					case "Null": {
						if(!isPointerShaped(params[0]))
							Context.error("Only pointer-shaped types can be null here. A nullable "
								+ "Int has no representation on the 68000.", pos);
						toC(params[0], pos);
					}
					case _: a.type != null ? toC(a.type, pos) : Context.error('Unsupported abstract: ${a.name}', pos);
				}
			}
			case TInst(cRef, _): {
				final c = cRef.get();
				final native = c.meta.extract(":md.type")[0];
				if(native != null) {
					switch(native.params[0].expr) {
						case EConst(CString(s)): s;
						case _: Context.error("@:md.type requires a constant String.", native.pos);
					}
				} else if(c.name == "String") {
					"const char*";
				} else {
					classPrefix(c) + "*";
				}
			}
			case TEnum(eRef, _): {
				addModuleTypeForCompilation(TEnumDecl(eRef));
				enumPrefix(eRef.get());
			}
			case TType(_, _): toC(haxe.macro.TypeTools.follow(t, true), pos);
			case TLazy(f): toC(f(), pos);
			case TFun(_, _): Context.error("Function values are not supported yet.", pos);
			case TDynamic(_): Context.error("Dynamic is not supported on this target.", pos);
			case _: Context.error('Unsupported type: ${t}', pos);
		}
	}

	function poolCapacity(c:ClassType):Null<Int> {
		final entry = c.meta.extract(":md.pool")[0];
		if(entry == null) return null;
		if(entry.params.length != 1) Context.error("@:md.pool takes one capacity.", entry.pos);
		return switch(entry.params[0].expr) {
			case EConst(CInt(v)): Std.parseInt(v);
			case _: Context.error("@:md.pool requires a constant Int capacity.", entry.pos);
		}
	}

	static function isMethod(cf:ClassField):Bool {
		return switch(cf.kind) {
			case FMethod(_): true;
			case _: false;
		}
	}

	function rejectStringMember(c:ClassType, member:String, pos:haxe.macro.Expr.Position):Void {
		if(c.name != "String" || c.pack.length != 0) return;
		Context.error("String has no runtime on this target. Use md.Text." + member + " or another "
			+ "md.Text operation on the pointer.", pos);
	}

	function memberName(cf:ClassField):String {
		return safe(cf.getNameOrNative());
	}

	static function isPointerShaped(t:Type):Bool {
		return switch(haxe.macro.TypeTools.follow(t)) {
			case TInst(_, _): true;
			case TAbstract(aRef, _): aRef.get().name == "Vector" && aRef.get().pack.join(".") == "md";
			case _: false;
		}
	}

	static function isVector(t:Type):Bool {
		return switch(haxe.macro.TypeTools.follow(t)) {
			case TAbstract(aRef, _): aRef.get().name == "Vector" && aRef.get().pack.join(".") == "md";
			case _: false;
		}
	}

	function storage(cf:ClassField):String {
		if(!isVector(cf.type)) return "";
		final rom = romValues(cf);
		if(rom != null) return "[" + rom.length + "]";

		final entry = cf.meta.extract(":md.size")[0];
		if(entry == null)
			Context.error("A Vector field needs its capacity: @:md.size(n), or the data itself "
				+ "through @:romData.", cf.pos);
		return switch(entry.params[0].expr) {
			case EConst(CInt(v)): "[" + v + "]";
			case _: Context.error("@:md.size requires a constant Int.", entry.pos);
		}
	}

	function methodName(c:ClassType, cf:ClassField):String {
		final native = cf.getNameOrNative();
		if(c.isExtern) return native;
		return classPrefix(c) + "_" + (cf.name == "new" ? "init" : safe(native));
	}

	function emitStruct(classType:ClassType, prefix:String, fields:Array<ClassVarData>):Void {
		appendToExtraFile(HEADER, 'typedef struct $prefix $prefix;\n', P_TYPEDEFS);

		final members = fields.map(v -> {
			final ctype = isVector(v.field.type) ? elementType(v.field.type, v.field.pos)
				: toC(v.field.type, v.field.pos);
			"\t" + ctype + " " + memberName(v.field) + storage(v.field) + ";";
		});
		if(members.length == 0) members.push("\tu8 empty;");
		appendToExtraFile(HEADER, 'struct $prefix {\n' + members.join("\n") + "\n};\n\n", P_STRUCTS);
	}

	function emitPool(prefix:String, capacity:Int, body:Array<String>):Void {
		appendToExtraFile(HEADER, '$prefix* ${prefix}_alloc(void);\n'
			+ 'void ${prefix}_free($prefix* self);\n'
			+ 'void ${prefix}_reset(void);\n'
			+ 's32 ${prefix}_live(void);\n', P_PROTOS);

		body.push('static $prefix ${prefix}__slots[$capacity];\n'
			+ 'static u16 ${prefix}__used = 0;\n'
			+ 'static u16 ${prefix}__free[$capacity];\n'
			+ 'static u16 ${prefix}__freeCount = 0;');

		body.push('$prefix* ${prefix}_alloc(void)\n{\n'
			+ '\tif(${prefix}__freeCount > 0) return &${prefix}__slots[${prefix}__free[--${prefix}__freeCount]];\n'
			+ '\tif(${prefix}__used < $capacity) return &${prefix}__slots[${prefix}__used++];\n'
			+ '\treturn NULL;\n}');

		body.push('void ${prefix}_free($prefix* self)\n{\n'
			+ '\tif(self == NULL) return;\n'
			+ '\t${prefix}__free[${prefix}__freeCount++] = (u16)(self - ${prefix}__slots);\n}');

		body.push('void ${prefix}_reset(void)\n{\n'
			+ '\t${prefix}__used = 0;\n\t${prefix}__freeCount = 0;\n}');

		body.push('s32 ${prefix}_live(void)\n{\n'
			+ '\treturn (s32)${prefix}__used - (s32)${prefix}__freeCount;\n}');
	}

	function emitCreate(prefix:String, ctor:ClassFuncData, body:Array<String>):Void {
		final params = ctor.args.map(a -> toC(a.type, ctor.field.pos) + " " + safe(a.getName()));
		final names = ctor.args.map(a -> safe(a.getName()));
		final signature = '$prefix* ${prefix}_create(' + (params.length == 0 ? "void" : params.join(", ")) + ")";

		appendToExtraFile(HEADER, signature + ";\n", P_PROTOS);
		body.push(signature + "\n{\n"
			+ '\t$prefix* self = ${prefix}_alloc();\n'
			+ '\tif(self != NULL) ${prefix}_init(' + ["self"].concat(names).join(", ") + ");\n"
			+ "\treturn self;\n}");
	}

	function emitVar(classType:ClassType, v:ClassVarData, body:Array<String>):Void {
		final name = fieldName(classType, v.field, true);
		final vector = isVector(v.field.type);
		final rom = romValues(v.field);
		final plain = vector ? elementType(v.field.type, v.field.pos) : toC(v.field.type, v.field.pos);
		final ctype = (rom != null ? "const " : "") + (v.field.meta.has(":md.volatile") ? "volatile " + plain : plain);
		final size = vector ? (rom != null ? "[" + rom.length + "]" : storage(v.field)) : "";

		appendToExtraFile(HEADER, 'extern $ctype $name$size;\n', P_GLOBALS);

		if(rom != null) {
			body.push('$ctype $name$size = { ' + rom.join(", ") + " };");
			return;
		}

		if(vector) {
			body.push('$ctype $name$size;');
			return;
		}

		final init = switch(v.field.expr()) {
			case null: null;
			case e: compileExpression(e);
		}
		body.push(init != null ? '$ctype $name = $init;' : '$ctype $name;');
	}

	function elementType(t:Type, pos:haxe.macro.Expr.Position):String {
		return switch(haxe.macro.TypeTools.follow(t)) {
			case TAbstract(_, params): toC(params[0], pos);
			case _: Context.error("Not a vector type.", pos);
		}
	}

	function emitFunc(classType:ClassType, prefix:String, f:ClassFuncData, body:Array<String>):Void {
		final isCtor = !f.isStatic && f.field.name == "new";
		final name = f.isStatic ? fieldName(classType, f.field, true) : methodName(classType, f.field);
		final ret = isCtor ? "void" : toC(f.ret, f.field.pos);

		final params = f.args.map(a -> toC(a.type, f.field.pos) + " " + safe(a.getName()));
		if(!f.isStatic) params.unshift('$prefix* self');
		final signature = ret + " " + name + "(" + (params.length == 0 ? "void" : params.join(", ")) + ")";

		appendToExtraFile(HEADER, signature + ";\n", P_PROTOS);

		if(f.field.meta.has(":md.main")) {
			if(!f.isStatic) Context.error("@:md.main must mark a static function.", f.field.pos);
			if(entryPoint != null) Context.error("Multiple @:md.main entry points declared.", f.field.pos);
			entryPoint = name;
		}

		final expr = f.expr;
		if(expr == null) return;
		body.push(signature + "\n{\n" + block(expr).tab() + "\n}");
	}

	function poolCall(callee:TypedExpr, args:Array<TypedExpr>, pos:haxe.macro.Expr.Position):Null<String> {
		final cf = switch(callee.expr) {
			case TField(obj, FStatic(cRef, cfRef)) if(cRef.get().name == "Pool" && cRef.get().pack.join(".") == "md"):
				cfRef.get();
			case _: null;
		}
		if(cf == null) return null;

		final owner = switch(cf.name) {
			case "free": switch(haxe.macro.TypeTools.follow(args[0].t)) {
				case TInst(cRef, _): cRef.get();
				case _: Context.error("Pool.free needs a class instance.", pos);
			}
			case _: switch(args[0].expr) {
				case TTypeExpr(TClassDecl(cRef)): cRef.get();
				case _: Context.error("Pool." + cf.name + " needs a class, as in Pool." + cf.name + "(Entity).", pos);
			}
		}

		if(poolCapacity(owner) == null)
			Context.error(owner.name + " has no pool. Add @:md.pool(n) above the class.", pos);

		final prefix = classPrefix(owner);
		return switch(cf.name) {
			case "free": prefix + "_free(" + compileExpressionOrError(args[0]) + ")";
			case "reset": prefix + "_reset()";
			case "live": prefix + "_live()";
			case _: Context.error("Unknown Pool operation: " + cf.name, pos);
		}
	}

	function vectorField(e:TypedExpr):Null<ClassField> {
		return switch(e.expr) {
			case TField(_, FStatic(_, cfRef)): cfRef.get();
			case TField(_, FInstance(_, _, cfRef)): cfRef.get();
			case TParenthesis(inner) | TMeta(_, inner) | TCast(inner, _): vectorField(inner);
			case _: null;
		}
	}

	function vectorCapacity(e:TypedExpr):Null<String> {
		final cf = switch(e.expr) {
			case TLocal(v): return vectorSizes.get(v.id);
			case _: vectorField(e);
		}
		if(cf == null) return null;

		final rom = romValues(cf);
		if(rom != null) return Std.string(rom.length);

		final entry = cf.meta.extract(":md.size")[0];
		if(entry == null) return null;
		return switch(entry.params[0].expr) {
			case EConst(CInt(v)): v;
			case _: null;
		}
	}

	function vectorCall(callee:TypedExpr, args:Array<TypedExpr>, pos:haxe.macro.Expr.Position):Null<String> {
		final cf = switch(callee.expr) {
			case TField(_, FStatic(cRef, cfRef)) if(cRef.get().name == "VectorTools" && cRef.get().pack.join(".") == "md"):
				cfRef.get();
			case _: null;
		}
		if(cf == null) return null;

		final target = compileExpressionOrError(args[0]);
		final capacity = vectorCapacity(args[0]);

		if(cf.name == "length") {
			if(capacity == null)
				Context.error("This vector is a pointer here, so it has no length. Pass the length alongside it.", pos);
			return capacity;
		}

		final index = compileExpressionOrError(args[1]);
		final slot = (Context.defined("md-debug") && capacity != null)
			? target + "[(" + index + ") % " + capacity + "]"
			: target + "[" + index + "]";

		return cf.name == "get" ? slot : slot + " = " + compileExpressionOrError(args[2]);
	}

	function textCall(callee:TypedExpr, args:Array<TypedExpr>, pos:haxe.macro.Expr.Position):Null<String> {
		final cf = switch(callee.expr) {
			case TField(_, FStatic(cRef, cfRef)) if(cRef.get().name == "Text" && cRef.get().pack.join(".") == "md"):
				cfRef.get();
			case _: null;
		}
		if(cf == null) return null;

		final target = compileExpressionOrError(args[0]);
		return switch(cf.name) {
			case "length": "((s32)strlen(" + target + "))";
			case "charAt": "((s32)(u8)(" + target + ")[" + compileExpressionOrError(args[1]) + "])";
			case "address" | "pointer": "((s32)(" + target + "))";
			case "of": "((const char*)(" + target + "))";
			case _: Context.error("Unknown Text operation: " + cf.name, pos);
		}
	}

	function romValues(cf:ClassField):Null<Array<String>> {
		final entry = cf.meta.extract(":romData")[0];
		if(entry == null) return null;
		if(entry.params.length != 1) Context.error("@:romData takes one array of constants.", entry.pos);

		final items = switch(entry.params[0].expr) {
			case EArrayDecl(items): items;
			case _: Context.error("@:romData needs an array, as in @:romData([1, 2, 3]).", entry.pos);
		}

		return items.map(item -> switch(item.expr) {
			case EConst(CInt(v)): v;
			case EConst(CString(s)): '"' + escape(s) + '"';
			case EUnop(OpNeg, false, {expr: EConst(CInt(v))}): "-" + v;
			case _: Context.error("@:romData holds constants only.", item.pos);
		});
	}

	public function compileClassImpl(classType:ClassType, varFields:Array<ClassVarData>,
			funcFields:Array<ClassFuncData>):Null<String> {
		if(classType.isExtern) return null;

		if(classType.superClass != null)
			Context.error("Inheritance is not supported on this target yet.", classType.pos);
		if(classType.interfaces.length > 0)
			Context.error("Interfaces are not supported on this target yet.", classType.pos);

		vectorSizes = [];

		final prefix = classPrefix(classType);
		final instanceVars = varFields.filter(v -> !v.isStatic);
		final capacity = poolCapacity(classType);
		final ctor = Lambda.find(funcFields, f -> !f.isStatic && f.field.name == "new");
		final hasInstances = instanceVars.length > 0 || ctor != null
			|| Lambda.exists(funcFields, f -> !f.isStatic);

		final body = [];

		if(hasInstances) emitStruct(classType, prefix, instanceVars);
		if(capacity != null) {
			if(capacity <= 0) Context.error("@:md.pool capacity must be positive.", classType.pos);
			emitPool(prefix, capacity, body);
		}

		for(v in varFields) if(v.isStatic) emitVar(classType, v, body);
		for(f in funcFields) emitFunc(classType, prefix, f, body);

		if(ctor != null && capacity != null) emitCreate(prefix, ctor, body);

		if(body.length == 0) return null;
		return '#include "${HEADER}"\n\n' + body.join("\n\n") + "\n";
	}

	static function enumIsSimple(e:EnumType):Bool {
		for(name in e.names) {
			final field = e.constructs.get(name);
			if(field == null) continue;
			switch(field.type) {
				case TFun(_, _): return false;
				case _:
			}
		}
		return true;
	}

	function enumPrefix(e:EnumType):String {
		return safe(e.globalName());
	}

	function enumTag(e:TypedExpr, pos:haxe.macro.Expr.Position):String {
		final holder = switch(haxe.macro.TypeTools.follow(e.t)) {
			case TEnum(eRef, _): eRef.get();
			case _: Context.error("Not an enum value.", pos);
		}
		final target = compileExpressionOrError(e);
		return enumIsSimple(holder) ? target : "(" + target + ").tag";
	}

	function enumConstruct(ef:EnumField, holder:EnumType, args:Array<String>,
			pos:haxe.macro.Expr.Position):String {
		final prefix = enumPrefix(holder);
		final name = safe(ef.name);

		if(enumIsSimple(holder)) {
			if(args.length > 0) Context.error("This constructor takes no arguments.", pos);
			return prefix + "_" + name;
		}

		final tag = ".tag = " + prefix + "_tag_" + name;
		if(args.length == 0) return "((" + prefix + "){ " + tag + " })";
		return "((" + prefix + "){ " + tag + ", .data." + name + " = { " + args.join(", ") + " } })";
	}

	public function compileEnumImpl(enumType:EnumType, constructs:Array<EnumOptionData>):Null<String> {
		final prefix = enumPrefix(enumType);

		if(enumIsSimple(enumType)) {
			final values = [];
			for(i in 0...constructs.length)
				values.push("\t" + prefix + "_" + safe(constructs[i].name) + " = " + i);
			appendToExtraFile(HEADER, "typedef enum {\n" + values.join(",\n") + "\n} " + prefix + ";\n\n", P_STRUCTS);
			return null;
		}

		appendToExtraFile(HEADER, 'typedef struct $prefix $prefix;\n', P_TYPEDEFS);

		final tags = [];
		final members = [];
		for(i in 0...constructs.length) {
			final option = constructs[i];
			tags.push("\t" + prefix + "_tag_" + safe(option.name) + " = " + i);
			if(option.args.length == 0) continue;
			final fields = option.args.map(a -> toC(a.type, enumType.pos) + " " + safe(a.name) + ";");
			members.push("\t\tstruct { " + fields.join(" ") + " } " + safe(option.name) + ";");
		}

		appendToExtraFile(HEADER, "typedef enum {\n" + tags.join(",\n") + "\n} " + prefix + "_tag;\n\n"
			+ 'struct $prefix {\n\tu8 tag;\n\tunion {\n' + members.join("\n") + "\n\t} data;\n};\n\n", P_STRUCTS);
		return null;
	}

	function block(expr:TypedExpr):String {
		final list = expr.unwrapBlock();
		final out = [];
		for(e in list) {
			final s = statement(e);
			if(s != null && s.length > 0) out.push(s);
		}
		return out.join("\n");
	}

	function statement(expr:TypedExpr):Null<String> {
		final s = compileExpression(expr, true);
		if(s == null || s.length == 0) return null;
		return needsSemicolon(expr) ? s + ";" : s;
	}

	static function needsSemicolon(expr:TypedExpr):Bool {
		return switch(expr.expr) {
			case TBlock(_) | TIf(_, _, _) | TWhile(_, _, _) | TFor(_, _, _) | TSwitch(_, _, _): false;
			case TMeta(_, e) | TParenthesis(e): needsSemicolon(e);
			case _: true;
		}
	}

	function nested(expr:TypedExpr):String {
		return switch(expr.expr) {
			case TBlock(_): "{\n" + block(expr).tab() + "\n}";
			case _: {
				final s = statement(expr);
				"{\n" + (s == null ? "" : s).tab() + "\n}";
			}
		}
	}

	public function compileExpressionImpl(expr:TypedExpr, topLevel:Bool):Null<String> {
		return switch(expr.expr) {
			case TConst(c): constant(c, expr.pos);

			case TLocal(v): varName(v);

			case TParenthesis(e): "(" + compileExpressionOrError(e) + ")";

			case TMeta(_, e): compileExpression(e, topLevel);

			case TCast(e, _): compileExpression(e, topLevel);

			case TBlock(_): "{\n" + block(expr).tab() + "\n}";

			case TVar(v, e): {
				var rom = false;
				if(e != null) {
					final capacity = vectorCapacity(e);
					if(capacity != null) vectorSizes.set(v.id, capacity);
					final field = vectorField(e);
					rom = field != null && field.meta.has(":romData");
				}
				final decl = (rom ? "const " : "") + toC(v.t, expr.pos) + " " + varName(v);
				e == null ? decl : decl + " = " + compileExpressionOrError(e);
			}

			case TBinop(OpUShr, e1, e2):
				"(s32)((u32)(" + compileExpressionOrError(e1) + ") >> (" + compileExpressionOrError(e2) + "))";

			case TBinop(OpAssignOp(OpUShr), e1, e2): {
				switch(e1.expr) {
					case TLocal(_) | TField(_, FStatic(_, _)):
					case _: Context.error("`>>>=` requires a simple variable on the left.", expr.pos);
				}
				final target = compileExpressionOrError(e1);
				target + " = (s32)((u32)(" + target + ") >> (" + compileExpressionOrError(e2) + "))";
			}

			case TBinop(OpNullCoal | OpAssignOp(OpNullCoal), _, _):
				Context.error("Null coalescing is not supported on this target.", expr.pos);

			case TBinop(op, e1, e2):
				compileExpressionOrError(e1) + " " + op.binopToString() + " " + compileExpressionOrError(e2);

			case TUnop(op, postFix, e): {
				final inner = compileExpressionOrError(e);
				final o = unopToString(op, expr.pos);
				postFix ? inner + o : o + inner;
			}

			case TField(e, fa): field(e, fa, expr.pos);

			case TTypeExpr(_): "";

			case TCall(_, _) if(expr.isStaticCall("Std", "int") != null): {
				final args = expr.isStaticCall("Std", "int");
				compileExpressionOrError(args[0]);
			}

			case TCall(callee, el): {
				final intrinsic = poolCall(callee, el, expr.pos) ?? vectorCall(callee, el, expr.pos)
					?? textCall(callee, el, expr.pos);
				if(intrinsic != null) intrinsic else switch(callee.expr) {
					case TField(_, FEnum(eRef, ef)): {
						addModuleTypeForCompilation(TEnumDecl(eRef));
						enumConstruct(ef, eRef.get(), el.map(a -> compileExpressionOrError(a)), expr.pos);
					}

					case TField(obj, FInstance(cRef, _, cfRef)) if(isMethod(cfRef.get())): {
						final c = cRef.get();
						rejectStringMember(c, cfRef.get().name, expr.pos);
						if(c.isExtern) noteInclude(c) else addModuleTypeForCompilation(TClassDecl(cRef));
						final args = [compileExpressionOrError(obj)].concat(el.map(a -> compileExpressionOrError(a)));
						methodName(c, cfRef.get()) + "(" + args.join(", ") + ")";
					}
					case _: {
						final args = el.map(a -> compileExpressionOrError(a)).join(", ");
						compileExpressionOrError(callee) + "(" + args + ")";
					}
				}
			}

			case TReturn(e): e == null ? "return" : "return " + compileExpressionOrError(e);

			case TBreak: "break";

			case TContinue: "continue";

			case TIf(cond, ifExpr, elseExpr): {
				var s = "if(" + compileExpressionOrError(cond) + ")\n" + nested(ifExpr);
				if(elseExpr != null) s += "\nelse\n" + nested(elseExpr);
				s;
			}

			case TWhile(cond, e, normalWhile): {
				final c = compileExpressionOrError(cond);
				normalWhile
					? "while(" + c + ")\n" + nested(e)
					: "do\n" + nested(e) + "\nwhile(" + c + ");";
			}

			case TSwitch(subject, cases, edef): switchChain(subject, cases, edef);

			case TObjectDecl(_): Context.error("Anonymous structures are not supported on this target yet.", expr.pos);
			case TArrayDecl(_) | TArray(_, _): Context.error("Arrays are not supported on this target yet. Use md.Vector.", expr.pos);
			case TNew(cRef, _, args): {
				final c = cRef.get();
				final prefix = classPrefix(c);
				if(poolCapacity(c) == null)
					Context.error('${c.name} has no pool to allocate from. Add @:md.pool(n) above the class.', expr.pos);
				addModuleTypeForCompilation(TClassDecl(cRef));
				prefix + "_create(" + args.map(a -> compileExpressionOrError(a)).join(", ") + ")";
			}
			case TFunction(_): Context.error("Closures are not supported on this target.", expr.pos);
			case TThrow(_) | TTry(_, _): Context.error("Exceptions are not supported on this target.", expr.pos);
			case TFor(_, _, _): Context.error("for-in is not supported on this target yet. Use a while loop.", expr.pos);
			case TEnumIndex(e): enumTag(e, expr.pos);

			case TEnumParameter(e, ef, index): {
				final holder = switch(haxe.macro.TypeTools.follow(e.t)) {
					case TEnum(eRef, _): eRef.get();
					case _: Context.error("Not an enum value.", expr.pos);
				}
				final arg = switch(ef.type) {
					case TFun(args, _): args[index].name;
					case _: Context.error("This constructor carries no arguments.", expr.pos);
				}
				"(" + compileExpressionOrError(e) + ").data." + safe(ef.name) + "." + safe(arg);
			}
			case TIdent(s): Context.error('Unknown identifier: $s', expr.pos);
		}
	}

	static function isEnumTag(e:TypedExpr):Bool {
		return switch(e.expr) {
			case TEnumIndex(_): true;
			case TParenthesis(inner) | TMeta(_, inner) | TCast(inner, _): isEnumTag(inner);
			case _: false;
		}
	}

	function isCaseConstant(e:TypedExpr):Bool {
		return switch(e.expr) {
			case TConst(TInt(_)) | TConst(TBool(_)): true;
			case TField(_, FEnum(eRef, _)): enumIsSimple(eRef.get());
			case TParenthesis(inner) | TMeta(_, inner) | TCast(inner, _): isCaseConstant(inner);
			case _: false;
		}
	}

	function switchChain(subject:TypedExpr, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>,
			edef:Null<TypedExpr>):String {
		final subj = compileExpressionOrError(subject);

		var switchable = cases.length > 0;
		for(c in cases) for(v in c.values) if(!isCaseConstant(v)) switchable = false;

		if(!switchable) return ifChain(subj, cases, edef);

		final exhaustive = edef == null && isEnumTag(subject);

		final out = ["switch(" + subj + ")", "{"];
		for(index in 0...cases.length) {
			final c = cases[index];
			if(exhaustive && index == cases.length - 1) out.push("\tdefault:");
			else for(v in c.values) out.push(("case " + compileExpressionOrError(v) + ":").tab());
			out.push("\t{");
			out.push((block(c.expr) + "\nbreak;").tab().tab());
			out.push("\t}");
		}
		if(edef != null) {
			out.push("\tdefault:");
			out.push("\t{");
			out.push((block(edef) + "\nbreak;").tab().tab());
			out.push("\t}");
		}
		out.push("}");
		return out.join("\n");
	}

	function ifChain(subj:String, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>,
			edef:Null<TypedExpr>):String {
		final parts = [];
		for(c in cases) {
			final tests = c.values.map(v -> "(" + subj + " == " + compileExpressionOrError(v) + ")").join(" || ");
			parts.push((parts.length == 0 ? "if(" : "else if(") + tests + ")\n" + nested(c.expr));
		}
		if(edef != null) {
			parts.push(parts.length == 0 ? nested(edef) : "else\n" + nested(edef));
		}
		return parts.join("\n");
	}

	function field(e:TypedExpr, fa:FieldAccess, pos:haxe.macro.Expr.Position):String {
		return switch(fa) {
			case FStatic(cRef, cfRef): {
				final c = cRef.get();
				if(c.isExtern) noteInclude(c);
				else addModuleTypeForCompilation(TClassDecl(cRef));
				fieldName(c, cfRef.get(), true);
			}
			case FEnum(eRef, ef): {
				addModuleTypeForCompilation(TEnumDecl(eRef));
				enumConstruct(ef, eRef.get(), [], pos);
			}
			case FInstance(cRef, _, cfRef): {
				final cf = cfRef.get();
				rejectStringMember(cRef.get(), cf.name, pos);
				if(isMethod(cf))
					Context.error("A method used as a value would need a closure, which this target has no heap for.", pos);
				addModuleTypeForCompilation(TClassDecl(cRef));
				compileExpressionOrError(e) + "->" + memberName(cf);
			}
			case FAnon(_) | FClosure(_, _) | FDynamic(_):
				Context.error("Dynamic field access is not supported on this target.", pos);
		}
	}

	function constant(c:TConstant, pos:haxe.macro.Expr.Position):String {
		return switch(c) {
			case TInt(i): Std.string(i);
			case TFloat(_): Context.error("Floating point is not available on the 68000.", pos);
			case TString(s): '"' + escape(s) + '"';
			case TBool(b): b ? "TRUE" : "FALSE";
			case TNull: "NULL";
			case TThis: "self";
			case TSuper: Context.error("super is not supported on this target yet.", pos);
		}
	}

	static function escape(s:String):String {
		return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t");
	}

	static function unopToString(op:haxe.macro.Expr.Unop, pos:haxe.macro.Expr.Position):String {
		return switch(op) {
			case OpIncrement: "++";
			case OpDecrement: "--";
			case OpNot: "!";
			case OpNeg: "-";
			case OpNegBits: "~";
			case OpSpread: Context.error("Spread operator is not supported.", pos);
		}
	}
}

#end
