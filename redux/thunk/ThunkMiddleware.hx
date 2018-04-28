package redux.thunk;

import redux.IMiddleware;
import redux.StoreMethods;

class ThunkMiddleware<TState, TParams> implements IMiddleware<Thunk<TState, TParams>, TState> {
	public var store:StoreMethods<TState>;
	var params:Null<TParams>;

	public function new(?params:TParams) {
		this.params = params;
	}

	public function middleware(action:Thunk<TState, TParams>, next:Void->Dynamic):Dynamic {
		return switch (action) {
			case Action(cb):
				return cb(store.dispatch, store.getState);

			case WithParams(cb):
				return cb(store.dispatch, store.getState, this.params);
		}
	}
}
