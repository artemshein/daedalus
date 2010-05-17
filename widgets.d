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
		Form form;
		
		this (Form form)
		{
			this.form = form;
		}
		
		abstract:
			string opCall (Field);
			string js (Field);
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
		
		this (Form form)
		{
			super(form);
		}
		string opCall (Field f, string tail = "")
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
		this (Form form)
		{
			super(form);
		}
		string opCall (Field field, string tail = "")
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
		string renderValue (Field f)
		{
			auto v = f.valAsString;
			if (!v.length)
				v = f.defaultValAsString;
			return htmlEscape(v);
		}
		
	public:
		this (Form form)
		{
			super(form);
			type = "checkbox";
		}
		string opCall (Field f)
		{
			return "<textarea" ~ renderName(f) ~ renderId(f, form)
				~ renderClasses(f) ~ renderOnClick(f) ~ renderOnChange(f)
				~ ">" ~ renderValue(f) ~ "</textarea>" ~ renderHint(f);
		}
}

class CheckboxFieldWidget: InputFieldWidget
{
	public:
		this (Form form)
		{
			super(form);
			type = "checkbox";
		}
		string opCall (Field f)
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
		this (Form form)
		{
			super(form);
			type = "text";
		}
		string opCall (Field f, string tail = "")
		{
			auto maxLen = f.maxLen;
			return InputFieldWidget(f, tail ~ (maxLen? (" maxlength=\"" ~ to!string(maxLen) ~ "\"") : ""));
		}
}

class HiddenInputFieldWidget: TextInputFieldWidget
{
	public:
		this (Form form)
		{
			super(form);
			type = "hidden";
		}
}

class PasswordInputFieldWidget: TextInputFieldWidget
{
	public:
		this (Form form)
		{
			super(form);
			type = "password";
		}
}

class ButtonFieldWidget: InputFieldWidget
{
	public:
		this (Form form)
		{
			super(form);
			type = "button";
		}
}

class SubmitButtonFieldWidget: ButtonFieldWidget
{
	this (Form form)
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
	public:
		string fieldId (Field f, Form form)
		{
			auto id = f.id;
			return id.length? id : (form.id ~ toupper(f.name));
		}
		string renderId (Form form)
		{
			auto id = form.id;
			return id.length? (" id=\"" ~ quoteEscape(id) ~ "\"") : "";
		}
		string renderAction (Form form)
		{
			auto action = form.action;
			return action.length? (" action=\"" ~ quoteEscape(action) ~ "\"") : "";
		}
		string renderFormHeader (Form form)
		{
			bool fileUploadFlag;
			foreach (f; form.fieldsByName)
			{
				auto widget = f.widget;
				if (widget !is null && typeid(widget) == typeid(FileInputFieldWidget))
					fileUploadFlag = true;
			}
			return
				"<form" ~ renderId(form) ~ renderAction(form) ~ " method=\"POST\""
					~ (fileUploadFlag? " enctype=\"multipart/form-data\"" : "")
					~ ">";
		}
		string renderLabel (Form form, Field field)
		{
			auto label = field.label;
			if (label is null || !label.length)
				return "";
			auto id = fieldId(field, form);
			if (id is null || !id.length)
				return "<div class=\"fieldLabel\">" ~ label ~ ":</div>";
			return "<div class=\"fieldLabel\"><label for=\""
				~ quoteEscape(htmlEscape(id)) ~ ">"
				~ toupper(tr(field.label)) ~ "</label>:</div>";
		}
		string renderLabelCheckbox (Form form, Field field)
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
		string renderField (Form form, Field field)
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
		string renderFields (Form form)
		{
			string html, js;
			// Hidden fields first
			foreach (field; form.hiddenFields)
				html ~= renderField(form, field);
			html ~= beforeFields;
			/+if "table" == type(form:fieldsList()[1]) then
				for _, fieldset in ipairs(form:fieldsList()) do
					html = html.."<fieldset title="..("%q"):format(fieldset.title:tr():capitalize()).."><legend>"..fieldset.title:tr():capitalize().."</legend>"
					for _, field in ipairs(fieldset.fields) do
						local v = form:field(field)
						local widget = v:widget()
						if widget and not widget:isA(widgets.HiddenInput) and not widget:isA(widgets.Button) then
							local fieldHtml, fieldJs = self:renderField(form, v)
							if fieldJs then js = (js or "")..fieldJs end
							if v:widget():isA(widgets.Checkbox) then
								html = html..self._beforeLabel..self._afterLabel..self._beforeField..fieldHtml.." "..self:renderLabelCheckbox(form, v)..self._afterField
							else
								html = html..self._beforeLabel..self:renderLabel(form, v)..self._afterLabel..self._beforeField..fieldHtml..self._afterField
							end
						end
					end
					html = html.."</fieldset>"
				end
			else
				-- Then visible fields
				for _, v in ipairs(form:visibleFields()) do
					local fieldHtml, fieldJs = self:renderField(form, v)
					if fieldJs then js = (js or "")..fieldJs end
					if v:widget():isA(widgets.Checkbox) then
						html = html..self._beforeLabel..self._afterLabel..self._beforeField..fieldHtml.." "..self:renderLabelCheckbox(form, v)..self._afterField
					else
						html = html..self._beforeLabel..self:renderLabel(form, v)..self._afterLabel..self._beforeField..fieldHtml..self._afterField
					end
				end
			end+/
			// Buttons
			html ~= beforeButtons ~ beforeLabel ~ afterLabel ~ beforeField;
			foreach (field; form.buttonFields)
				html ~= renderField(form, field);
			return html ~ afterField ~ afterButtons ~ afterFields
				~ (js.length
					? "<script type=\"text/javascript\" language=\"JavaScript\">//<![CDATA[\n"
						~ js ~ "\n//]]></script>"
					: ""
				);
		}
		string renderFormEnd (Form form)
		{
			return "</form>";
		}
		string renderJs (Form form)
		{
			auto validationFunc = "function(){";
			foreach (name, f; form.fields)
				foreach (v; f.validators)
				{
					auto id = fieldId(f, form);
					validationFunc ~= "if(!$('#" ~ id ~ "')." ~ v.js
						~ "){$('#" ~ id ~ "').showError(\""
						~ quoteEscape(interpolate(v.errorMsg, ["field": toupper(tr(f.label))]))
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
		string opCall (Form form)
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
