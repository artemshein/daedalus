module container;

import fields;

string fieldGetterAndSetter (FieldClass, string name) ()
{
	return FieldClass.stringof ~ " " ~ name ~ " () { return cast("
		~ FieldClass.stringof ~ ") rwFields[\"" ~ name ~ "\"]; } auto "
		~ name ~ " (" ~ FieldClass.stringof ~ " f) { rwFields[\"" ~ name ~ "\"] = f; return this; }";
}

abstract class Container
{
	protected:
		Field[string] fieldsByName;
		
	public:
		string[] errors, msgs;
		
		this () @safe
		{}
		ref Field[string] rwFields () @safe @property
		{
			return fieldsByName;
		}
		const(Field[string]) fields () @safe @property pure const
		{
			return fieldsByName;
		}
}
