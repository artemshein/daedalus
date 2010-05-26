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

@safe:
	
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
	
	const
	uint maxLen ()
	{
		return maxLen_;
	}
	
	const
	string asHtml ()
	in
	{
		assert(widget !is null);
	}
	body
	{
		return widget(this);
	}
	
	const
	string js ()
	in
	{
		assert(widget !is null);
	}
	body
	{
		return widget.js(this);
	}
	
abstract:

	bool valid ();

const:

	string defaultValAsString ();
	string valAsString ();
}

class TextField: Field
{
protected:

	string value_;
	
public:

	string defaultVal;

@safe:
	
	this ()
	{
		super();
	}
	
	string value (string v)
	{
		value_ = v;
		return v;
	}
	
	@trusted
	uint value (uint v)
	{
		value_ = to!string(v);
		return v;
	}
	
	@trusted
	int value (int v)
	{
		value_ = to!string(v);
		return v;
	}
	
	const
	string value ()
	{
		return value_;
	}
	
	@trusted
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
	
	const
	string valAsString ()
	{
		return value;
	}
	
	const
	string defaultValAsString ()
	{
		return defaultVal;
	}
	
	const
	uint minLen ()
	{
		auto v = "length" in validators;
		if (v is null)
			return 0;
		assert(isA!LengthValidator(*v));
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
	
	const
	uint maxLen ()
	{
		auto v = "length" in validators;
		if (v is null)
			return 0;
		assert(isA!LengthValidator(*v));
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
	/+
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
@safe:

	this ()
	{
		super();
		minLen = 1;
		maxLen = 32;
		required = true;
		unique = true;
		//regexp = "^[a-zA-Z0-9_%.%-]+$";
	}
	
	this (string label)
	{
		this();
		this.label = label;
	}
}

class PasswordField: TextField
{
public:
@safe:

	this ()
	{
		this.required = true;
	}
	
	this (string label)
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

@safe:

	@trusted
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
	
	const
	int value ()
	{
		return value_;
	}
	
	@trusted
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
	
	@trusted const
	string valAsString ()
	{
		return to!string(value);
	}
	
	@trusted const
	string defaultValAsString ()
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

@safe:
	
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
	
	const
	bool value ()
	{
		return value_;
	}
	
	@trusted
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
	
	const
	string valAsString ()
	{
		return value? "true" : "false";
	}
	
	const
	string defaultValAsString ()
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
}

class SubmitField: ButtonField
{
public:
@safe:

	this (in string defaultVal)
	{
		this.defaultVal = defaultVal;
	}
}
