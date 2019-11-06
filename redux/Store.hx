package redux;

#if (haxe_ver >= 4)
import js.lib.Promise;
#else
import js.Promise;
#end
import redux.Redux;

/**
	http://redux.js.org/docs/basics/Store.html
**/
interface Store<TState>
{
	function getState():TState;
	function dispatch(action:Action):Promise<Dynamic>;
	function subscribe(listener:StoreListener):Unsubscribe;
	function replaceReducer<TState>(rootReducer:Reducer<TState>):Void;
}
