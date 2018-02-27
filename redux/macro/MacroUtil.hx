package redux.macro;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;

@:publicFields
class MacroUtil {
	static function unifyComplexTypes(type1:ComplexType, type2:ComplexType):Bool
	{
		if (type1 == null && type2 == null) return true;
		if (type1 == null || type2 == null) return false;

		return TypeTools.unify(
			ComplexTypeTools.toType(type1),
			ComplexTypeTools.toType(type2)
		);
	}

	static function getAnonymousFields(complexType:ComplexType):Array<ClassField>
	{
		var type = ComplexTypeTools.toType(complexType);

		return switch (type) {
			case TType(_.get().type => t, _):
				switch (t)
				{
					case TAnonymous(_.get() => {fields: fields, status: _}): fields;
					default: null;
				}

			case TAnonymous(_.get() => {fields: fields, status: _}): fields;
			default: null;
		}
	}

	static function hasField(fields:Array<Field>, fieldName:String):Bool
	{
		for (f in fields)
			if (f.name == fieldName) return true;

		return false;
	}

	static function printFunctionSignature(
		args:Array<Type>,
		ret:Type
	) {
		return args
			.concat([ret])
			.map(TypeTools.toString)
			.map(function(arg) return arg.indexOf('->') > 0 ? '($arg)' : arg)
			.join(' -> ');
	}

	static function getPartialType(type:ComplexType):ComplexType
	{
		return TPath({
			name: 'Partial',
			pack: ['react'],
			params: [TPType(type)]
		});
	}

	static function isDispatch(complexType:ComplexType):Bool
	{
		var type = ComplexTypeTools.toType(complexType);
		return TypeTools.toString(type) == 'redux.Dispatch';
	}

	static function extractMetaString(metadata:MetaAccess, name:String):String
	{
		if (!metadata.has(name)) return null;

		var metas = metadata.extract(name);
		if (metas.length == 0) return null;

		var params = metas[0].params;
		if (params.length == 0) return null;

		return ExprTools.getValue(params[0]);
	}
}
