package mdcompiler;

#if (macro || md_runtime)

import reflaxe.ReflectCompiler;
import reflaxe.preprocessors.ExpressionPreprocessor;

class CompilerInit {
	public static function Start() {
		#if !eval
		Sys.println("CompilerInit.Start can only be called from a macro context.");
		return;
		#end

		#if (haxe_ver < "4.3.0")
		Sys.println("Reflaxe/MegaDrive requires Haxe version 4.3.0 or greater.");
		return;
		#end

		ReflectCompiler.AddCompiler(new Compiler(), {
			expressionPreprocessors:[
				SanitizeEverythingIsExpression({}),
				PreventRepeatVariables({}),
				RemoveSingleExpressionBlocks,
				RemoveConstantBoolIfs,
				RemoveUnnecessaryBlocks,
				RemoveReassignedVariableDeclarations,
				RemoveLocalVariableAliases,
				MarkUnusedVariables,
			],
			fileOutputExtension: ".c",
			outputDirDefineName: "md-output",
			fileOutputType:FilePerClass,
			reservedVarNames:reservedNames(),
			targetCodeInjectionName: "__md__",
			manualDCE:true,
			trackUsedTypes:true
		});
	}

	static function reservedNames() {
		return [
			"auto", "break", "case", "char", "const", "continue", "default", "do",
			"double", "else", "enum", "extern", "float", "for", "goto", "if",
			"inline", "int", "long", "register", "restrict", "return", "short",
			"signed", "sizeof", "static", "struct", "switch", "typedef", "union",
			"unsigned", "void", "volatile", "while",
			"bool", "true", "false", "TRUE", "FALSE", "NULL", "main",
			"u8", "u16", "u32", "s8", "s16", "s32", "fix16", "fix32"
		];
	}
}

#end
