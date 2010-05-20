module fields;

import std.conv;
import qc, type, container, validators, widgets;

abstract class Field
{
	protected:
		uint maxLen_;

	public:
		Container container;
		string id, label, name, hint, onClick, onChange, onLoad;
		bool required, unique, pk, index;
		Validator[string] validators;
		string[] errors, classes;
		FieldWidget widget, ajaxWidget;
		
		this () @safe
		{}
		Field addValidator (string cl, Validator v) @safe
		{
			validators[cl] = v;
			return this;
		}
		uint maxLen (uint v) @safe
		{
			maxLen_ = v;
			return v;
		}
		uint maxLen () const
		{
			return maxLen_;
		}
		string asHtml () @safe const
		in
		{
			assert(widget !is null);
		}
		body
		{
			return widget(this);
		}
		string js () @safe const
		in
		{
			assert(widget !is null);
		}
		body
		{
			return widget.js(this);
		}
		
		abstract:
			bool valid () @safe;
			string defaultValAsString () @safe const;
			string valAsString () @safe const;
}

class TextField: Field
{
	protected:
		string value_;
		
	public:
		string defaultVal;
		
		this () @safe
		{
			super();
		}
		string value (string v) @safe
		{
			value_ = v;
			return v;
		}
		uint value (uint v) @trusted
		{
			value_ = to!string(v);
			return v;
		}
		int value (int v) @trusted
		{
			value_ = to!string(v);
			return v;
		}
		string value () @safe const
		{
			return value_;
		}
		bool valid () @trusted
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
		string valAsString () @safe const
		{
			return value;
		}
		string defaultValAsString () @safe const
		{
			return defaultVal;
		}
		uint minLen () const
		{
			auto v = "length" in validators;
			if (v is null)
				return 0;
			assert(isA!LengthValidator(*v));
			return (cast(LengthValidator)*v).min;
		}
		uint minLen (uint len) @safe
		{
			auto v = LengthValidator.key in validators;
			if (v is null)
				addValidator(LengthValidator.key, new LengthValidator(len, 0));
			else
				(cast(LengthValidator)*v).min = len;
			return len;	
		}
		uint maxLen () const
		{
			auto v = "length" in validators;
			if (v is null)
				return 0;
			assert(isA!LengthValidator(*v));
			return (cast(LengthValidator)*v).max;
		}
		uint maxLen (uint len) @safe
		{
			auto v = LengthValidator.key in validators;
			if (v is null)
				addValidator(LengthValidator.key, new LengthValidator(len));
			else
				(cast(LengthValidator)*v).max = len;
			return len;
		}/+
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
		}+/
		
	unittest
	{
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
		this () @safe
		{
			super();
			minLen = 1;
			maxLen = 32;
			required = true;
			unique = true;
			//regexp = "^[a-zA-Z0-9_%.%-]+$";
		}
		this (string label) @safe
		{
			this();
			this.label = label;
		}
}

class PasswordField: TextField
{
	protected:
	public:
		this () @safe
		{
			this.required = true;
		}
		this (string label) @safe
		{
			this();
			this.label = label;
		}
}

class IntField: Field
{
	protected:
		int value_;
		
	public:
		int defaultVal;
	
		string value (string v) @trusted
		{
			value_ = to!int(v);
			return v;
		}
		uint value (uint v) @safe
		{
			value_ = cast(int)v;
			return v;
		}
		int value (int v) @safe
		{
			value_ = v;
			return v;
		}
		int value () @safe const
		{
			return value_;
		}
		bool valid () @trusted
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
		string valAsString () @trusted const
		{
			return to!string(value);
		}
		string defaultValAsString () @trusted const
		{
			return to!string(defaultVal);
		}
	
		
	unittest
	{
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
		
		string value (string v) @safe
		{
			value_ = v !is null && v.length;
			return v;
		}
		uint value (uint v) @safe
		{
			value_ = cast(bool)v;
			return v;
		}
		int value (int v) @safe
		{
			value_ = cast(bool)v;
			return v;
		}
		bool value () @safe const
		{
			return value_;
		}
		bool valid () @trusted
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
		string valAsString () @safe const
		{
			return value? "true" : "false";
		}
		string defaultValAsString () @safe const
		{
			return defaultVal? "true" : "false";
		}
		
	unittest
	{
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
		this (in string defaultVal)
		{
			this.defaultVal = defaultVal;
		}
}
