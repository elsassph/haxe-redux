package redux;

#if (haxe_ver >= 4)
import js.lib.Promise;
#else
import js.Promise;
#end
import redux.Redux;

/**
	Reduced Store API when provided in the React context
	http://redux.js.org/docs/api/Store.html
**/
typedef StoreMethods<TState> = {
	function getState():TState;
	function dispatch(action:Action):Promise<Dynamic>;
}
