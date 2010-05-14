module container;

import fields;

abstract class Container
{
	protected:
	public:
		string[] errors, msgs;
		Field[string] fieldsByName;
		
		Container addField (string name, Field f)
		{
			fieldsByName[name] = f;
			return this;
		}
}
