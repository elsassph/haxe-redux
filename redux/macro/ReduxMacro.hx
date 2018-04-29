package redux.macro;

class ReduxMacro
{
	static public function initMacro()
	{
		#if react
		redux.react.ReactConnectorMacro.addBuilder();
		#end
	}
}

