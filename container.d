module container;

import fields;

abstract class Container
{
	protected:
	public:
		string[] errors, msgs;
		Field[string] fields;
}
