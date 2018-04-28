package redux.thunk;

import redux.Redux.Dispatch;

enum Thunk<TState, TParams> {
	Action(cb:Dispatch->(Void->TState)->Dynamic);
	WithParams(cb:Dispatch->(Void->TState)->Null<TParams>->Dynamic);
}

