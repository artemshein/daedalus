module validators;

import std.conv;
import qc;

abstract class Validator
{
	protected:
	public:
		string[] errors;
		string errorMsg;
		
		abstract:
			bool valid (string);
			bool valid (int);
			bool valid (uint);
			bool valid (bool);
}

class FilledValidator: Validator
{
	public:
		bool valid (string s)
		{
			return s !is null && s.length;
		}
		bool valid (int v)
		{
			return true;
		}
		bool valid (uint v)
		{
			return true;
		}
		bool valid (bool b)
		{
			return true;
		}
		
	unittest
	{
		scope t = new Test!FilledValidator;
		auto v = new FilledValidator;
		assert(!v.valid(""));
		assert(!v.valid(null));
		assert(v.valid("a"));
		assert(v.valid(3));
	}
}

class LengthValidator: Validator
{
	public:
		uint min = uint.min, max = uint.max;
		this (uint min, uint max)
		{
			this.min = min;
			this.max = max;
		}
		this (uint max)
		{
			this.max = max;
		}
		bool valid (string s)
		{
			return s.length >= min && s.length <= max;
		}
		bool valid (int v)
		{
			return valid(to!string(v));
		}
		bool valid (uint v)
		{
			return valid(to!string(v));
		}
		bool valid (bool v)
		{
			assert(false, "not implemented");
		}
	
	unittest
	{
		scope t = new Test!LengthValidator;
		auto v = new LengthValidator(3, 5);
		assert(!v.valid(12));
		assert(v.valid(123));
		assert(v.valid(1234));
		assert(v.valid(12345));
		assert(!v.valid(123456));
		assert(!v.valid(""));
		assert(!v.valid("ab"));
		assert(v.valid("abc"));
		assert(v.valid("abcde"));
		assert(!v.valid("abcdef"));
	}
}

class IntValidator: Validator
{
	public:
		bool valid (string s)
		{
			try
			{
				auto v = to!int(s);
			}
			catch
			{
				return false;
			}
			return true;
		}
		bool valid (int v)
		{
			return true;
		}
		bool valid (uint v)
		{
			return true;
		}
		bool valid (bool b)
		{
			return false;
		}
		
	unittest
	{
		scope t = new Test!IntValidator;
		auto v = new IntValidator;
		assert(!v.valid(""));
		assert(!v.valid("abcd"));
		assert(v.valid("12345"));
		assert(v.valid("-245"));
	}
}
