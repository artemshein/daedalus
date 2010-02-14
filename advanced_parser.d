module advanced_parser;

import std.stdio, std.stdarg, std.conv, std.array, std.typetuple;
version(unittest) import qc;
debug import std.string;

/++
 + Helpers
 +/

string generateOpIndexMethods (string parserType)
{
	auto funcStr = "FunctionActionParser!(" ~ parserType ~")";
	auto dlgStr = "DelegateActionParser!(" ~ parserType ~")";
	return funcStr ~ " opIndex (void function (AttrType) act) { return new " ~ funcStr ~ "(this, act); } "
		~ dlgStr ~ " opIndex (void delegate (AttrType) act) { return new " ~ dlgStr ~ "(this, act); } ";
}

void skipOver (Skipper)  (ref string s, Skipper skipper)
{
	static if (is(Skipper == class) && Skipper.isParser)
		while (skipper(s)) {}
}

struct Vector (Fields ...)
{
	Fields fields;
}

/++
 + Parser
 +/

class Parser (Derived)
{
	enum bool isParser = true;
	bool opCall (ref string s, Parser skipper = null) {return false;}
	const ref Derived derived ()
	{
		return *cast(const Derived*)&this;
	}
}

class PrimitiveParser (Derived): Parser!(Derived)
{
}

class NaryParser (Derived): Parser!(Derived)
{
}

class UnaryParser (Derived): Parser!(Derived)
{
}

class BinaryParser (Derived): Parser!(Derived)
{
}

/++
 + NumericParser
 +/

class NumericParser (Type)
{
	alias Type AttrType;
	bool opCall (Skipper) (ref string s, Skipper skipper = null)
	{
		auto fs = s;
		skipOver(s, skipper);
		try
		{
			parse!Type(s);
		}
		catch
		{
			s = fs;
			return false;
		}
		return true;
	}
	bool opCall (Skipper) (ref string s, Skipper skipper = null, out AttrType attr = Type.init)
	{
		auto fs = s;
		skipOver(s, skipper);
		try
		{
			attr = parse!Type(s);
		}
		catch
		{
			s = fs;
			return false;
		}
		return true;
	}
	mixin(generateOpIndexMethods(typeof(this).stringof));
}

unittest
{
	scope t = new Test!NumericParser();
	auto s = "123bcd";
	uint a;
	assert(uint_(s, null, a));
	assert(a == 123);
	assert(s == "bcd");
	s = "123bcd";
	byte b;
	assert(byte_(s, null, b));
	assert(b == 123);
	assert(s == "bcd");
}

/++
 + RepeatParser
 +/

class RepeatParser (ParserType)
{
	alias ParserType.AttrType[] AttrType;
	ParserType parser;
	uint from, to;
	this (ParserType parser, uint from, uint to = 0)
	{
		this.parser = parser;
		this.from = from;
		this.to = to? to : to.max;
	}
	bool opCall (Skipper) (ref string s, Skipper skipper = null)
	{
		auto fs = s;
		if (skipper !is null)
			while (skipper(s)) {}
		uint cnt;
		while (cnt < to && parser(s, skipper))
			++cnt;
		if (cnt < from)
		{
			s = fs;
			return false;
		}
		return true;
	}
	bool opCall (Skipper) (ref string s, Skipper skipper = null, out AttrType attr = AttrType.init)
	{
		auto fs = s;
		auto app = appender(&attr);
		skipOver(s, skipper);
		uint cnt;
		ParserType.AttrType a;
		while (cnt < to && parser(s, skipper, a))
		{
			++cnt;
			app.put(a);
		}
		if (cnt < from)
		{
			s = fs;
			return false;
		}
		return true;
	}
}

unittest
{
	scope t = new Test!(RepeatParser!CharParser, "!CharParser")();
	auto a = +char_('A');
	auto s = "AAAAA";
	char[] s2;
	assert(a(s, null, s2));
	assert("" == s);
	assert("AAAAA" == s2);
}

/+class BasicParser (Type)
{
	typedef AttrType Type;
	
}+/

/++
 + CharParser
 +/

class CharParser
{
	alias char AttrType;
	AttrType ch;
	this (AttrType ch)
	{
		this.ch = ch;
	}
	SequenceParser!(SequenceParser!(CharParser, ParserType), Vector!(CharParser, ParserType)) opShr (ParserType) (ParserType p)
	{
		return new SequenceParser!(SequenceParser!(CharParser, ParserType), Vector!(CharParser, ParserType))(Vector!(CharParser, ParserType)(this, p));
	}
	RepeatParser!CharParser opPos ()
	{
		return new RepeatParser!CharParser(this, 1);
	}
	bool opCall (Skipper) (ref string s, Skipper skipper = null)
	{
		auto fs = s;
		if (skipper !is null)
			while (skipper(s)) {}
		if (s.length == 0 || s[0] != ch)
		{
			s = fs;
			return false;
		}
		s = s[1 .. $];
		return true;
	}
	bool opCall (Skipper) (ref string s, Skipper skipper = null, out AttrType attr = AttrType.init)
	{
		auto fs = s;
		skipOver(s, skipper);
		if (s.length == 0 || (attr = s[0]) != ch)
		{
			s = fs;
			return false;
		}
		s = s[1 .. $];
		return true;
	}
}

unittest
{
	scope t = new Test!CharParser();
	auto p = char_('Z');
	auto s = "ZZZ";
	char ch;
	assert(p(s, null, ch));
	assert('Z' == ch);
	assert("ZZ" == s);
}

CharParser char_ (char ch)
{
	return new CharParser(ch);
}
/++
 + StringParser
 +/

class StringParser
{
	alias string AttrType;
	string str;
	this (string s)
	{
		this.str = s;
	}
	SequenceParser!(StringParser, ParserType) opShr (ParserType) (ParserType p)
	{
		return new SequenceParser!(StringParser, ParserType)(this, p);
	}
	bool opCall (Skipper) (ref string s, Skipper skipper = null)
	{
		auto fs = s;
		if (skipper !is null)
			while (skipper(s)) {}
		if (s.length < str.length || s[0 .. str.length] != str)
		{
			s = fs;
			return false;
		}
		s = s[str.length .. $];
		return true;
	}
	bool opCall (Skipper) (ref string s, Skipper skipper = null, out AttrType attr = AttrType.init)
	{
		auto fs = s;
		if (skipper !is null)
			while (skipper(s)) {}
		if (s.length < str.length || s[0 .. str.length] != str)
		{
			s = fs;
			return false;
		}
		attr = s[0 .. str.length];
		s = s[str.length .. $];
		return true;
	}
}

StringParser string_ (string s)
{
	return new StringParser(s);
}

/++
 + SequenceParser family
 +/

template attrTypes (ParsersTypes ...)
{
	static if (ParsersTypes.length > 1)
		alias TypeTuple!(ParsersTypes[0].AttrType, attrTypes!(ParsersTypes[1 .. $])) attrTypes;
	else
		alias TypeTuple!(ParsersTypes[0].AttrType) attrTypes;
}

template attrType (ParserType)
{
	alias ParserType.AttrType attrType;
}

class SequenceParser (Derived, Elements): NaryParser!(Derived)
{
	protected:
		Elements elements;
	public:
		this (Elements elements)
		{
			this.elements = elements;
		}
		SequenceParser!(SequenceParser!(Derived, Elements), Vector!(SequenceParser!(Derived, Elements), ParserType)) opShr (ParserType) (ParserType p)
		{
			return SequenceParser!(SequenceParser!(Derived, Elements), Vector!(SequenceParser!(Derived, Elements), ParserType))(this, p);
		}
		bool parse (Context, Skipper, Attribute) (ref string s, Context context, Skipper skipper, out Attribute attr)
		{
			/+auto fs = s;
			skipOver(s, skipper);
			foreach (i, ParserType; ParsersTypes)
			{
				if (!parsers[i](s, skipper, attrs[i]))
					goto NoMatch;
			}
			return true;
			NoMatch:
				s = fs;
				return false;+/
			parse(s, context, skipper, attr);
		}
		/+bool opCall (Skipper) (ref string s, out attrTypes!(ParsersTypes) attrs)
		{
			return this.opCall(s, null, attrs);
		}+/
		/+
		bool opCall (Skipper) (ref string s, Skipper skipper = null)
		{
			auto fs = s;
			skipOver(s, skipper);
			foreach (i, ParserType; ParsersTypes)
			{
				if (!parsers[i](s, skipper))
					goto NoMatch;
			}
			return true;
			NoMatch:
				s = fs;
				return false;
		}+/
		/+
		bool opCall (s, skipper, char c, uint u, byte b)
		{
			auto fs = s;
			if (skipper !is null)
				while (skipper(s)) {}
			if (anyIf(s, skipper, parsers[0], parsers[1], parsers[2], c, u, b))
				return true;
			s = fs;
			return false;
		}+/
}

unittest
{
	new Test!(SequenceParser, "!CharParser,CharParser,CharParser")(
	{
		auto p = char_('A') >> char_('B') >> char_('C');
		auto s = "ABCDEF";
		Vector!(char, char, char) cs;
		assert(p.parse(s, cs));
		assert('A' == c1);
		assert('B' == c2);
		assert('C' == c3);
		assert("DEF" == s);
		s = "ABCDE";
		assert(p(s));
		assert("DE" == s);
	});
	new Test!(SequenceParser, "!(StringParser,CharParser,NumericParser,RepeatParser!CharParser)")(
	{
		auto p = string_("ABC") >> char_('D') >> uint_ >> +char_('Z');
		auto s = "ABCD456ZZend";
		string s2;
		char c1;
		char[] s3;
		uint u;
		assert(p(s, null, s2, c1, u, s3));
		assert("end" == s);
		assert("ABC" == s2);
		assert('D' == c1);
		assert(456 == u);
		assert("ZZ" == s3);
	});
}

/++
 + ContextParser
 +/


/++
 + ActionParser family
 +/
class ActionParser (ParserType, ActionType)
{
	ParserType parser;
	ActionType act;
	this (ParserType parser, ActionType act)
	{
		this.act = act;
		this.parser = parser;
	}
}

template FunctionActionParser (ParserType)
{
	alias ActionParser!(ParserType, void function (ParserType.AttrType)) FunctionActionParser;
}

template DelegateActionParser (ParserType)
{
	alias ActionParser!(ParserType, void delegate (ParserType.AttrType)) DelegateActionParser;
}

unittest
{
	uint value;
	void setValueTo (uint v)
	{
		value = v;
	}
	auto p = uint_[&setValueTo];
	auto s = "535";
	assert(p(s));
	assert("" == s);
	assert(535 == value);
}

static
{
	NumericParser!ulong ulong_;
	NumericParser!uint uint_;
	NumericParser!ushort ushort_;
	NumericParser!ubyte ubyte_;
	NumericParser!long long_;
	NumericParser!int int_;
	NumericParser!short short_;
	NumericParser!byte byte_;
}

static this ()
{
	ulong_ = new NumericParser!ulong();
	uint_ = new NumericParser!uint();
	ushort_ = new NumericParser!ushort();
	ubyte_ = new NumericParser!ubyte();
	long_ = new NumericParser!long();
	int_ = new NumericParser!int();
	short_ = new NumericParser!short();
	byte_ = new NumericParser!byte();
}
