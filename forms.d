/**
 * Forms
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module forms;

import std.stdio;
import type, strings, container, widgets, fields;

abstract class Form: Container
{
	protected:
	public:
		string id, action, ajaxUrl, ajax;
		FormWidget widget, ajaxWidget;
		string[] fieldsOrder;
		string[][string] fieldsets;
		
		this () @safe
		{
			super();
		}
		string asHtml () @safe const
		in
		{
			assert(widget !is null, "widget must be set first");
		}
		body
		{
			return widget(this);
		}
		const(Field)[string] activeFields () @trusted pure const
		{
			Field[string] res;
			foreach (name; fieldsOrder)
			{
				assert(name in fields, "no field " ~ name);
				res[name] = cast(Field) fields[name]; // hmmm...
			}
			return res;
		}
		const(Field)[string] hiddenFields () @trusted const
		{
			Field[string] res;
			foreach (name, f; activeFields)
			{
				assert(f !is null);
				auto widget = f.widget;
				if (widget !is null && isA!HiddenInputFieldWidget(widget))
					res[name] = cast(Field) f; // hmmm...
			}
			return res;
		}
		const(Field)[string] buttonFields () @trusted const
		{
			Field[string] res;
			foreach (name, f; fields)
				if (isA!ButtonField(f))
				{
					assert(f !is null);
					res[name] = cast(Field) f; // hmmm...
				}
			return res;
		}
		const(Field)[string] visibleFields () @trusted const
		{
			Field[string] res;
			foreach (name, f; activeFields)
			{
				auto widget = f.widget;
				if (widget !is null && !isA!HiddenInputFieldWidget(widget) && !isA!ButtonFieldWidget(widget))
					res[name] = cast(Field) f; // hmmm...
			}
			return res;
		}
}
