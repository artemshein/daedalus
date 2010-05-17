module container;

import fields;

abstract class Container
{
	protected:
	public:
		string[] errors, msgs;
		Field[string] fieldsByName;
		
		Container addField (in string name, Field f)
		{
			fieldsByName[name] = f;
			return this;
		}
		Field[string] fields ()
		{
			return fieldsByName;
		}
}
