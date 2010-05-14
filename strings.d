module strings;

import std.regex;

string quoteEscape (string s)
{
	return replace(s, regex("\"", "g"), "\"");
}
