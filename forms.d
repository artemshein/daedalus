module forms;

import container, widgets;

abstract class Form: Container
{
	protected:
	public:
		string id;
		FormWidget widget;
		string[] fieldsOrder;
				
		string asHtml ()
		{
			return widget(this);
		}
}
