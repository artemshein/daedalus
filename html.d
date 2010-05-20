module html;

import std.regex;
import qc;

static string[string] htmlEscapeSequences;
static this ()
{
	htmlEscapeSequences = ["<": "&lt;", ">": "&rt;"];
}

string htmlEscape (string s) @trusted
{
	string htmlEscapeReplacer (RegexMatch!(string) m)
	{
		return htmlEscapeSequences[m.hit];
	}
	return replace!(htmlEscapeReplacer)(s, regex("[<>]", "g"));
}

unittest
{
	assert(htmlEscape("<b>abc</b>") == "&lt;b&rt;abc&lt;/b&rt;");
}
