module strings;

import std.regex;

string quoteEscape (string s) @trusted
{
	return replace(s, regex("\"", "g"), "\"");
}

string interpolate (string s, in string[string] v) @trusted
{
	string replacer (RegexMatch!(string) m)
	{
		return v[m.captures[0]];
	}
	return replace!(replacer)(s, regex("%[(]([a-zA-Z]+)[)]", "g"));
}
