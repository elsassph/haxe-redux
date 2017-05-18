# Redux externs and support classes for Haxe

A smart set of externs, abstracts and macros for a smart Haxe and redux integration.

By default the externs use `@:jsRequire` (eg. JS `require`).

To use a global Redux JS (eg. https://cdnjs.com/libraries/redux) add: `-D redux_global`. 


## Basic API

The base externs work exactly as described in the redux documentation.


## Advanced API

Using the `StoreBuilder` helper it is possible to leverage Haxe Enums to dispatch 
and match actions. 

### Store setup

```haxe
	import redux.StoreBuilder.*;

	// store model, implementing reducer and middleware logic
	var todoList = new TodoList();
	
	// create root reducer normally, excepted you must use 
	// 'StoreBuilder.mapReducer' to wrap the Enum-based reducer
	var rootReducer = Redux.combineReducers({
		todoList: mapReducer(TodoAction, todoList)
	});
	
	// create middleware normally, excepted you must use 
	// 'StoreBuilder.mapMiddleware' to wrap the Enum-based middleware
	var middleware = Redux.applyMiddleware(
		mapMiddleware(TodoAction, todoList)
	);
	
	// user 'StoreBuilder.createStore' helper to automatically wire
	// the Redux devtools browser extension:
	// https://github.com/zalmoxisus/redux-devtools-extension
	return createStore(rootReducer, null, middleware);
```

### Dispatch

The regular Redux `store.dispatch` is declared to accept the type `Action` which is 
in fact a Haxe `abstract` capable of auto-converting Haxe Enums into a regular 
`{ type, value }` Redux object.

For code to be seamless, simple wrapper functions provides the right Haxe Enum value
to the reducer/middleware.

```haxe
// Use regular 'store.dispatch' but passing Haxe Enums!
store.dispatch(TodoAction.Load)
	.then(function(_) {
		store.dispatch(TodoAction.Add('Item 5'));
		store.dispatch(TodoAction.Toggle('4'));
	});
```

```haxe
// TodoList.hx

// Match the Haxe Enum directly in your reducer!
public function reduce(state:TodoListState, action:TodoAction):TodoListState 
{
	return switch(action)
	{
		case Add(text):
			var newEntry = { id: '${++ID}', text: text, done: false };
			copy(state, {
				entries: state.entries.concat([newEntry])
			});
		case ...
```

```haxe
// Match the Haxe Enum directly in your middleware!
public function middleware(store:StoreMethods<ApplicationState>, action:TodoAction, next:Void -> Dynamic)
{
	return switch(action)
	{
		case Load: loadEntries(store);
		default: next();
	}
}
```


## React Connect

### High Order Component (HOC) approach (TODO)

**Note: externs for this approach are NOT included.**

Normally for React, you're expected to use react-redux's `connect` function:
http://redux.js.org/docs/basics/UsageWithReact.html

HOC will create a wrapped component that maps the redux state into component **props**.

Using HOCs is a bit awkward in Haxe's class-oriented approach, one way to do it is to store
the connected class reference in a static field:

```haxe
class MyComponent extends ReactComponent 
{
	static public var Connected = ReactRedux.connect(mapStateToProps)(MyComponent);
	
	static function mapStateToProps(state:State)
	{
		...
	} 
	...
}
```

```haxe
	override function render() 
	{
		return jsx('<MyComponent.Connected />');
	}
```


### Macro approach

The approach proposed here uses macros to directly modify your class to insert the needed 
lifecycle operations:
- interface `IConnectedComponent` triggers the `ConnectMacro`,
- `this.context.store` is wired automatically,
- a `this.dispatch` function is created, forwarding to the connected store,
- if a `mapState` (static or not) function is declared, it will be used: 
	- in the constructor to set the initial state (instead of props),
	- when the state changes, to call `setState` with a new mapped state.

Using this system you don't normally even need to wrap the views using a separate component, 
but you should be able to manually reproduce this setup if desired. 

Unlike the HOC, this approach applies the mapped redux state as **state** values (only
when it changes).

**Note: it is strongly discouraged to use inheritance with classes implementing 
`IConnectedComponent`. Use React components composition instead!**

```haxe
// Implement IConnectComponent and (optionally) simply declare your state mapping function.
// No need to wrap your React view with Redux's connect function!
class TodoListView extends ReactComponentOfState<TodoListState> implements IConnectedComponent
{
	static function mapState(state:ApplicationState)
	{
		var todoList = state.todoList;
		var entries = todoList.entries;
		var message = 
			todoList.loading 
			? 'Loading...'
			: '${getRemaining(entries)} remaining of ${entries.length} items to complete';
		
		return {
			message: message,
			list: entries
		}
	}
	...
	override public function render() 
	{
		return jsx('
			<div>
				<TodoStatsView message=${state.message} addNew=$addNew/>
				<hr/>
				<ul>
					${renderList()}
				</ul>
			</div>
		');
	}
	
	function addNew() 
	{
		dispatch(TodoAction.Add('A new task'));
	}
	...
```

### Common issues

#### Uncaught Error: Actions must be plain objects. Use custom middleware for async actions.

Happens when you dispatch an Enum but the `dispatch` function is dynamically typed.

The reason is the Enum needs to be transformed using an abstract type `redux.Action`.
This abstract type will wrap the Enum value in a regular Redux action. 

**Solution:**

Make sure `dispatch` is a function declared as `redux.Action->Dynamic` 
or simply `redux.Dispatch`.

For example if you pass a reference to `dispatch` down to sub-components, you'll need
to type the props or use a temp variable:

```haxe
// when reference is untyped
var dispatch:Dispatch = props.dispatch;
dispatch(AnEnum.Action);

// or use typed props
typedef MyCompProps = {
	dispatch:Dispatch
}

class MyComp extends ReactComponentOfProps<MyCompProps> {
	...
	function doSomething() {
		props.dispatch(AnEnum.Action);
	}
}
```

## Changes

### 0.5.0 

- Compatibility with haxe-react 1.2.0: changed to use `react.ReactPropTypes` instead of `react.React.PropTypes`
