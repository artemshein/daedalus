module fields;

import std.conv;
import qc, container, validators, widgets;

abstract class Field
{
	protected:
		uint maxLen_;
	public:
		Container container;
		string id, label, name, hint, onClick, onChange;
		bool required, unique, pk, index;
		Validator[string] validators;
		string[] errors, classes;
		Widget widget, ajaxWidget;
		
		this ()
		{}
		Field addValidator (string cl, Validator v)
		{
			validators[cl] = v;
			return this;
		}
		uint maxLen (uint v)
		{
			maxLen_ = v;
			return v;
		}
		uint maxLen ()
		{
			return maxLen_;
		}
		
		abstract:
			bool valid ();
			string defaultValAsString ();
			string valAsString ();
}

class TextField: Field
{
	protected:
		string value_;
		
	public:
		string defaultVal;
		
		this ()
		{
			super();
		}
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
		string valAsString ()
		{
			return value;
		}
		string defaultValAsString ()
		{
			return defaultVal;
		}
		uint minLen ()
		{
			auto v = "length" in validators;
			if (v is null)
				return 0;
			assert(typeid(v) == typeid(LengthValidator));
			return (cast(LengthValidator)*v).min;
		}
		uint minLen (uint len)
		{
			auto v = LengthValidator.key in validators;
			if (v is null)
				addValidator(LengthValidator.key, new LengthValidator(len, 0));
			else
				(cast(LengthValidator)*v).min = len;
			return len;	
		}
		uint maxLen ()
		{
			auto v = "length" in validators;
			if (v is null)
				return 0;
			assert(typeid(v) == typeid(LengthValidator));
			return (cast(LengthValidator)*v).max;
		}
		uint maxLen (uint len)
		{
			auto v = LengthValidator.key in validators;
			if (v is null)
				addValidator(LengthValidator.key, new LengthValidator(len));
			else
				(cast(LengthValidator)*v).max = len;
			return len;
		}
		string regexp ()
		{
			auto v = RegexpValidator.key in validators;
			if (v is null)
				return null;
			else
				return (cast(RegexpValidator)*v).regexp;
		}
		string regexp (string s)
		{
			auto v = RegexpValidator.key in validators;
			if (v is null)
				addValidator(RegexpValidator.key, new RegexpValidator(s));
			else
				return (cast(RegexpValidator)*v).regexp = s;
			return s;
		}
		
	unittest
	{
		scope t = new Test!TextField;
		auto f = new TextField;
		f.value = 10;
		assert("10" == f.value);
		f.addValidator("length", new LengthValidator(3, 5));
		assert(!f.valid);
		f.value = 123;
		assert(f.valid);
	}
}

class LoginField: TextField
{
	public:
		this ()
		{
			super();
			minLen = 1;
			maxLen = 32;
			required = true;
			unique = true;
			regexp = "^[a-zA-Z0-9_%.%-]+$";
		}
}

class PasswordField: TextField
{
	protected:
	public:
		this (bool required)
		{
			this.required = required;
		}
}

class IntField: Field
{
	protected:
		int value_;
		
	public:
		int defaultVal;
	
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
		string valAsString ()
		{
			return to!string(value);
		}
		string defaultValAsString ()
		{
			return to!string(defaultVal);
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
		bool defaultVal;
		
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
		string valAsString ()
		{
			return value? "true" : "false";
		}
		string defaultValAsString ()
		{
			return defaultVal? "true" : "false";
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
		this (string defaultVal)
		{
			this.defaultVal = defaultVal;
		}
}
