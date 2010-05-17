module strings;

import std.regex;

string quoteEscape (string s)
{
	return replace(s, regex("\"", "g"), "\"");
}

string interpolate (string s, string[string] v)
{
	string replacer (RegexMatch!(string) m)
	{
		return v[m.captures[0]];
	}
	return replace!(replacer)(s, regex("%[(]([a-zA-Z]+)[)]", "g"));
}
