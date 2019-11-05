package redux.react;

import haxe.Constraints.Function;
import redux.Redux;
import react.Partial;

#if react_next
import react.ReactType;
#else
import react.React.CreateElementType;
#end

#if reactredux_global
@:native('ReactRedux')
#else
@:jsRequire('react-redux')
#end
extern class ReactRedux
{
	// https://github.com/reactjs/react-redux/blob/master/docs/api.md#connectmapstatetoprops-mapdispatchtoprops-mergeprops-options
	public static function connect<TStateProps, TDispatchProps, TOwnProps, TProps>(
		?mapStateToProps: Function,
		?mapDispatchToProps: Dynamic,
		?mergeProps: TStateProps -> TDispatchProps -> TOwnProps -> TProps,
		?options: Partial<ConnectOptions>
	#if react_next
	): ReactTypeOf<TProps> -> ReactTypeOf<TOwnProps>;
	#else
	): CreateElementType -> CreateElementType;
	#end

	// https://github.com/reactjs/react-redux/blob/master/docs/api.md#connectadvancedselectorfactory-connectoptions
	public static function connectAdvanced<TFactoryOptions, TState, TOwnProps, TProps, TOptions:ConnectAdvancedOptions>(
		selectorFactory: Dispatch -> TFactoryOptions -> (TState -> TOwnProps -> TProps),
		?connectOptions: TOptions
	#if react_next
	): ReactTypeOf<TProps> -> ReactTypeOf<TOwnProps>;
	#else
	): CreateElementType -> CreateElementType;
	#end
}

typedef ConnectAdvancedOptions = {
	/**
		Computes the connector component's displayName property relative to
		that of the wrapped component. Usually overridden by wrapper functions.
		Default value: name => 'ConnectAdvanced(' + name + ')'
	*/
	var getDisplayName: String -> String;

	/**
		Shown in error messages. Usually overridden by wrapper functions.
		Default value: 'connectAdvanced'
	*/
	var methodName: String;

	/**
		If defined, a property named this value will be added to the props
		passed to the wrapped component. Its value will be the number of times
		the component has been rendered, which can be useful for tracking down
		unnecessary re-renders.
		Default value: undefined
	*/
	var renderCountProp: String;

	/**
		Controls whether the connector component subscribes to redux store
		state changes. If set to false, it will only re-render on
		componentWillReceiveProps.
		Default value: true
	*/
	var shouldHandleStateChanges: Bool;

	/**
		The key of props/context to get the store. You probably only need this
		if you are in the inadvisable position of having multiple stores.
		Default value: 'store'
	*/
	var storeKey: String;

	/**
		If true, stores a ref to the wrapped component instance and makes it
		available via getWrappedInstance() method.
		Default value: false
	*/
	var withRef: Bool;
}

typedef ConnectOptions = {
	> ConnectAdvancedOptions,

	/**
		If true, connect() will avoid re-renders and calls to mapStateToProps,
		mapDispatchToProps, and mergeProps if the relevant state/props objects
		remain equal based on their respective equality checks. Assumes that
		the wrapped component is a “pure” component and does not rely on any
		input or state other than its props and the selected Redux store’s
		state.
		Default value: true
	**/
	var pure: Bool;

	/**
		When pure, compares incoming store state to its previous value.
		Default value: strictEqual (===)
	**/
	var areStatesEqual: Dynamic -> Dynamic -> Bool;

	/**
		When pure, compares incoming props to its previous value.
		Default value: shallowEqual
	**/
	var areOwnPropsEqual: Dynamic -> Dynamic -> Bool;

	/**
		When pure, compares the result of mapStateToProps to its previous value.
		Default value: shallowEqual
	**/
	var areStatePropsEqual: Dynamic -> Dynamic -> Bool;

	/**
		When pure, compares the result of mergeProps to its previous value.
		Default value: shallowEqual
	**/
	var areMergedPropsEqual: Dynamic -> Dynamic -> Bool;
}
