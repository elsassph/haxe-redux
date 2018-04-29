package redux.react;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import react.jsx.JsxStaticMacro;
import react.wrap.ReactWrapperMacro;
import react.ReactMacro;

class ReactConnectorMacro {
	public static inline var CONNECT_META = ':connect';
	static inline var CONNECTED_META = ':connected_by_macro';
	static inline var DEFAULT_CONNECTED_FIELD_NAME = '_connected';

	// Use prepend to ensure @:connect is handled before @:wrap
	static function addBuilder() react.ReactComponentMacro.prependBuilder(buildComponent);

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
			var connectParams = getConnectParams(inClass, connectMeta.params, fields);

			fields.push({
				access: [APublic, AStatic],
				name: fieldName,
				kind: FVar(null, macro redux.react.ReactRedux.connect($a{connectParams})),
				doc: null,
				meta: null,
				pos: connectMeta.pos
			});

			// Prepare wrappers reordering
			var wrappers = extractWrappers(inClass.meta);
			inClass.meta.remove(ReactWrapperMacro.WRAP_META);
			inClass.meta.remove(CONNECT_META);
			for (w in wrappers.next) inClass.meta.add(w.name, w.params, w.pos);

			// Add new metas
			// Avoid typing here since it will fail (the class and its fields are not accessible yet)
			// The typing will be handled in `fieldName` anyway
			var wrapperExpr = macro untyped $i{inClass.name}.$fieldName;
			inClass.meta.add(CONNECTED_META, [], connectMeta.pos);
			inClass.meta.add(ReactWrapperMacro.WRAP_META, [wrapperExpr], connectMeta.pos);

			// Add old meta
			for (w in wrappers.prev) inClass.meta.add(w.name, w.params, w.pos);
		}

		return fields;
	}

	static function getConnectParams(inClass:ClassType, params:Array<Expr>, fields:Array<Field>):Array<Expr>
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
					case 'mapStateToProps': mapStateToProps = macro $i{inClass.name}.mapStateToProps;
					case 'mapDispatchToProps': mapDispatchToProps = macro $i{inClass.name}.mapDispatchToProps;
					case 'mergeProps': mergeProps = macro $i{inClass.name}.mergeProps;
					case 'options': options = macro $i{inClass.name}.options;
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

	static function extractWrappers(meta:MetaAccess):{next:Array<MetadataEntry>, prev:Array<MetadataEntry>}
	{
		var prevWrappers = [];
		var nextWrappers = [];
		var foundConnect = false;

		for (m in meta.get())
		{
			if (m.name == CONNECT_META)
			{
				foundConnect = true;
			}
			else if (m.name == ReactWrapperMacro.WRAP_META)
			{
				if (foundConnect) nextWrappers.push(m);
				else prevWrappers.push(m);
			}
		}

		nextWrappers.reverse();
		prevWrappers.reverse();

		return {
			next: nextWrappers,
			prev: prevWrappers
		};
	}
}
