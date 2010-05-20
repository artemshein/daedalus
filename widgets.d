module widgets;

import std.string, std.conv, std.stdio;
import type, strings, i18n, html, forms, fields;

abstract class Widget
{
}

abstract class FieldWidget: Widget
{
	protected:
		string fieldId (in Field f, in Form form) @trusted const
		{
			auto id = f.id;
			return id.length? id : (form.id ~ capitalize(f.name));
		}
		string renderType () @safe const
		{
			return " type=\"" ~ quoteEscape(type) ~ "\"";
		}
		string renderName (in Field f) @safe const
		{
			return " name=\"" ~ quoteEscape(htmlEscape(f.name)) ~ "\"";
		}
		string renderId (in Field f, in Form form) @safe const
		{
			return " id=\"" ~ quoteEscape(htmlEscape(fieldId(f, form))) ~ "\"";
		}
		string renderValue (in Field f) @safe const
		{
			auto v = f.valAsString;
			if (!v.length)
				v = f.defaultValAsString;
			return " value=\"" ~ quoteEscape(htmlEscape(v)) ~ "\"";
		}
		string renderHint (in Field f) @safe const
		{
			return f.hint.length? ("<span class=\"fieldHint\">" ~ tr(f.hint) ~ "</span>") : "";
		}
		string renderClasses (in Field f) @trusted const
		{
			auto classes = f.classes;
			if (classes.length)
				return " class=\"" ~ quoteEscape(join(classes, " ")) ~ (f.errors.length? " error" : "") ~ "\"";
			else
				return f.errors.length? " class=\"error\"" : "";
		}
		string renderOnClick (in Field f) @safe const
		{
			return f.onClick.length? (" onclick=\"" ~ quoteEscape(f.onClick) ~ "\"") : "";
		}
		string renderOnChange (in Field f) @safe const
		{
			return f.onChange.length? (" onchange=\"" ~ quoteEscape(f.onChange) ~ "\"") : "";
		}
	
	public:
		string type;
		const Form form;
		
		this (in Form form) @safe
		{
			this.form = form;
		}
		string js (in Field) @safe const
		{
			return "";
		}
		
		abstract:
			string opCall (in Field, in string tail = "") @safe const;
}

class InputFieldWidget: FieldWidget
{
	protected:
		string renderDisabled (in Field f) @safe const
		{
			return disabled? " disabled=\"disabled\"" : "";
		}
		
	public:
		bool disabled;
		
		this (in Form form) @safe
		{
			super(form);
		}
		string opCall (in Field f, in string tail = "") @safe const
		{
			return "<input" ~ renderType ~ renderName(f) ~ renderId(f, form)
				~ renderValue(f) ~ renderClasses(f) ~ renderOnClick(f)
				~ renderOnChange(f) ~ renderDisabled(f) ~ tail ~ " />"
				~ renderHint(f);
		}
}

class FileInputFieldWidget: InputFieldWidget
{
	protected:
		string type = "file";
		
	public:
		this (in Form form) @safe
		{
			super(form);
		}
		string opCall (in Field field, in string tail = "") @safe const
		{
			return "<input" ~ renderType ~ renderName(field)
				~ renderId(field, form) ~ renderClasses(field)
				~ renderOnClick(field) ~ renderOnChange(field)
				~ tail ~ " />" ~ renderHint(field);
		}
}

class TextAreaFieldWidget: FieldWidget
{
	protected:
		string renderValue (in Field f) @safe const
		{
			auto v = f.valAsString;
			if (!v.length)
				v = f.defaultValAsString;
			return htmlEscape(v);
		}
		
	public:
		this (in Form form) @safe
		{
			super(form);
			type = "checkbox";
		}
		string opCall (in Field f, in string tail = "") @safe const
		{
			return "<textarea" ~ renderName(f) ~ renderId(f, form)
				~ renderClasses(f) ~ renderOnClick(f) ~ renderOnChange(f)
				~ ">" ~ renderValue(f) ~ "</textarea>" ~ renderHint(f);
		}
}

class CheckboxFieldWidget: InputFieldWidget
{
	public:
		this (in Form form) @safe
		{
			super(form);
			type = "checkbox";
		}
		string opCall (in Field f, in string tail = "") @safe const
		{
			auto v = f.valAsString;
			auto tTail = tail.idup;
			if ("1" == v || "true" == v)
				tTail = " checked=\"checked\"";
			return "<input" ~ renderType ~ renderName(f) ~ renderId(f, form)
				~ " value=\"1\"" ~ renderClasses(f) ~ renderOnClick(f)
				~ renderOnChange(f) ~ tTail ~ " />";
		}
}

class TextInputFieldWidget: InputFieldWidget
{
	public:
		this (in Form form) @safe
		{
			super(form);
			type = "text";
		}
		string opCall (in Field f, in string tail = "") @trusted const
		{
			auto maxLen = f.maxLen;
			return InputFieldWidget(f, tail ~ (maxLen? (" maxlength=\"" ~ to!string(maxLen) ~ "\"") : ""));
		}
}

class HiddenInputFieldWidget: TextInputFieldWidget
{
	public:
		this (in Form form) @safe
		{
			super(form);
			type = "hidden";
		}
}

class PasswordInputFieldWidget: TextInputFieldWidget
{
	public:
		this (in Form form) @safe
		{
			super(form);
			type = "password";
		}
}

class ButtonFieldWidget: InputFieldWidget
{
	public:
		this (in Form form) @safe
		{
			super(form);
			type = "button";
		}
}

class SubmitButtonFieldWidget: ButtonFieldWidget
{
	this (in Form form) @safe
	{
		super(form);
		type = "submit";
	}
}

abstract class FormWidget: Widget
{
	protected:
		string beforeFields,
			beforeLabel,
			afterLabel,
			beforeField,
			afterField,
			beforeButtons,
			afterButtons,
			afterFields;
			
		string fieldId (in Field f, in Form form) @trusted const
		{
			auto id = f.id;
			return id.length? id : (form.id ~ capitalize(f.name));
		}
		string renderId (in Form form) @safe const
		{
			auto id = form.id;
			return id.length? (" id=\"" ~ quoteEscape(id) ~ "\"") : "";
		}
		string renderAction (in Form form) @safe const
		{
			auto action = form.action;
			return action.length? (" action=\"" ~ quoteEscape(action) ~ "\"") : "";
		}
		string renderFormHeader (in Form form) @trusted const
		{
			bool fileUploadFlag;
			foreach (f; form.fields)
			{
				auto widget = f.widget;
				if (widget !is null && isA!FileInputFieldWidget(widget))
					fileUploadFlag = true;
			}
			return
				"<form" ~ renderId(form) ~ renderAction(form) ~ " method=\"POST\""
					~ (fileUploadFlag? " enctype=\"multipart/form-data\"" : "")
					~ ">";
		}
		string renderLabel (in Form form, in Field field) @trusted const
		{
			auto label = field.label;
			if (label is null || !label.length)
				return "";
			auto id = fieldId(field, form);
			if (id is null || !id.length)
				return "<div class=\"fieldLabel\">" ~ label ~ ":</div>";
			return "<div class=\"fieldLabel\"><label for=\""
				~ quoteEscape(htmlEscape(id)) ~ "\">"
				~ capitalize(tr(field.label)) ~ "</label>:</div>";
		}
		string renderLabelCheckbox (in Form form, in Field field) @safe const
		{
			auto label = field.label;
			if (label is null || !label.length)
				return "";
			auto id = fieldId(field, form);
			if (id is null || !id.length)
				return "<span class=\"fieldLabel\">" ~ label ~ "</span>";
			return "<span class=\"fieldLabel\"><label for=\""
				~ quoteEscape(htmlEscape(id)) ~ "\">"
				~ tr(label) ~ "</label></span>";
		}
		string renderField (in Form form, in Field field) @safe const
		{
			auto html = field.asHtml;
			auto js = field.js;
			auto errors = field.errors;
			if (errors.length)
			{
				html ~= "<ul class=\"fieldErrors\">";
				foreach (error; errors)
					html ~= "<li>" ~ error ~ "</li>";
				html ~= "</ul>";
			}
			return html; //, (js or field:onLoad() and ((js or "")..(field:onLoad() or "")))
		}
		string renderFieldHtml (in Form form, in Field f) @safe const
		{
			auto html = f.asHtml;
			auto errors = f.errors;
			if (errors.length)
			{
				html ~= "<ul class=\"fieldErrors\">";
				foreach (error; errors)
					html ~= "<li>" ~ error ~ "</li>";
				html ~= "</ul>";
			}
			return html;
		}
		string renderFieldJs (in Form form, in Field field) @safe const
		{
			return field.js ~ field.onLoad;
		}
		string renderFields (in Form form) @trusted const
		{
			string html, js;
			// Hidden fields first
			foreach (field; form.hiddenFields)
				html ~= renderFieldHtml(form, field);
			html ~= beforeFields;
			if (form.fieldsets.length)
				foreach (label, fieldset; form.fieldsets)
				{
					html ~= "<fieldset title=\"" ~ quoteEscape(capitalize(tr(label))) ~ "\"><legend>" ~ capitalize(tr(label)) ~ "</legend>";
					foreach (fName; fieldset)
					{
						auto f = form.fields[fName];
						auto widget = f.widget;
						if (widget && !isA!HiddenInputFieldWidget(widget) && !isA!ButtonFieldWidget(widget))
						{
							auto fHtml = renderFieldHtml(form, f);
							js ~= renderFieldJs(form, f);
							if (isA!CheckboxFieldWidget(f.widget))
								html ~= beforeLabel ~ afterLabel ~ beforeField ~ fHtml ~ " " ~ renderLabelCheckbox(form, f) ~ afterField;
							else
								html ~= beforeLabel ~ renderLabel(form, f) ~ afterLabel ~ beforeField ~ fHtml ~ afterField;
						}
					}
					html ~= "</fieldset>";
				}
			else
				foreach (f; form.visibleFields)
				{
					auto fHtml = renderFieldHtml(form, f);
					js ~= renderFieldJs(form, f);
					if (isA!CheckboxFieldWidget(f.widget))
						html ~= beforeLabel ~ afterLabel ~ beforeField
							~ fHtml ~ " " ~ renderLabelCheckbox(form, f)
							~ afterField;
					else
						html ~= beforeLabel ~ renderLabel(form, f)
							~ afterLabel ~ beforeField ~ fHtml ~ afterField;
				}
			// Buttons
			html ~= beforeButtons ~ beforeLabel ~ afterLabel ~ beforeField;
			foreach (field; form.buttonFields)
			{
				assert(field !is null);
				html ~= renderFieldHtml(form, field);
			}
			return html ~ afterField ~ afterButtons ~ afterFields
				~ (js.length
					? "<script type=\"text/javascript\" language=\"JavaScript\">//<![CDATA[\n"
						~ js ~ "\n//]]></script>"
					: ""
				);
		}
		string renderFormEnd (in Form form) @safe const
		{
			return "</form>";
		}
		string renderJs (in Form form) @trusted const
		{
			auto validationFunc = "function(){";
			foreach (name, f; form.fields)
				foreach (v; f.validators)
				{
					auto id = fieldId(f, form);
					validationFunc ~= "if(!$('#" ~ id ~ "')." ~ v.js
						~ "){$('#" ~ id ~ "').showError(\""
						~ quoteEscape(interpolate(v.errorMsg, ["field": capitalize(tr(f.label))]))
						~ "\");return false;}";
				}
			validationFunc ~= "return true;}";
			auto ajax = form.ajax;
			return "<script type=\"text/javascript\" language=\"JavaScript\">//<![CDATA[\n"
				~ (ajax.length
					? ("var options=" ~ ajax//jsonEncode(ajax)
						~ ";options.beforeSubmit=" ~ validationFunc
						~ ";$(\"#" ~ form.id ~ "\").ajaxForm(options);")
					: ("$(\"#" ~ form.id ~ "\").submit(" ~ validationFunc ~");")
				)
				~ "\n//]]></script>";
		}
	
	public:
		string opCall (in Form form) @safe const
		{
			return renderFormHeader(form) ~ renderFields(form)
				~ renderFormEnd(form) ~ renderJs(form);
		}
}

class FlowFormWidget: FormWidget
{
	protected:
		string beforeFields = "",
			beforeLabel = " ",
			afterLabel = " ",
			beforeField = " ",
			afterField = " ",
			beforeButtons = "<div class=\"buttons\">",
			afterButtons = "</div>",
			afterFields = "";
}

class HorisontalTableFormWidget: FormWidget
{
	protected:
		string beforeFields = "<table><tbody><tr>",
			beforeLabel = "<th>",
			afterLabel = "</th>",
			beforeField = "<td>",
			afterField = "</td>",
			beforeButtons = "",
			afterButtons = "",
			afterFields = "</tr></tbody></table>";
}

class VerticalTableFormWidget: FormWidget
{
	protected:
		string beforeFields = "<table><tbody>",
			beforeLabel = "<tr><th>",
			afterLabel = "</th>",
			beforeField = "<td>",
			afterField = "</td></tr>",
			beforeButtons = "",
			afterButtons = "",
			afterFields = "</tbody></table>";
}
