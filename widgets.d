module widgets;

import std.string, std.conv;
import strings, i18n, html, forms, fields;

abstract class Widget
{
}

abstract class FieldWidget: Widget
{
	protected:
		string fieldId (Field f, Form form)
		{
			auto id = f.id;
			return id.length? id : (form.id ~ toupper(f.name));
		}
		string renderType ()
		{
			return " type=\"" ~ quoteEscape(type) ~ "\"";
		}
		string renderName (Field f)
		{
			return " name=\"" ~ quoteEscape(htmlEscape(f.name)) ~ "\"";
		}
		string renderId (Field f, Form form)
		{
			return " id=\"" ~ quoteEscape(htmlEscape(fieldId(f, form))) ~ "\"";
		}
		string renderValue (Field f)
		{
			auto v = f.valAsString;
			if (!v.length)
				v = f.defaultValAsString;
			return " value=\"" ~ quoteEscape(htmlEscape(v)) ~ "\"";
		}
		string renderHint (Field f)
		{
			return f.hint.length? ("<span class=\"fieldHint\">" ~ tr(f.hint) ~ "</span>") : "";
		}
		string renderClasses (Field f)
		{
			auto classes = f.classes;
			if (classes.length)
				return " class=\"" ~ quoteEscape(join(classes, " ")) ~ (f.errors.length? " error" : "") ~ "\"";
			else
				return f.errors.length? " class=\"error\"" : "";
		}
		string renderOnClick (Field f)
		{
			return f.onClick.length? (" onclick=\"" ~ quoteEscape(f.onClick) ~ "\"") : "";
		}
		string renderOnChange (Field f)
		{
			return f.onChange.length? (" onchange=\"" ~ quoteEscape(f.onChange) ~ "\"") : "";
		}
	
	public:
		string type;
		this ()
		{}
}

class InputFieldWidget: FieldWidget
{
	protected:
		string renderDisabled (Field f)
		{
			return disabled? " disabled=\"disabled\"" : "";
		}
		
	public:
		bool disabled;
		
		string opCall (Field f, Form form, string tail = "")
		{
			return "<input" ~ renderType ~ renderName(f) ~ renderId(f, form)
				~ renderValue(f) ~ renderClasses(f) ~ renderOnClick(f)
				~ renderOnChange(f) ~ renderDisabled(f) ~ tail ~ " />"
				~ renderHint(f);
		}
}

class TextAreaFieldWidget: FieldWidget
{
	protected:
		string renderValue (Field f)
		{
			auto v = f.valAsString;
			if (!v.length)
				v = f.defaultValAsString;
			return htmlEscape(v);
		}
		
	public:
		this ()
		{
			super();
			type = "checkbox";
		}
		string opCall (Field f, Form form)
		{
			return "<textarea" ~ renderName(f) ~ renderId(f, form)
				~ renderClasses(f) ~ renderOnClick(f) ~ renderOnChange(f)
				~ ">" ~ renderValue(f) ~ "</textarea>" ~ renderHint(f);
		}
}

class CheckboxFieldWidget: InputFieldWidget
{
	public:
		this ()
		{
			super();
			type = "checkbox";
		}
		string opCall (Field f, Form form)
		{
			string tail;
			auto v = f.valAsString;
			if ("1" == v || "true" == v)
				tail = " checked=\"checked\"";
			return "<input" ~ renderType ~ renderName(f) ~ renderId(f, form)
				~ " value=\"1\"" ~ renderClasses(f) ~ renderOnClick(f)
				~ renderOnChange(f) ~ tail ~ " />";
		}
}

class TextInputFieldWidget: InputFieldWidget
{
	public:
		this ()
		{
			super();
			type = "text";
		}
		string opCall (Field f, Form form, string tail = "")
		{
			auto maxLen = f.maxLen;
			return InputFieldWidget(f, form, tail ~ (maxLen? (" maxlength=\"" ~ to!string(maxLen) ~ "\"") : ""));
		}
}

class HiddenInputFieldWidget: TextInputFieldWidget
{
	public:
		this ()
		{
			super();
			type = "hidden";
		}
}

class PasswordInputFieldWidget: TextInputFieldWidget
{
	public:
		this ()
		{
			super();
			type = "password";
		}
}

class ButtonFieldWidget: InputFieldWidget
{
	public:
		this ()
		{
			super();
			type = "button";
		}
}

class SubmitButtonFieldWidget: ButtonFieldWidget
{
	this ()
	{
		super();
		type = "submit";
	}
}

abstract class FormWidget: Widget
{
	public:
		abstract:
			string opCall (Form form);
}
