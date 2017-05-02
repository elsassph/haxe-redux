package redux.react;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import react.ReactMacro;
import redux.macro.MacroUtil.*;

enum ConnectedFunction {
	WithDispatch(field:Field);
	WithDispatchAndOwnProps(field:Field);
}

@:access(react.ReactMacro)
class ReactConnectorMacro {
	static inline var DEFAULT_JSX_STATIC:String = 'Connected';

	static function buildContainer():Array<Field>
	{
		var inClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();

		var componentPropsType = macro :Dynamic;
		var ownPropsType = macro :Dynamic;
		var jsxStatic = getJsxStaticName(inClass);

		switch (inClass.superClass)
		{
			case {params: params, t: _.toString() => 'redux.react.ReactConnect'}:
				componentPropsType = TypeTools.toComplexType(params[0]);
				ownPropsType = TypeTools.toComplexType(params[1]);

			default:
				Context.fatalError('You cannot inherit from a react connector', inClass.pos);
		}

		checkNonStaticFields(fields);
		checkReservedFields(fields, jsxStatic);

		var wrappedComponent = getWrappedComponent(fields, componentPropsType);
		var connectedFunctions = getConnectedFunctions(fields, ownPropsType, componentPropsType, inClass);

		var mapStateToProps = getMapStateToProps(fields, ownPropsType, componentPropsType);
		var mapDispatchToProps = getMapDispatchToProps(fields, ownPropsType, componentPropsType);
		var mergeProps = getMergeProps(fields, ownPropsType, componentPropsType);
		var options = getOptions(fields);

		if (mapDispatchToProps == null)
			addMapDispatchToProps(
				fields,
				connectedFunctions,
				ownPropsType,
				componentPropsType
			);
		else if (connectedFunctions.length > 0)
			addMapDispatchToPropsWarnings(connectedFunctions);

		if (mapStateToProps == null) addMapStateToProps(fields);
		if (mergeProps == null) addMergeProps(fields);
		if (options == null) addOptions(fields);

		addConnected(jsxStatic, fields);
		addRender(fields, componentPropsType, wrappedComponent, inClass);

		return fields;
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
		if (inClass.meta.has(':jsxStatic')) 
			return extractMetaString(inClass.meta, ':jsxStatic');

		inClass.meta.add(':jsxStatic', [macro $v{DEFAULT_JSX_STATIC}], inClass.pos);
		return DEFAULT_JSX_STATIC;
	}

	static function getWrappedComponent(fields:Array<Field>, componentPropsType:ComplexType):ComplexType
	{
		var wrappedComponent = Lambda.find(fields, function(field) {
			return field.name == 'wrappedComponent';
		});
		
		if (wrappedComponent == null) return null;

		return switch (wrappedComponent.kind) {
			case FVar(t, _): t;
			default: null;
		};
	}

	static function getConnectedFunctions(
		fields:Array<Field>,
		propsType:ComplexType,
		componentPropsType:ComplexType,
		inClass:ClassType
	):Array<ConnectedFunction> {
		return fields
			.filter(function(field) {
				return Lambda.find(field.meta, function(meta) {
					return meta.name == ':connect';
				}) != null;
			})
			.map(function(field) {
				switch (field.kind)
				{
					case FFun({args: args, expr: _, params: _, ret: ret}):
						if (args.length == 0)
							Context.fatalError(
								'Connected functions must accept a Dispatch argument',
								field.pos
							);

						if (!isDispatch(args[0].type))
							Context.fatalError(
								'First argument of connected functions must be Dispatch',
								field.pos
							);

						var fields = getAnonymousFields(componentPropsType);
						if (fields == null)
							Context.fatalError(
								'Wrapped components props must be anonymous objects', 
								inClass.pos
							);

						for (ref in fields)
							if (ref.name == field.name)
								return validateConnectedFunction(
									ref, 
									field, 
									propsType, 
									args.slice(1), 
									ret
								);

					default:
						Context.fatalError('Only functions can be connected with @:connect', field.pos);
				}

				return null;
			});
	}

	static function validateConnectedFunction(
		ref:ClassField,
		field:Field,
		propsType:ComplexType,
		fieldArgs:Array<FunctionArg>,
		fieldRet:ComplexType
	):ConnectedFunction {
		var refType = TypeTools.follow(ref.type);
		var needsOwnProps = false;

		switch (refType)
		{
			case TFun(args, ret):
				if (fieldRet == null)
					Context.warning(
						'You should specify the return type to allow type checking against props\n' +
						'(should be ${TypeTools.toString(ret)} to match props)',
						field.pos
					);
				else if (!TypeTools.unify(ret, ComplexTypeTools.toType(fieldRet)))
				{
					Context.fatalError('Return type does not match props', field.pos);
				}

				// trace(printFunctionSignature(
				// 	fieldArgs.map(function(arg) return arg.type == null ? null : ComplexTypeTools.toType(arg.type)), 
				// 	ComplexTypeTools.toType(fieldRet)
				// ));

				if (args.length < fieldArgs.length)
				{
					if (unifyComplexTypes(fieldArgs[0].type, propsType))
					{
						fieldArgs = fieldArgs.slice(1);
						needsOwnProps = true;
					}
				}

				if (args.length != fieldArgs.length)
				{
					var functionSign = printFunctionSignature(args.map(function(arg) return arg.t), ret);
					var wantedSign = 
						'dispatch: Dispatch -> ' + functionSign
						+ '\nor\n dispatch: Dispatch -> ownProps: ' 
						+ ComplexTypeTools.toString(propsType)
						+ ' -> ' + functionSign;

					Context.fatalError(
						'Field `${ref.name}` does not match props type. Wanted:\n $wantedSign',
						field.pos
					);
				}

				for (i in 0...args.length)
				{
					var wantedType = args[i].t;
					var wantedTypeStr = TypeTools.toString(wantedType);

					var fieldArg = fieldArgs[i];
					var fieldName = fieldArg.name;
					var fieldType = fieldArg.type;

					if (fieldArg.type == null)
					{
						Context.warning(
							'You should specify the type for argument `$fieldName`\n'
							+ '(should be $wantedTypeStr to match props)',
							field.pos
						);
					}
					else if (!TypeTools.unify(wantedType, ComplexTypeTools.toType(fieldType)))
					{
						var fieldTypeStr = ComplexTypeTools.toString(fieldType);

						Context.fatalError(
							'Argument `$fieldName` does not match props:\n'
							+ '$fieldTypeStr should be $wantedTypeStr',
							field.pos
						);
					}
				}

			default:
				Context.fatalError(
					'Only functions can be connected with @:connect',
					field.pos
				);
		}

		return needsOwnProps ? WithDispatchAndOwnProps(field) : WithDispatch(field);
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
						if (args.length == 0 || args.length > 2)
							Context.fatalError(
								'mapStateToProps must accept one or two arguments',
								field.pos
							);

						if (args.length == 2 && !unifyComplexTypes(args[1].type, propsType))
							Context.fatalError(
								'mapStateToProps: second argument must match '
								+ 'the container\'s props type.',
								field.pos
							);

						if (!unifyComplexTypes(ret, componentPropsType))
							if (!unifyComplexTypes(ret, getPartialType(componentPropsType)))
								Context.fatalError(
									'mapStateToProps must return the wrapped component\'s '
									+ 'props type (or a Partial<> of it)',
									field.pos
								);

					default:
						Context.fatalError('mapStateToProps must be a function', field.pos);
				}

				return field;
			}
		}

		return null;
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
						if (args.length == 0 || args.length > 2)
							Context.fatalError(
								'mapDispatchToProps must accept one or two arguments',
								field.pos
							);

						if (!isDispatch(args[0].type))
							Context.fatalError(
								'mapDispatchToProps: first argument must of type Dispatch',
								field.pos
							);

						if (args.length == 2 && !unifyComplexTypes(args[1].type, propsType))
							Context.fatalError(
								'mapDispatchToProps: second argument must match '
								+ 'the container\'s props type.',
								field.pos
							);

						if (!unifyComplexTypes(ret, componentPropsType))
							if (!unifyComplexTypes(ret, getPartialType(componentPropsType)))
								Context.fatalError(
									'mapDispatchToProps must return the wrapped component\'s '
									+ 'props type (or a Partial<> of it)',
									field.pos
								);

					default:
						Context.fatalError(
							'Current implementation only handles mapDispatchToProps as a function',
							field.pos
						);
				}

				return field;
			}
		}

		return null;
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

	static function addMapDispatchToPropsWarnings(connectedFunctions:Array<ConnectedFunction>)
	{
		for (field in connectedFunctions)
			switch (field) {
				case WithDispatch(f), WithDispatchAndOwnProps(f):
					Context.warning(
						'@:connect functions will not be connected by the macro '
						+ 'when you define mapDispatchToProps',
						f.pos
					);
			}
	}

	static function addMapDispatchToProps(
		fields:Array<Field>,
		connectedFunctions:Array<ConnectedFunction>,
		propsType:ComplexType,
		componentPropsType:ComplexType
	) {
		fields.push({
			name: 'mapDispatchToProps',
			doc: null,
			meta: [],
			access: [AStatic],
			kind: FFun({
				args: [
					{type: macro :redux.Redux.Dispatch, name: 'dispatch'},
					{type: propsType, name: 'ownProps', opt: true}
				],
				params: [],
				ret: getPartialType(componentPropsType),
				expr: mapDispatchToPropsExpr(connectedFunctions)
			}),
			pos: Context.currentPos()
		});
	}

	static function mapDispatchToPropsExpr(connectedFunctions:Array<ConnectedFunction>)
	{
		var propsFields = [
			for (connectedFunction in connectedFunctions)
				switch (connectedFunction) {
					case WithDispatch(field):
						{
							field: field.name,
							expr: macro $i{field.name}.bind(dispatch)
						};

					case WithDispatchAndOwnProps(field):
						{
							field: field.name,
							expr: macro $i{field.name}.bind(dispatch, ownProps)
						};
				}
		];

		return {
			expr: EBlock([{
				expr: EReturn({
					expr: EObjectDecl(propsFields),
					pos: Context.currentPos()
				}),
				pos: Context.currentPos()
			}]),
			pos: Context.currentPos()
		};
	}

	static function addConnected(jsxStatic:String, fields:Array<Field>)
	{
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
				expr: getConnectedExpr(jsxStatic)
			}),
			pos: Context.currentPos()
		});
	}

	static function getConnectedExpr(jsxStatic:String)
	{
		return macro {
			if ($i{jsxStatic} == null)
				$i{jsxStatic} = redux.react.ReactRedux.connect(
					mapStateToProps,
					mapDispatchToProps,
					mergeProps,
					options
				)(render);

			return $i{jsxStatic};
		};
	}

	static function addRender(
		fields:Array<Field>,
		componentPropsType:ComplexType,
		wrappedComponent:ComplexType,
		inClass:ClassType
	) {
		var componentName = switch (ComplexTypeTools.toType(wrappedComponent)) {
			case TInst(compClass, _):
				compClass.get().name;
			
			case null: 
				null;

			default:
				Context.fatalError(
					'Invalid wrapped component for React Container',
					inClass.pos
				);
		};

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
				expr: renderExpr(componentName, inClass.pos)
			}),
			pos: Context.currentPos()
		});
	}

	static function renderExpr(componentName:String, pos:Position)
	{
		var jsx = macro null;

		if (componentName != null) {
			var jsxStr = '<' + componentName + ' {...props} />';
			jsx = ReactMacro.parseJsx(jsxStr, pos);
		}

		return macro {
			var children = untyped props.children;

			if (children != null && react.React.isValidElement(children))
			{
				return react.React.Children.map(
					children, 
					function(child) return react.React.cloneElement(child, props)
				);
			} else {
				return ${jsx};
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
