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

string split (string s, string[] dels ...) @safe pure
{
	string[] res;
	auto tail = s;
	foreach (del; dels)
	{
		if (!tail.length)
			break;
		auto idx = tail.indexOf(del);
		if (-1 != idx)
		{
			res ~= tail[0 .. idx];
			tail = tail[idx + del.length + 1 .. $];
		}
	}
	res ~= tail;
	return res;
}
