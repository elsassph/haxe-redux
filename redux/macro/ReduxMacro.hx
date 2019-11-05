package redux.macro;

class ReduxMacro
{
	static public function initMacro()
	{
		#if (react || react_next)
		redux.react.ReactConnectorMacro.addBuilder();
		#end
	}
}

