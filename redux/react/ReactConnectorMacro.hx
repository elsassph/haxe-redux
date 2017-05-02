package redux.react;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import react.jsx.JsxStaticMacro;
import react.ReactMacro;

class ReactConnectorMacro {
	static inline var CONNECT_META = ':connect';
	static inline var CONNECTED_META = ':connected_by_macro';
	static inline var DEFAULT_CONNECTED_FIELD_NAME = '_connected';

	static function addBuilder() react.ReactComponentMacro.appendBuilder(buildComponent);

	static function buildComponent(inClass:ClassType, fields:Array<Field>):Array<Field>
	{
		if (inClass.meta.has(CONNECTED_META)) return fields;

		if (inClass.meta.has(CONNECT_META))
		{
			if (inClass.meta.has(JsxStaticMacro.META_NAME))
				Context.fatalError(
					'Cannot use @${CONNECT_META} and @${JsxStaticMacro.META_NAME} on the same component',
					inClass.pos
				);

			var fieldName = DEFAULT_CONNECTED_FIELD_NAME;
			while (hasField(fields, fieldName)) fieldName = '_$fieldName';

			var connectMeta = inClass.meta.extract(CONNECT_META).shift();
			var connectParams = getConnectParams(connectMeta.params, fields);

			fields.push({
				access: [APublic, AStatic],
				name: fieldName,
				kind: FVar(null, macro redux.react.ReactRedux.connect($a{connectParams})($i{inClass.name})),
				doc: null,
				meta: null,
				pos: connectMeta.pos
			});

			inClass.meta.add(JsxStaticMacro.META_NAME, [macro $v{fieldName}], connectMeta.pos);
			inClass.meta.add(CONNECTED_META, [], inClass.pos);
		}

		return fields;
	}

	static function getConnectParams(params:Array<Expr>, fields:Array<Field>):Array<Expr>
	{
		if (params.length > 0) return params;

		var mapStateToProps:Null<Expr> = null;
		var mapDispatchToProps:Null<Expr> = null;
		var mergeProps:Null<Expr> = null;
		var options:Null<Expr> = null;

		for (f in fields)
		{
			if (Lambda.has(f.access, AStatic))
			{
				switch (f.name)
				{
					case 'mapStateToProps': mapStateToProps = macro mapStateToProps;
					case 'mapDispatchToProps': mapDispatchToProps = macro mapDispatchToProps;
					case 'mergeProps': mergeProps = macro mergeProps;
					case 'options': options = macro options;
					default:
				}
			}
		}

		if (mapStateToProps == null && mapDispatchToProps == null && mergeProps == null && options == null)
			return [];

		if (mapStateToProps == null) mapStateToProps = macro null;
		if (mapDispatchToProps == null && (mergeProps != null || options != null)) mapDispatchToProps = macro null;
		if (mergeProps == null && options != null) mergeProps = macro null;

		var ret = [mapStateToProps];
		if (mapDispatchToProps != null) ret.push(mapDispatchToProps);
		if (mergeProps != null) ret.push(mergeProps);
		if (options != null) ret.push(options);
		return ret;
	}

	static function hasField(fields:Array<Field>, fieldName:String):Bool
	{
		for (f in fields)
			if (f.name == fieldName) return true;

		return false;
	}
}
