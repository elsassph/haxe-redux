package redux.react;

typedef ReactConnector<TComponentProps> = ReactConnect<TComponentProps, Dynamic>;
typedef ReactConnectorOfProps<TComponentProps, OwnProps> = ReactConnect<TComponentProps, OwnProps>;

@:autoBuild(redux.react.ReactConnectorMacro.buildContainer())
class ReactConnect<TComponentProps, OwnProps> {}
