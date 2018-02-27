package redux.react;

typedef TVoid = {};

/**
  A react-redux connector designed for a component TComponent, providing TProps
  from redux store.
*/
typedef ReactConnector<TComponent, TProps> = ReactConnect<TComponent, TProps, TVoid>;

/**
  A react-redux connector designed for a component TComponent, providing TProps
  from redux store and the connector's props (TOwnProps)
*/
typedef ReactConnectorOfProps<TComponent, TComponentProps, TOwnProps> = ReactConnect<TComponent, TComponentProps, TOwnProps>;

/**
  A react-redux connector for use with any component compatible with TProps.
  Will return an empty react node at runtime if used without children, with an
  error message if compiled with -debug.
*/
typedef ReactGenericConnector<TProps> = ReactConnect<TVoid, TProps, TVoid>;

/**
  A react-redux connector for use with any component compatible with TProps.
  This connector also accepts props of type TOwnProps.
  Will return an empty react node at runtime if used without children, with an
  error message if compiled with -debug.
*/
typedef ReactGenericConnectorOfProps<TProps, TOwnProps> = ReactConnect<TVoid, TProps, TOwnProps>;

@:autoBuild(redux.react.ReactConnectorMacro.buildContainer())
class ReactConnect<TComponent, TComponentProps, TOwnProps> {}
