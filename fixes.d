module fixes;

import core.exception;
import std.variant, std.stdarg;

// Bug in dmd or std.variant

class VariantProxy
{
	Variant v;
	this (Variant v)
	{
		this.v = v;
	}
	
	unittest
	{
		try
		{
			Variant[string] v;
			v["abc"] = 10; // should throw due to bug in dmd or phobos
		}
		catch (RangeError)
		{
			return;
		}
		assert(false, "bug fixed?");
	}
}

// this function needed while D can't pass variadic arguments
Variant[] packArgs (in TypeInfo[] _arguments, void* _argptr) @trusted
{
	Variant[] res;
	res.length = _arguments.length; 
	foreach (i, arg; _arguments)
	{
		Variant v;
		if (typeid(uint) == arg)
			v = va_arg!uint(_argptr);
		else if (typeid(int) == arg)
			v = va_arg!int(_argptr);
		else if (typeid(string) == arg)
			v = va_arg!string(_argptr);
		else
			assert(false, "not implemented");
		res[i] = v;
	}
	return res;
}
