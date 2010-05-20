module extras.auth.forms;

import std.string, std.stdio;
import container, forms, fields, widgets, i18n;

class LoginForm: Form
{
	public:
		mixin(fieldGetterAndSetter!(LoginField, "login"));
		mixin(fieldGetterAndSetter!(PasswordField, "password"));
		mixin(fieldGetterAndSetter!(SubmitField, "signIn"));
		
		this ()
		{
			super();
			fieldsOrder = ["login", "password", "signIn"];
			login = new LoginField(capitalize(tr("login")));
			login.widget = new TextInputFieldWidget(this);
			password = new PasswordField(capitalize(tr("password")));
			password.widget = new PasswordInputFieldWidget(this);
			signIn = new SubmitField(capitalize(tr("sign in")));
			signIn.widget = new SubmitButtonFieldWidget(this);
			widget = new VerticalTableFormWidget;
		}
} 
