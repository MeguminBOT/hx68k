package mdcompiler;

#if (macro || md_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

import reflaxe.DirectToStringCompiler;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.input.ClassHierarchyTracker;

using StringTools;
using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.OperatorHelper;
using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.TypedExprHelper;

class Compiler extends DirectToStringCompiler {
	public static inline final HEADER = "hx.h";
	public static inline final ENTRY = "hx_entry.c";
	public static inline final IFACES = "hx_interfaces.c";

	static inline final P_PROLOGUE = 0;
	static inline final P_INCLUDES = 5;
	static inline final P_TYPEDEFS = 7;
	static inline final P_STRUCTS = 8;
	static inline final P_GLOBALS = 10;
	static inline final P_PROTOS = 20;
	static inline final P_EPILOGUE = 90;

	static final IDENT = ~/[^A-Za-z0-9_]/g;

	static inline final MARK_OPEN = "\x01";
	static inline final MARK_CLOSE = "\x02";

	var entryPoint:Null<String> = null;
	var includes:Map<String, Bool> = [];
	var interfaceTypes:Map<String, Bool> = [];
	var interfaceTables:Map<String, Bool> = [];
	var vectorFields:Map<Int, ClassField> = [];
	var currentClass:Null<ClassType> = null;
	var lineStarts:Map<String, Array<Int>> = [];
	var sourceIndex:Map<String, Int> = [];
	var sources:Array<String> = [];
	var marks:Array<{file:Int, line:Int, symbol:Null<String>, haxe:Null<String>}> = [];
	var statics:Array<String> = [];
	var lifted:Array<String> = [];
	var currentReturn:Null<Type> = null;

	public override function onCompileStart() {
		entryPoint = null;
		includes = [];
		interfaceTypes = [];
		interfaceTables = [];

		final main = getMainModule();
		if(main != null) addModuleTypeForCompilation(main);

		setExtraFile(HEADER, "");
		appendToExtraFile(HEADER, "#ifndef _HX_H_\n#define _HX_H_\n\n#include <genesis.h>", P_PROLOGUE);
		appendToExtraFile(HEADER, "extern s32 hx_bounds_hits;\n", P_GLOBALS);
		if(Context.defined("md-debug"))
			appendToExtraFile(HEADER, "static inline s32 hx_bounds(s32 index, s32 capacity)\n{\n"
				+ "\tif((u32)index >= (u32)capacity) { hx_bounds_hits++; return 0; }\n"
				+ "\treturn index;\n}\n", P_PROTOS);
		appendToExtraFile(HEADER, "#endif", P_EPILOGUE);
	}

	public override function onCompileEnd() {
		final entry = entryPoint;
		if(entry == null) {
			Context.error("No entry point. Mark a static function with @:md.main.", Context.currentPos());
			return;
		}
		setExtraFile(ENTRY, '#include "${HEADER}"\n\ns32 hx_bounds_hits = 0;\n\n'
			+ 'int main(bool hardReset)\n{\n\t(void)hardReset;\n\t${entry}();\n\treturn 0;\n}\n');
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
				declare(params[0], "*", pos);

			case TInst(cRef, params) if(cRef.get().name == "VectorData"):
				declare(params[0], "*", pos);

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
				} else if(c.isInterface) {
					interfaceType(c);
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
			case TFun(args, ret): functionPointer(args, ret, "", pos);
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
			case TInst(cRef, _): !cRef.get().isInterface;
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

	function lineOf(file:String, offset:Int):Int {
		var starts = lineStarts.get(file);
		if(starts == null) {
			starts = [0];
			final bytes = try sys.io.File.getBytes(file) catch(e:Dynamic) null;
			if(bytes != null) for(i in 0...bytes.length) if(bytes.get(i) == 10) starts.push(i + 1);
			lineStarts.set(file, starts);
		}
		var low = 0;
		var high = starts.length - 1;
		while(low < high) {
			final mid = (low + high + 1) >> 1;
			if(starts[mid] <= offset) low = mid else high = mid - 1;
		}
		return low + 1;
	}

	function sourceOf(file:String):Int {
		final known = sourceIndex.get(file);
		if(known != null) return known;
		final index = sources.length;
		sources.push(file);
		sourceIndex.set(file, index);
		return index;
	}

	function mark(pos:haxe.macro.Expr.Position, symbol:Null<String> = null, haxe:Null<String> = null):String {
		final info = Context.getPosInfos(pos);
		if(!sys.FileSystem.exists(info.file)) return "";
		marks.push({file: sourceOf(info.file), line: lineOf(info.file, info.min), symbol: symbol, haxe: haxe});
		return MARK_OPEN + (marks.length - 1) + MARK_CLOSE;
	}

	function markStatic(pos:haxe.macro.Expr.Position, symbol:String, haxe:String, ctype:String):Void {
		final info = Context.getPosInfos(pos);
		if(!sys.FileSystem.exists(info.file)) return;
		statics.push('static $symbol ${sourceOf(info.file)} ${lineOf(info.file, info.min)} $haxe $ctype');
	}

	function writeMap(prefix:String, content:String):String {
		final records = [];
		final lines = content.split("\n");

		for(i in 0...lines.length) {
			var text = lines[i];
			var first = true;
			while(true) {
				final open = text.indexOf(MARK_OPEN);
				if(open < 0) break;
				final close = text.indexOf(MARK_CLOSE, open);
				final index = Std.parseInt(text.substring(open + 1, close));
				text = text.substring(0, open) + text.substring(close + 1);
				if(!first) continue;
				first = false;
				final m = marks[index];
				records.push(m.symbol == null ? 'line ${i + 1} ${m.file} ${m.line}'
					: 'function ${m.symbol} ${i + 1} ${m.file} ${m.line} ${m.haxe}');
			}
			lines[i] = text;
		}

		final head = ["hxmap 1", 'source $prefix.c', "root " + haxe.io.Path.removeTrailingSlashes(Sys.getCwd().split("\\").join("/"))];
		for(i in 0...sources.length) head.push('file $i ' + sources[i].split("\\").join("/"));
		setExtraFile(prefix + ".hxmap", head.concat(statics).concat(records).join("\n") + "\n");
		return lines.join("\n");
	}

	static function isInterfaceType(t:Type):Null<ClassType> {
		return switch(haxe.macro.TypeTools.follow(t)) {
			case TInst(cRef, _): cRef.get().isInterface ? cRef.get() : null;
			case _: null;
		}
	}

	function ifaceSlotSignature(cf:ClassField):String {
		final sig = functionType(cf, cf.pos);
		final params = ["void*"];
		for(a in sig.args) params.push(toC(a, cf.pos));
		return toC(sig.ret, cf.pos) + " (*)(" + params.join(", ") + ")";
	}

	function interfaceType(c:ClassType):String {
		final name = classPrefix(c);
		if(interfaceTypes.exists(name)) return name;
		interfaceTypes.set(name, true);

		final vt = name + "__vt";
		appendToExtraFile(HEADER, 'typedef struct $name $name;\ntypedef struct $vt $vt;\n', P_TYPEDEFS);

		final members = [];
		for(cf in c.fields.get()) {
			if(!isMethod(cf)) continue;
			final sig = functionType(cf, cf.pos);
			final params = ["void*"];
			for(a in sig.args) params.push(toC(a, cf.pos));
			members.push("\t" + toC(sig.ret, cf.pos) + " (*" + memberName(cf) + ")(" + params.join(", ") + ");");
		}
		if(members.length == 0) members.push("\tu8 empty;");

		appendToExtraFile(HEADER, 'struct $vt {\n' + members.join("\n") + "\n};\n\n"
			+ 'struct $name {\n\tvoid* self;\n\tconst $vt* vt;\n};\n\n', P_STRUCTS);
		return name;
	}

	function interfaceTable(cls:ClassType, iface:ClassType):String {
		final name = classPrefix(cls) + "__" + classPrefix(iface);
		if(interfaceTables.exists(name)) return name;
		interfaceTables.set(name, true);

		final vt = interfaceType(iface) + "__vt";
		final values = [];
		for(cf in iface.fields.get()) {
			if(!isMethod(cf)) continue;
			final impl = resolveMethod(cls, cf.name);
			if(impl == null || impl.field.expr() == null)
				Context.error(cls.name + " has no body for " + cf.name + ", which " + iface.name
					+ " needs.", cls.pos);
			values.push("\t(" + ifaceSlotSignature(cf) + ")" + methodName(impl.owner, impl.field));
		}
		if(values.length == 0) values.push("\t0");

		appendToExtraFile(HEADER, 'extern const $vt $name;\n', P_GLOBALS);
		if(getExtraFileContent(IFACES, P_PROLOGUE).length == 0)
			appendToExtraFile(IFACES, '#include "${HEADER}"\n\n', P_PROLOGUE);
		appendToExtraFile(IFACES, 'const $vt $name = {\n' + values.join(",\n") + "\n};\n\n", P_GLOBALS);
		return name;
	}

	static function isStoredVar(cf:ClassField):Bool {
		return switch(cf.kind) {
			case FVar(read, write): !read.match(AccCall | AccInline | AccRequire(_, _)) && !write.match(AccCall);
			case _: false;
		}
	}

	static function superOf(c:ClassType):Null<ClassType> {
		return c.superClass == null ? null : c.superClass.t.get();
	}

	static function storedVars(c:ClassType):Array<ClassField> {
		return c.fields.get().filter(cf -> isStoredVar(cf));
	}

	function inheritedVars(c:ClassType):Array<ClassField> {
		final base = superOf(c);
		if(base == null) return [];
		return inheritedVars(base).concat(storedVars(base));
	}

	function virtualSlots(c:ClassType):Array<{owner:ClassType, field:ClassField}> {
		final base = superOf(c);
		final out = base == null ? [] : virtualSlots(base);
		for(cf in c.fields.get()) {
			if(!isMethod(cf)) continue;
			if(Lambda.exists(out, s -> s.field.name == cf.name)) continue;
			if(ClassHierarchyTracker.funcHasChildOverride(c, cf, false)) out.push({owner: c, field: cf});
		}
		return out;
	}

	function vtType(c:ClassType):Null<String> {
		final slots = virtualSlots(c);
		if(slots.length == 0) return null;
		return classPrefix(slots[slots.length - 1].owner) + "__vt";
	}

	function resolveMethod(c:ClassType, name:String):Null<{owner:ClassType, field:ClassField}> {
		var k:Null<ClassType> = c;
		while(k != null) {
			for(cf in k.fields.get()) if(isMethod(cf) && cf.name == name) return {owner: k, field: cf};
			k = superOf(k);
		}
		return null;
	}

	function functionType(cf:ClassField, pos:haxe.macro.Expr.Position):{args:Array<Type>, ret:Type} {
		return switch(haxe.macro.TypeTools.follow(cf.type)) {
			case TFun(args, ret): {args: args.map(a -> a.t), ret: ret};
			case _: Context.error(cf.name + " is not a method.", pos);
		}
	}

	function slotParams(owner:ClassType, cf:ClassField):Array<String> {
		final params = [classPrefix(owner) + "*"];
		for(a in functionType(cf, cf.pos).args) params.push(toC(a, cf.pos));
		return params;
	}

	function slotMember(owner:ClassType, cf:ClassField):String {
		final sig = functionType(cf, cf.pos);
		return "\t" + toC(sig.ret, cf.pos) + " (*" + memberName(cf) + ")("
			+ slotParams(owner, cf).join(", ") + ");";
	}

	static function receiverRef(e:TypedExpr):Null<Ref<ClassType>> {
		return switch(haxe.macro.TypeTools.follow(e.t)) {
			case TInst(cRef, _): cRef;
			case _: null;
		}
	}

	function virtualTarget(c:ClassType, cf:ClassField):Null<{owner:ClassType, field:ClassField}> {
		if(c.isFinal) return null;
		final resolved = resolveMethod(c, cf.name);
		if(resolved == null) return null;
		return ClassHierarchyTracker.funcHasChildOverride(c, resolved.field, false) ? resolved : null;
	}

	static function isSimpleReceiver(e:TypedExpr):Bool {
		return switch(e.expr) {
			case TLocal(_) | TConst(TThis) | TTypeExpr(_): true;
			case TField(obj, _): isSimpleReceiver(obj);
			case TParenthesis(inner) | TMeta(_, inner) | TCast(inner, _): isSimpleReceiver(inner);
			case _: false;
		}
	}

	static function isClassPointer(t:Type):Bool {
		return switch(haxe.macro.TypeTools.follow(t)) {
			case TInst(cRef, _): {
				final c = cRef.get();
				!c.isExtern && !c.isInterface && !(c.name == "String" && c.pack.length == 0);
			}
			case _: false;
		}
	}

	function upcast(target:Type, from:Type, value:String, pos:haxe.macro.Expr.Position):String {
		final iface = isInterfaceType(target);
		if(iface != null) {
			final source = switch(haxe.macro.TypeTools.follow(from)) {
				case TInst(cRef, _): cRef.get();
				case _: null;
			}
			if(source == null || source.isInterface) return value;
			return "((" + interfaceType(iface) + "){ (void*)" + value + ", &"
				+ interfaceTable(source, iface) + " })";
		}
		if(!isClassPointer(target) || !isClassPointer(from)) return value;
		final a = toC(target, pos);
		return a == toC(from, pos) ? value : "(" + a + ")" + value;
	}

	function coerce(target:Type, e:TypedExpr):String {
		return upcast(target, e.t, compileExpressionOrError(e), e.pos);
	}

	function selfArg(owner:ClassType, receiver:ClassType, value:String):String {
		return classPrefix(owner) == classPrefix(receiver) ? value : "(" + classPrefix(owner) + "*)" + value;
	}

	function callArgs(callee:Type, el:Array<TypedExpr>):Array<String> {
		final types = switch(haxe.macro.TypeTools.follow(callee)) {
			case TFun(args, _): args.map(a -> a.t);
			case _: null;
		}
		final out = [];
		for(i in 0...el.length)
			out.push(types != null && i < types.length ? coerce(types[i], el[i])
				: compileExpressionOrError(el[i]));
		return out;
	}

	function ctorArgs(cf:ClassField):Array<{name:String, declaration:String}> {
		return switch(haxe.macro.TypeTools.follow(cf.type)) {
			case TFun(args, _): [for(i in 0...args.length) {
				name: args[i].name == null || args[i].name == "" ? "a" + i : safe(args[i].name),
				declaration: declare(args[i].t,
					args[i].name == null || args[i].name == "" ? "a" + i : safe(args[i].name), cf.pos)
			}];
			case _: Context.error("A constructor must be a function.", cf.pos);
		}
	}

	function instanceCall(obj:TypedExpr, declared:ClassType, cf:ClassField, el:Array<TypedExpr>,
			pos:haxe.macro.Expr.Position):String {
		final ref = receiverRef(obj);
		if(ref != null) addModuleTypeForCompilation(TClassDecl(ref));
		final c = ref == null ? declared : ref.get();
		final args = callArgs(cf.type, el);
		final target = compileExpressionOrError(obj);

		if(c.isInterface) {
			if(!isSimpleReceiver(obj))
				Context.error("An interface call reads its receiver twice. Bind it to a local first.", pos);
			interfaceType(c);
			return "(" + target + ").vt->" + memberName(cf)
				+ "(" + ["(" + target + ").self"].concat(args).join(", ") + ")";
		}

		final slot = virtualTarget(c, cf);

		if(slot == null) {
			final impl = resolveMethod(c, cf.name);
			if(impl == null) Context.error(c.name + " has no method " + cf.name + ".", pos);
			return methodName(impl.owner, impl.field)
				+ "(" + [selfArg(impl.owner, c, target)].concat(args).join(", ") + ")";
		}

		if(!isSimpleReceiver(obj))
			Context.error("A virtual call reads its receiver twice. Bind it to a local first.", pos);
		return "((const " + vtType(c) + "*)" + target + "->__vt)->" + memberName(cf)
			+ "(" + [selfArg(slot.owner, c, target)].concat(args).join(", ") + ")";
	}

	function section(meta:MetaAccess):String {
		final entry = meta.extract(":md.section")[0];
		if(entry == null) return "";
		return switch(entry.params[0].expr) {
			case EConst(CString(name)): ' __attribute__((section("' + name + '")))';
			case _: Context.error("@:md.section requires a constant String.", entry.pos);
		}
	}

	function attributes(meta:MetaAccess):String {
		return (meta.has(":md.noinline") ? "__attribute__((noinline)) " : "");
	}

	function functionPointer(args:Array<{t:Type, opt:Bool, name:String}>, ret:Type, name:String,
			pos:haxe.macro.Expr.Position):String {
		final params = args.map(a -> toC(a.t, pos));
		return toC(ret, pos) + " (*" + name + ")(" + (params.length == 0 ? "void" : params.join(", ")) + ")";
	}

	function declare(t:Type, name:String, pos:haxe.macro.Expr.Position):String {
		return switch(haxe.macro.TypeTools.follow(t)) {
			case TFun(args, ret): functionPointer(args, ret, name, pos);
			case TAbstract(aRef, params) if(aRef.get().name == "Vector" && aRef.get().pack.join(".") == "md"):
				declare(params[0], "*" + name, pos);
			case TInst(cRef, params) if(cRef.get().name == "VectorData"):
				declare(params[0], "*" + name, pos);
			case _: {
				final base = toC(t, pos);
				if(name == "") base else if(StringTools.startsWith(name, "*")) base + name else base + " " + name;
			}
		}
	}

	function declareField(cf:ClassField, name:String):String {
		final vector = isVector(cf.type);
		final slot = name + (vector ? storage(cf) : "");
		return vector ? declare(elementOf(cf.type, cf.pos), slot, cf.pos) : declare(cf.type, slot, cf.pos);
	}

	function elementOf(t:Type, pos:haxe.macro.Expr.Position):Type {
		return switch(haxe.macro.TypeTools.follow(t)) {
			case TAbstract(_, params): params[0];
			case _: Context.error("Not a vector type.", pos);
		}
	}

	function lift(f:TFunc, pos:haxe.macro.Expr.Position):String {
		final owner = currentClass == null ? "hx" : classPrefix(currentClass);
		final name = owner + "_lambda" + lifted.length;

		final bound:Map<Int, Bool> = [];
		for(a in f.args) bound.set(a.v.id, true);
		rejectCaptures(f.expr, bound, pos);

		final params = f.args.map(a -> declare(a.v.t, varName(a.v), pos));
		final signature = toC(f.t, pos) + " " + name + "("
			+ (params.length == 0 ? "void" : params.join(", ")) + ")";
		appendToExtraFile(HEADER, signature + ";\n", P_PROTOS);

		final outer = currentReturn;
		currentReturn = f.t;
		final origin = mark(pos, name, (currentClass == null ? "" : currentClass.name) + ".lambda");
		lifted.push(origin + signature + "\n{\n" + block(f.expr).tab() + "\n}");
		currentReturn = outer;

		return name;
	}

	function rejectCaptures(e:TypedExpr, bound:Map<Int, Bool>, pos:haxe.macro.Expr.Position):Void {
		switch(e.expr) {
			case TLocal(v):
				if(!bound.exists(v.id))
					Context.error("This function takes " + v.name + " with it, and there is no heap "
						+ "to take it on. Pass it as an argument or keep it in a static.", pos);
			case TConst(TThis):
				Context.error("This function takes `this` with it, which needs a capture this "
					+ "target has no heap for.", pos);
			case TVar(v, init): {
				bound.set(v.id, true);
				if(init != null) rejectCaptures(init, bound, pos);
			}
			case TFor(v, iterator, body): {
				bound.set(v.id, true);
				rejectCaptures(iterator, bound, pos);
				rejectCaptures(body, bound, pos);
			}
			case TFunction(inner): {
				for(a in inner.args) bound.set(a.v.id, true);
				rejectCaptures(inner.expr, bound, pos);
			}
			case _: haxe.macro.TypedExprTools.iter(e, child -> rejectCaptures(child, bound, pos));
		}
	}

	function emitStruct(prefix:String, fields:Array<ClassField>, vtable:Bool):Void {
		appendToExtraFile(HEADER, 'typedef struct $prefix $prefix;\n', P_TYPEDEFS);

		final members = vtable ? ["\tconst void* __vt;"] : [];
		for(cf in fields) members.push("\t" + declareField(cf, memberName(cf)) + ";");
		if(members.length == 0) members.push("\tu8 empty;");
		appendToExtraFile(HEADER, 'struct $prefix {\n' + members.join("\n") + "\n};\n\n", P_STRUCTS);
	}

	function emitVtableType(prefix:String, slots:Array<{owner:ClassType, field:ClassField}>):Void {
		final name = prefix + "__vt";
		appendToExtraFile(HEADER, 'typedef struct $name $name;\n', P_TYPEDEFS);
		final members = slots.map(s -> slotMember(s.owner, s.field));
		appendToExtraFile(HEADER, 'struct $name {\n' + members.join("\n") + "\n};\n\n", P_STRUCTS);
	}

	function emitVtable(classType:ClassType, prefix:String, slots:Array<{owner:ClassType, field:ClassField}>,
			body:Array<String>):Void {
		final values = slots.map(slot -> {
			final impl = resolveMethod(classType, slot.field.name);
			if(impl == null || impl.field.expr() == null)
				Context.error(classType.name + " has no body for " + slot.field.name + ", so its vtable "
					+ "slot would be empty.", classType.pos);
			final sig = functionType(slot.field, slot.field.pos);
			final signature = toC(sig.ret, slot.field.pos)
				+ " (*)(" + slotParams(slot.owner, slot.field).join(", ") + ")";
			"\t(" + signature + ")" + methodName(impl.owner, impl.field);
		});
		body.push("static const " + vtType(classType) + " " + prefix + "__vtable = {\n"
			+ values.join(",\n") + "\n};");
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

	function emitCreate(prefix:String, init:ClassType, args:Array<{name:String, declaration:String}>,
			vtable:Bool, body:Array<String>):Void {
		final params = args.map(a -> a.declaration);
		final signature = '$prefix* ${prefix}_create(' + (params.length == 0 ? "void" : params.join(", ")) + ")";
		final initPrefix = classPrefix(init);
		final names = [initPrefix == prefix ? "self" : '($initPrefix*)self'].concat(args.map(a -> a.name));

		appendToExtraFile(HEADER, signature + ";\n", P_PROTOS);
		body.push(signature + "\n{\n"
			+ '\t$prefix* self = ${prefix}_alloc();\n'
			+ "\tif(self == NULL) return NULL;\n"
			+ '\t${initPrefix}_init(' + names.join(", ") + ");\n"
			+ (vtable ? '\tself->__vt = &${prefix}__vtable;\n' : "")
			+ "\treturn self;\n}");
	}

	function inheritedCtor(c:ClassType):Null<{owner:ClassType, field:ClassField}> {
		var k:Null<ClassType> = c;
		while(k != null) {
			if(k.constructor != null) return {owner: k, field: k.constructor.get()};
			k = superOf(k);
		}
		return null;
	}

	function emitVar(classType:ClassType, v:ClassVarData, body:Array<String>):Void {
		final name = fieldName(classType, v.field, true);
		final vector = isVector(v.field.type);
		final rom = romValues(v.field);
		final slot = name + (vector ? (rom != null ? "[" + rom.length + "]" : storage(v.field)) : "");
		final plain = vector ? declare(elementOf(v.field.type, v.field.pos), slot, v.field.pos)
			: declare(v.field.type, slot, v.field.pos);
		final decl = (rom != null ? "const " : "") + (v.field.meta.has(":md.volatile") ? "volatile " + plain : plain);

		final placed = section(v.field.meta);

		appendToExtraFile(HEADER, 'extern $decl;\n', P_GLOBALS);
		final written = vector
			? StringTools.trim(declare(elementOf(v.field.type, v.field.pos), "", v.field.pos))
				+ (rom != null ? "[" + rom.length + "]" : storage(v.field))
			: StringTools.trim(declare(v.field.type, "", v.field.pos));
		markStatic(v.field.pos, name, classType.name + "." + v.field.name,
			(rom != null ? "const " : "") + written);

		if(rom != null) {
			body.push('$decl$placed = { ' + rom.join(", ") + " };");
			return;
		}

		if(vector) {
			body.push('$decl$placed;');
			return;
		}

		final init = switch(v.field.expr()) {
			case null: null;
			case e: compileExpression(e);
		}
		body.push(init != null ? '$decl$placed = $init;' : '$decl$placed;');
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

		final params = f.args.map(a -> declare(a.type, safe(a.getName()), f.field.pos));
		if(!f.isStatic) params.unshift('$prefix* self');
		final signature = ret + " " + name + "(" + (params.length == 0 ? "void" : params.join(", ")) + ")"
			+ section(f.field.meta);

		appendToExtraFile(HEADER, attributes(f.field.meta) + signature + ";\n", P_PROTOS);

		if(f.field.meta.has(":md.main")) {
			if(!f.isStatic) Context.error("@:md.main must mark a static function.", f.field.pos);
			if(entryPoint != null) Context.error("Multiple @:md.main entry points declared.", f.field.pos);
			entryPoint = name;
		}

		final expr = f.expr;
		if(expr == null) return;
		final outer = currentReturn;
		currentReturn = isCtor ? null : f.ret;
		final origin = mark(f.field.pos, name, classType.name + "." + f.field.name);
		body.push(origin + attributes(f.field.meta) + signature + "\n{\n" + block(expr).tab() + "\n}");
		currentReturn = outer;
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
			case TLocal(v): vectorFields.get(v.id);
			case TParenthesis(inner) | TMeta(_, inner) | TCast(inner, _): vectorField(inner);
			case _: null;
		}
	}

	function declaredCapacity(cf:ClassField):Null<String> {
		final rom = romValues(cf);
		if(rom != null) return Std.string(rom.length);

		final entry = cf.meta.extract(":md.size")[0];
		if(entry == null) return null;
		return switch(entry.params[0].expr) {
			case EConst(CInt(v)): v;
			case _: null;
		}
	}

	function vectorCapacity(e:TypedExpr):Null<String> {
		final cf = vectorField(e);
		return cf == null ? null : declaredCapacity(cf);
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

		final field = vectorField(args[0]);
		if(cf.name == "get" && field != null) {
			final rom = romValues(field);
			final constant = constantIndex(args[1]);
			if(rom != null && constant != null && constant >= 0 && constant < rom.length)
				return rom[constant];
		}

		final index = compileExpressionOrError(args[1]);
		final slot = (Context.defined("md-debug") && capacity != null)
			? target + "[hx_bounds(" + index + ", " + capacity + ")]"
			: target + "[" + index + "]";

		return cf.name == "get" ? slot : slot + " = " + compileExpressionOrError(args[2]);
	}

	static function constantIndex(e:TypedExpr):Null<Int> {
		return switch(e.expr) {
			case TConst(TInt(v)): v;
			case TParenthesis(inner) | TMeta(_, inner) | TCast(inner, _): constantIndex(inner);
			case _: null;
		}
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

	function memoryCall(callee:TypedExpr, args:Array<TypedExpr>, pos:haxe.macro.Expr.Position):Null<String> {
		final cf = switch(callee.expr) {
			case TField(_, FStatic(cRef, cfRef)) if(cRef.get().name == "Memory" && cRef.get().pack.join(".") == "md"):
				cfRef.get();
			case _: null;
		}
		if(cf == null) return null;

		if(cf.name == "addressOf") return "((s32)(" + compileExpressionOrError(args[0]) + "))";

		final width = switch(cf.name) {
			case "readU8" | "writeU8": "u8";
			case "readU16" | "writeU16": "u16";
			case "readU32" | "writeU32": "u32";
			case _: Context.error("Unknown Memory operation: " + cf.name, pos);
		}

		final at = "(*(volatile " + width + "*)(" + compileExpressionOrError(args[0]) + "))";
		return args.length > 1 ? "(" + at + " = " + compileExpressionOrError(args[1]) + ")" : at;
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

		if(classType.isInterface) return null;

		if(classType.superClass != null) addModuleTypeForCompilation(TClassDecl(classType.superClass.t));

		currentClass = classType;
		vectorFields = [];
		sourceIndex = [];
		sources = [];
		marks = [];
		statics = [];
		lifted = [];

		final prefix = classPrefix(classType);
		final instanceVars = inheritedVars(classType).concat(storedVars(classType));
		final slots = virtualSlots(classType);
		final capacity = poolCapacity(classType);
		final hasInstances = instanceVars.length > 0 || slots.length > 0 || classType.superClass != null
			|| classType.constructor != null || Lambda.exists(funcFields, f -> !f.isStatic);

		final body = [];

		if(hasInstances) emitStruct(prefix, instanceVars, slots.length > 0);
		if(slots.length > 0 && slots[slots.length - 1].owner == classType) emitVtableType(prefix, slots);
		if(capacity != null) {
			if(capacity <= 0) Context.error("@:md.pool capacity must be positive.", classType.pos);
			emitPool(prefix, capacity, body);
		}

		for(v in varFields) if(v.isStatic) emitVar(classType, v, body);
		for(f in funcFields) emitFunc(classType, prefix, f, body);

		if(capacity != null) {
			final made = inheritedCtor(classType);
			if(made == null)
				Context.error(classType.name + " has a pool but no constructor to fill a slot with.",
					classType.pos);
			if(slots.length > 0) emitVtable(classType, prefix, slots, body);
			emitCreate(prefix, made.owner, ctorArgs(made.field), slots.length > 0, body);
		}

		for(text in lifted) body.push(text);

		if(body.length == 0) return null;
		return writeMap(prefix, '#include "${HEADER}"\n\n' + body.join("\n\n") + "\n");
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
		return mark(expr.pos) + (needsSemicolon(expr) ? s + ";" : s);
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
					final field = vectorField(e);
					if(field != null) vectorFields.set(v.id, field);
					rom = field != null && field.meta.has(":romData");
				}
				final decl = (rom ? "const " : "") + declare(v.t, varName(v), expr.pos);
				e == null ? decl : decl + " = " + coerce(v.t, e);
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

			case TBinop(OpAssign, e1, e2):
				compileExpressionOrError(e1) + " = " + coerce(e1.t, e2);

			case TBinop(OpNullCoal | OpAssignOp(OpNullCoal), _, _):
				Context.error("Null coalescing is not supported on this target.", expr.pos);

			case TBinop(op, e1, e2): {
				final text = compileExpressionOrError(e1) + " " + op.binopToString() + " "
					+ compileExpressionOrError(e2);
				op.isAssign() ? text : "(" + text + ")";
			}

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

			case TCall({expr: TConst(TSuper)}, el): {
				final base = currentClass == null ? null : superOf(currentClass);
				if(base == null) Context.error("super() has no base class to call.", expr.pos);
				final made = inheritedCtor(base);
				if(made == null) Context.error(base.name + " has no constructor for super() to call.", expr.pos);
				final args = ["(" + classPrefix(made.owner) + "*)self"].concat(callArgs(made.field.type, el));
				classPrefix(made.owner) + "_init(" + args.join(", ") + ")";
			}

			case TCall({expr: TField({expr: TConst(TSuper)}, FInstance(_, _, cfRef))}, el): {
				final base = currentClass == null ? null : superOf(currentClass);
				if(base == null) Context.error("super has no base class here.", expr.pos);
				final impl = resolveMethod(base, cfRef.get().name);
				if(impl == null) Context.error(base.name + " has no " + cfRef.get().name + ".", expr.pos);
				final args = ["(" + classPrefix(impl.owner) + "*)self"].concat(callArgs(impl.field.type, el));
				methodName(impl.owner, impl.field) + "(" + args.join(", ") + ")";
			}

			case TCall(callee, el): {
				final intrinsic = poolCall(callee, el, expr.pos) ?? vectorCall(callee, el, expr.pos)
					?? textCall(callee, el, expr.pos) ?? memoryCall(callee, el, expr.pos);
				if(intrinsic != null) intrinsic else switch(callee.expr) {
					case TField(_, FEnum(eRef, ef)): {
						addModuleTypeForCompilation(TEnumDecl(eRef));
						enumConstruct(ef, eRef.get(), el.map(a -> compileExpressionOrError(a)), expr.pos);
					}

					case TField(obj, FInstance(cRef, _, cfRef)) if(isMethod(cfRef.get())): {
						final c = cRef.get();
						final cf = cfRef.get();
						rejectStringMember(c, cf.name, expr.pos);
						if(c.isExtern) {
							noteInclude(c);
							final args = [compileExpressionOrError(obj)].concat(callArgs(cf.type, el));
							methodName(c, cf) + "(" + args.join(", ") + ")";
						} else {
							addModuleTypeForCompilation(TClassDecl(cRef));
							instanceCall(obj, c, cf, el, expr.pos);
						}
					}
					case _: {
						final args = callArgs(callee.t, el).join(", ");
						compileExpressionOrError(callee) + "(" + args + ")";
					}
				}
			}

			case TReturn(e): e == null ? "return"
				: "return " + (currentReturn == null ? compileExpressionOrError(e) : coerce(currentReturn, e));

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
				final made = inheritedCtor(c);
				final compiled = made == null ? args.map(a -> compileExpressionOrError(a))
					: callArgs(made.field.type, args);
				prefix + "_create(" + compiled.join(", ") + ")";
			}
			case TFunction(f): lift(f, expr.pos);
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
			case TSuper: Context.error("super reaches a base constructor or method, and nothing else.", pos);
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
