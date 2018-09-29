package redux.thunk;

import redux.Redux.Dispatch;

enum Thunk<TState, TParams> {
	Action<TReturn>(cb:Dispatch->(Void->TState)->TReturn);
	WithParams<TReturn>(cb:Dispatch->(Void->TState)->Null<TParams>->TReturn);
}

