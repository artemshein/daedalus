/**
 * Container
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module container;

import fields;

string fieldGetterAndSetter (FieldClass, string name) () @safe pure
{
	return FieldClass.stringof ~ " " ~ name ~ " () { return cast("
		~ FieldClass.stringof ~ ") rwFields[\"" ~ name ~ "\"]; } auto "
		~ name ~ " (" ~ FieldClass.stringof ~ " f) { rwFields[\"" ~ name
		~ "\"] = f; return this; }";
}

abstract class Container
{
protected:

	Field[string] fieldsByName;
	
public:
@safe:

	string[] errors, msgs;
	
	this ()
	{}

@property:

	ref Field[string] rwFields ()
	{
		return fieldsByName;
	}
	
	const
	Field[string] fields ()
	{
		return fieldsByName;
	}
}
