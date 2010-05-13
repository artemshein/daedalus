module fields;

import std.conv;
import qc, container, validators, widgets;

abstract class Field
{
	protected:
	public:
		Container container;
		string id, label, name, hint;
		bool required, unique, pk, index;
		Validator[] validators;
		string[] errors, classes;
		Widget widget, ajaxWidget;
		
		Field addValidator (Validator v)
		{
			validators ~= v;
			return this;
		}
		abstract:
			bool valid ();
}

class TextField: Field
{
	protected:
		string value_;
		
	public:
		string value (string v)
		{
			value_ = v;
			return v;
		}
		uint value (uint v)
		{
			value_ = to!string(v);
			return v;
		}
		int value (int v)
		{
			value_ = to!string(v);
			return v;
		}
		string value ()
		{
			return value_;
		}
		bool valid ()
		{
			bool res = true;
			foreach (v; validators)
				if (!v.valid(value))
				{
					// TODO: add error
					res = false;
				}
			return res;
		}
	
		
	unittest
	{
		scope t = new Test!TextField;
		auto f = new TextField;
		f.value = 10;
		assert("10" == f.value);
		f.addValidator(new LengthValidator(3, 5));
		assert(!f.valid);
		f.value = 123;
		assert(f.valid);
	}
}

class PasswordField: TextField
{
	protected:
	public:
}

class IntField: Field
{
	protected:
		int value_;
		
	public:
		string value (string v)
		{
			value_ = to!int(v);
			return v;
		}
		uint value (uint v)
		{
			value_ = cast(int)v;
			return v;
		}
		int value (int v)
		{
			value_ = v;
			return v;
		}
		int value ()
		{
			return value_;
		}
		bool valid ()
		{
			bool res = true;
			foreach (v; validators)
				if (!v.valid(value))
				{
					// TODO: add error
					res = false;
				}
			return res;
		}
	
		
	unittest
	{
		scope t = new Test!IntField;
		auto f = new IntField;
		f.value = "10";
		assert(10 == f.value);
	}
}

class BoolField: Field
{
	protected:
		bool value_;
		
	public:
		string value (string v)
		{
			value_ = v !is null && v.length;
			return v;
		}
		uint value (uint v)
		{
			value_ = cast(bool)v;
			return v;
		}
		int value (int v)
		{
			value_ = cast(bool)v;
			return v;
		}
		bool value ()
		{
			return value_;
		}
		bool valid ()
		{
			bool res = true;
			foreach (v; validators)
				if (!v.valid(value))
				{
					// TODO: add error
					res = false;
				}
			return res;
		}
	
		
	unittest
	{
		scope t = new Test!BoolField;
		auto f = new BoolField;
		f.value = "1";
		assert(f.value);
	}
}

class ButtonField: TextField
{
	protected:
	public:
}

class SubmitField: ButtonField
{
	protected:
	public:
}
