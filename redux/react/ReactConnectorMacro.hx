package redux.react;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import react.jsx.JsxStaticMacro;
import react.ReactMacro;
import redux.macro.MacroUtil.*;

enum ConnectedFunction {
	WithDispatch(field:Field);
	WithDispatchAndOwnProps(field:Field);
}

class ReactConnectorMacro {
	static inline var DEFAULT_JSX_STATIC:String = 'Connected';

	static function buildContainer():Array<Field>
	{
		var inClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();

		var wrappedComponent:Null<ComplexType> = null;
		var componentPropsType = macro :Dynamic;
		var ownPropsType = macro :Dynamic;
		var jsxStatic = getJsxStaticName(inClass);

		switch (inClass.superClass)
		{
			case {params: params, t: _.toString() => 'redux.react.ReactConnect'}:
				wrappedComponent = extractOptionalType(params[0]);
				componentPropsType = TypeTools.toComplexType(params[1]);
				ownPropsType = TypeTools.toComplexType(params[2]);

			default:
				Context.fatalError('You cannot inherit from a react connector', inClass.pos);
		}

		checkNonStaticFields(fields);
		checkReservedFields(fields, jsxStatic);

		var mapStateToProps = getMapStateToProps(fields, ownPropsType, componentPropsType);
		var mapDispatchToProps = getMapDispatchToProps(fields, ownPropsType, componentPropsType);
		var mergeProps = getMergeProps(fields, ownPropsType, componentPropsType);
		var options = getOptions(fields);

		if (mapStateToProps == null) addMapStateToProps(fields);
		if (mapDispatchToProps == null) addMapDispatchToProps(fields);
		if (mergeProps == null) addMergeProps(fields);
		if (options == null) addOptions(fields);

		addConnected(jsxStatic, wrappedComponent, inClass.name, fields);
		addRender(fields, componentPropsType, wrappedComponent, inClass);

		return fields;
	}

	static function extractOptionalType(type:Type):Null<ComplexType> {
		return switch (type) {
			case TType(_.get() => {name: 'TVoid'}, _): null;
			default: TypeTools.toComplexType(type);
		};
	}

	static function extractClassName(cls:Null<ComplexType>):Null<String>
	{
		if (cls == null) return null;

		return switch (cls) {
			case TPath({name: name}): name;
			default: null;
		}
	}

	static function checkNonStaticFields(fields:Array<Field>):Void
	{
		for (field in fields)
			if (!Lambda.has(field.access, AStatic))
				Context.fatalError('React connectors cannot have non-static fields', field.pos);
	}

	static function checkReservedFields(fields:Array<Field>, jsxStatic:String):Void
	{
		for (field in fields)
			switch (field.name) {
				case '$jsxStatic', 'get_$jsxStatic', 'render':
					Context.fatalError('Field ${field.name} is reserved', field.pos);

				default:
			}
	}

	static function getJsxStaticName(inClass:ClassType):String
	{
		if (inClass.meta.has(JsxStaticMacro.META_NAME))
			return extractMetaString(inClass.meta, JsxStaticMacro.META_NAME);

		inClass.meta.add(JsxStaticMacro.META_NAME, [macro $v{DEFAULT_JSX_STATIC}], inClass.pos);
		return DEFAULT_JSX_STATIC;
	}

	static function getMapStateToProps(
		fields:Array<Field>,
		propsType:ComplexType,
		componentPropsType:ComplexType
	):Field {
		for (field in fields)
		{
			if (field.name == 'mapStateToProps')
			{
				switch (field.kind)
				{
					case FFun({args: args, ret: ret}):
						// TODO:
						// Extract args and ret from function return, and call checkMapStateToProps
						// With them when args.length == 0 to ensure factory function's typing.

						if (args.length != 0)
							checkMapStateToProps(propsType, componentPropsType, args, ret, field.pos);

					default:
						Context.fatalError('mapStateToProps must be a function', field.pos);
				}

				return field;
			}
		}

		return null;
	}

	static function checkMapStateToProps(
		propsType:ComplexType,
		componentPropsType:ComplexType,
		args:Array<FunctionArg>,
		ret:ComplexType,
		pos:Position
	) {
		if (args.length == 0 || args.length > 2)
			Context.fatalError(
				'mapStateToProps must accept one or two arguments',
				pos
			);

		if (args.length == 2 && !unifyComplexTypes(args[1].type, propsType))
			Context.fatalError(
				'mapStateToProps: second argument must match '
				+ 'the container\'s props type.',
				pos
			);

		if (!unifyComplexTypes(ret, componentPropsType))
			if (!unifyComplexTypes(ret, getPartialType(componentPropsType)))
				Context.fatalError(
					'mapStateToProps must return the wrapped component\'s '
					+ 'props type (or a Partial<> of it)',
					pos
				);

	}

	static function getMapDispatchToProps(
		fields:Array<Field>,
		propsType:ComplexType,
		componentPropsType:ComplexType
	):Field {
		for (field in fields)
		{
			if (field.name == 'mapDispatchToProps')
			{
				switch (field.kind)
				{
					case FFun({args: args, ret: ret}):
						// TODO:
						// Extract args and ret from function return, and call checkMapDispatchToProps
						// With them when args.length == 0 to ensure factory function's typing.

						if (args.length != 0)
							checkMapDispatchToProps(propsType, componentPropsType, args, ret, field.pos);

					default:
						// Assuming mapDispatchToProps as object containing action creators
				}

				return field;
			}
		}

		return null;
	}

	static function checkMapDispatchToProps(
		propsType:ComplexType,
		componentPropsType:ComplexType,
		args:Array<FunctionArg>,
		ret:ComplexType,
		pos:Position
	) {
		if (args.length == 0 || args.length > 2)
			Context.fatalError(
				'mapDispatchToProps must accept one or two arguments',
				pos
			);

		if (!isDispatch(args[0].type))
			Context.fatalError(
				'mapDispatchToProps: first argument must of type Dispatch',
				pos
			);

		if (args.length == 2 && !unifyComplexTypes(args[1].type, propsType))
			Context.fatalError(
				'mapDispatchToProps: second argument must match '
				+ 'the container\'s props type.',
				pos
			);

		if (!unifyComplexTypes(ret, componentPropsType))
			if (!unifyComplexTypes(ret, getPartialType(componentPropsType)))
				Context.fatalError(
					'mapDispatchToProps must return the wrapped component\'s '
					+ 'props type (or a Partial<> of it)',
					pos
				);
	}

	static function getMergeProps(
		fields:Array<Field>,
		propsType:ComplexType,
		componentPropsType:ComplexType
	):Field {
		for (field in fields)
		{
			if (field.name == 'mergeProps')
			{
				switch (field.kind)
				{
					case FFun({args: args, ret: ret}):
						if (args.length != 3)
							Context.fatalError(
								'mergeProps must accept three arguments',
								field.pos
							);

						if (!unifyComplexTypes(args[0].type, componentPropsType))
							if (!unifyComplexTypes(args[0].type, getPartialType(componentPropsType)))
								Context.fatalError(
									'mergeProps: first argument must match the wrapped '
									+ 'component\'s props type (or a Partial<> of it)',
									field.pos
								);

						if (!unifyComplexTypes(args[1].type, componentPropsType))
							if (!unifyComplexTypes(args[1].type, getPartialType(componentPropsType)))
								Context.fatalError(
									'mergeProps: second argument must match the wrapped '
									+ 'component\'s props type (or a Partial<> of it)',
									field.pos
								);

						if (!unifyComplexTypes(args[2].type, propsType))
							Context.fatalError(
								'mergeProps: third argument must match the container\'s props type.',
								field.pos
							);

						if (!unifyComplexTypes(ret, componentPropsType))
							Context.fatalError(
								'mergeProps must return the wrapped component\'s props type',
								field.pos
							);

					default:
						Context.fatalError('mergeProps must be a function', field.pos);
				}

				return field;
			}
		}

		return null;
	}

	static function getOptions(fields:Array<Field>):Field
	{
		for (field in fields)
		{
			if (field.name == 'options')
			{
				var connectOptionsType:ComplexType = macro :redux.react.ReactRedux.ConnectOptions;

				switch (field.kind)
				{
					case FVar(type), FProp(_, _, type, _):
						if (!unifyComplexTypes(type, connectOptionsType))
							if (!unifyComplexTypes(type, getPartialType(connectOptionsType)))
								Context.fatalError(
									'Connect options must be a ConnectOptions '
									+ ' or a Partial<ConnectOptions>',
									field.pos
								);


					default:
						Context.fatalError('Invalid connect options', field.pos);
				}

				return field;
			}
		}

		return null;
	}

	static function addConnected(
		jsxStatic:String,
		wrappedComponent:ComplexType,
		containerName:String,
		fields:Array<Field>
	) {
		fields.push({
			name: jsxStatic,
			access: [AStatic, APublic],
			kind: FProp('get', 'null', macro :react.React.CreateElementType),
			pos: Context.currentPos()
		});

		fields.push({
			name: 'get_$jsxStatic',
			doc: null,
			meta: [],
			access: [AStatic],
			kind: FFun({
				args: [],
				params: [],
				ret: macro :react.React.CreateElementType,
				expr: getConnectedExpr(jsxStatic, wrappedComponent, containerName)
			}),
			pos: Context.currentPos()
		});
	}

	static function getConnectedExpr(
		jsxStatic:String,
		wrappedComponent:ComplexType,
		containerName:String
	) {
		var componentDisplayNameExpr = macro {};
		var containerDisplayNameExpr = macro {};
		var containerDefaultPropsExpr = macro {};

		#if debug
		var componentName = extractClassName(wrappedComponent);
		componentName = componentName == null
			? 'UnknownWrappedComponent'
			: 'Wrapped_$componentName';

		componentDisplayNameExpr = macro untyped render.displayName = $v{componentName};
		containerDisplayNameExpr = macro untyped $i{jsxStatic}.displayName = $v{containerName};
		containerDefaultPropsExpr = macro untyped $i{jsxStatic}.defaultProps = $i{containerName}.defaultProps;
		#end

		return macro {
			if ($i{jsxStatic} == null) {
				${componentDisplayNameExpr};

				$i{jsxStatic} = redux.react.ReactRedux.connect(
					mapStateToProps,
					mapDispatchToProps,
					mergeProps,
					options
				)(render);

				${containerDisplayNameExpr};
				${containerDefaultPropsExpr};
			}

			return $i{jsxStatic};
		};
	}

	static function addRender(
		fields:Array<Field>,
		componentPropsType:ComplexType,
		wrappedComponent:ComplexType,
		inClass:ClassType
	) {
		var componentName = null;

		if (wrappedComponent != null) {
			componentName = switch (ComplexTypeTools.toType(wrappedComponent)) {
				case TInst(_.get() => cls, _):
					if (cls.meta.has(JsxStaticMacro.META_NAME)) {
						var staticField = JsxStaticMacro.extractMetaString(cls.meta, JsxStaticMacro.META_NAME);
						[cls.name, staticField];
					} else {
						[cls.name];
					}

				default:
					Context.fatalError(
						'Invalid wrapped component for React Container',
						inClass.pos
					);
					null;
			};
		}

		fields.push({
			name: 'render',
			doc: null,
			meta: [],
			access: [AStatic],
			kind: FFun({
				args: [{
					type: componentPropsType,
					name: 'props'
				}],
				params: [],
				ret: null,
				expr: renderExpr(inClass, componentName, inClass.pos)
			}),
			pos: Context.currentPos()
		});
	}

	static function renderExpr(container:ClassType, componentName:Null<Array<String>>, pos:Position)
	{
		var renderWithoutChildren:Expr = componentName == null
			? macro {
				#if debug
				if (react.React.Children.count(children) == 0)
					js.Browser.console.error('Container ' + $v{container.name} + ' cannot be used without children');
				#end
				return null;
			}
			: macro return react.React.createElement($p{componentName}, props);

		return macro {
			var children = untyped props.children;
			var props = react.ReactUtil.copyWithout(props, null, ['children']);

			if (children != null) {
				var newChildren = react.React.Children.map(
					children,
					function(child) {
						if (react.React.isValidElement(child)) {
							return react.React.cloneElement(child, props);
						}

						return child;
					}
				);

				return react.React.createElement(react.Fragment, {}, react.React.Children.toArray(newChildren));
			} else {
				$renderWithoutChildren;
			}
		};
	}

	static function addMapStateToProps(fields:Array<Field>)
	{
		fields.push({
			name: 'mapStateToProps',
			access: [AStatic],
			kind: FProp('default', 'null', macro :Dynamic, macro null),
			pos: Context.currentPos()
		});
	}

	static function addMapDispatchToProps(fields:Array<Field>)
	{
		fields.push({
			name: 'mapDispatchToProps',
			access: [AStatic],
			kind: FProp('default', 'null', macro :Dynamic, macro {}),
			pos: Context.currentPos()
		});
	}

	static function addMergeProps(fields:Array<Field>)
	{
		fields.push({
			name: 'mergeProps',
			access: [AStatic],
			kind: FProp('default', 'null', macro :Dynamic, macro null),
			pos: Context.currentPos()
		});
	}

	static function addOptions(fields:Array<Field>)
	{
		fields.push({
			name: 'options',
			access: [AStatic],
			kind: FProp('default', 'null', macro :Dynamic, macro null),
			pos: Context.currentPos()
		});
	}
}
