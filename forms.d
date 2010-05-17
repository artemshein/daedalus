module forms;

import strings, container, widgets, fields;

abstract class Form: Container
{
	protected:
	public:
		string id, action, ajaxUrl, ajax;
		FormWidget widget, ajaxWidget;
		string[] fieldsOrder;
				
		string asHtml ()
		in
		{
			assert(widget !is null, "widget must be set first");
		}
		body
		{
			return widget(this);
		}
		Field[string] activeFields ()
		{
			static Field[string] res = null;
			if (res is null)
				foreach (name; fieldsOrder)
					res[name] = fieldsByName[name];
			return res;
		}
		Field[string] hiddenFields ()
		{
			static Field[string] res = null;
			if (res is null)
				foreach (name, f; activeFields)
				{
					auto widget = f.widget;
					if (widget !is null && typeid(widget) == typeid(HiddenInputFieldWidget))
						res[name] = f;
				}
			return res;
		}
		Field[string] buttonFields ()
		{
			Field[string] res = null;
			if (res is null)
				foreach (name, f; fieldsByName)
					if (typeid(f) == typeid(ButtonField))
						res[name] = f;
			return res;
		}
}
