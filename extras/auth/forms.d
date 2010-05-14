module extras.auth.forms;

import std.string;
import forms, fields, i18n;

class LoginForm: Form
{
	public:
		this ()
		{
			fieldsOrder = ["login", "password", "signIn"];
			addField("login", new LoginField);
			addField("password", new PasswordField(true));
			addField("signIn", new SubmitField(toupper(tr("sign in"))));
		}
} 
