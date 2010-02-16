module parser;

debug = parser;

import std.conv, std.array, std.variant;
version(unittest) import qc;
debug(parser) import std.string, std.stdio;

/++
 + Parser
 +/

abstract class Parser
{
	/+protected:
		static MatchLen matchSkipParser (string s, Parser skipParser)
		{
			auto res = NoMatch;
			while (true)
			{
				auto res2 = skipParser(s);
				if (NoMatch != res2)
				{
					s = s[res2 .. $];
					res = (NoMatch == res)? res2 : res + res2;
				}
				else
					break;
			}
			return res;
		}
		uint offset;+/
	public:
	/+alias void function (string) matchAction;
	alias void delegate (string) matchDelegate;
	alias void function (string, T[]) beforeAction;
	alias void function (string, T[], int) afterAction;+/
	/+debug
	{
		private beforeAction[] beforeActions;
		private afterAction[] afterActions;
		private string name;
		string getName () { return name; }
		Parser!(T) setName (string n) { name = n; return this; }
		Parser!(T) addBeforeAction (beforeAction action) { beforeActions.length = beforeActions.length + 1; beforeActions[$-1] = action; return this; }
		Parser!(T) addAfterAction (afterAction action) { afterActions.length = afterActions.length + 1; afterActions[$-1] = action; return this; }
		void performBeforeActions (T[] stream)
		{
			foreach (action; beforeActions)
				action(name, stream);
		}
		void performAfterActions (T[] stream, int result)
		{
			foreach (action; afterActions)
				action(name, stream, result);
		}
		void trace (T[] name)
		{
			this.name = name;
			addBeforeAction(&Debugger!(T).beginOut);
			addAfterAction(&Debugger!(T).endOut);
			addBeforeAction(&Debugger!(T).beginOut);
			addAfterAction(&Debugger!(T).endOut);
		}
	}+/
		bool opCall (ref string s, Parser skipper = null) { return parse(s, skipper); }
		bool opCall (ref string s, out Variant v, Parser skipper = null) { return parse(s, v, skipper); }
		Parser opNeg () { return new NotParser(this); }
		AndParser opAdd (Parser p) { return new AndParser([this, p]); }
		RepeatParser opSlice (uint from, uint to = 0) { return new RepeatParser(this, from, to); }
		RepeatParser opStar () { return new RepeatParser(this, 0, 0); }
		RepeatParser opCom () { return new RepeatParser(this, 0, 1); }
		RepeatParser opPos () { return new RepeatParser(this, 1, 0); }
		SequenceParser opShr (Parser p) { return new SequenceParser([this, p]); }
		SequenceParser opShr (char ch) { return new SequenceParser([this, new CharParser(ch)]); }
		SequenceParser opShr_r (char ch) { return new SequenceParser([cast(Parser)new CharParser(ch), this]); }
		AndParser opSub (Parser p) { return new AndParser([this, -p]); }
		OrParser opOr (Parser p) { return new OrParser([this, p]); }
		OrParser opOr (char ch) { return new OrParser([this, new CharParser(ch)]); }
		Parser opIndex (Action) (Action act) { return new ActionParser!(Action)(this, act); }
		/+
		Parser opIndex (void function () act) { return new VoidFunctionActionParser(this, act); }
		Parser opIndex (void delegate () act) { return new VoidDelegateActionParser(this, act); }
		Parser opIndex (void function (char) act) { return new FunctionActionParser!char(this, act); }
		Parser opIndex (void delegate (char) act) { return new DelegateActionParser!char(this, act); }
		Parser opIndex (void function (string) act) { return new FunctionActionParser!string(this, act); }
		Parser opIndex (void delegate (string) act) { return new DelegateActionParser!string(this, act); }
		Parser opIndex (void function (int) act) { return new FunctionActionParser!int(this, act); }
		Parser opIndex (void delegate (int) act) { return new DelegateActionParser!int(this, act); }
		Parser opIndex (void function (uint) act) { return new FunctionActionParser!uint(this, act); }
		Parser opIndex (void delegate (uint) act) { return new DelegateActionParser!uint(this, act); }
		Parser opIndex (void function (double) act) { return new FunctionActionParser!double(this, act); }
		Parser opIndex (void delegate (double) act) { return new DelegateActionParser!double(this, act); }
		+/
		bool match (ref string s)
		{
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			return true;
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			if (skipper !is null)
				while(skipper(s)) {}
			if (!match(s))
			{
				s = fs;
				return false;
			}
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			if (skipper !is null)
				while(skipper(s)) {}
			if (!match(s, v))
			{
				s = fs;
				return false;
			}
			return true;
		}
}

class UnaryParser: Parser
{
	protected:
		Parser parser;
	public:
		bool match (ref string s)
		{
			return parser.match(s);
		}
		bool match (ref string s, out Variant v)
		{
			return parser.match(s, v);
		}
		bool parse (ref string s, Parser skipper = null)
		{
			return parser.parse(s, skipper);
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			return parser.parse(s, v, skipper);
		}
}

class BinaryParser: Parser
{
	protected:
		Parser left, right;
	public:
		this (Parser left, Parser right)
		{
			this.left = left;
			this.right = right;
		}
}

class NaryParser: Parser
{
	protected:
		Parser[] parsers;
}

/++
 + ActionParser
 +/

class ActionParser (Action): UnaryParser
{
	Action action;
	this (Parser parser, Action action)
	{
		this.parser = parser;
		this.action = action;
	}
	bool parse (ref string s, Parser skipper = null)
	{
		auto fs = s;
		if (!parser.parse(s, skipper))
			return false;
		auto sVal = fs[0 .. $ - s.length];
		static if (is(Action : void function (char)) || is(Action : void delegate (char)))
			action(fs[0]);
		else static if (is(Action : void function (string)) || is(Action : void delegate (string)))
			action(to!(string)(sVal));
		else static if (is(Action : void function (byte)) || is(Action : void delegate (byte)))
			action(to!(byte)(sVal));
		else static if (is(Action : void function (ubyte)) || is(Action : void delegate (ubyte)))
			action(to!(ubyte)(sVal));
		else static if (is(Action : void function (short)) || is(Action : void delegate (short)))
			action(to!(short)(sVal));
		else static if (is(Action : void function (ushort)) || is(Action : void delegate (ushort)))
			action(to!(ushort)(sVal));
		else static if (is(Action : void function (int)) || is(Action : void delegate (int)))
			action(to!(int)(sVal));
		else static if (is(Action : void function (uint)) || is(Action : void delegate (uint)))
			action(to!(uint)(sVal));
		else static if (is(Action : void function (long)) || is(Action : void delegate (long)))
			action(to!(long)(sVal));
		else static if (is(Action : void function (ulong)) || is(Action : void delegate (ulong)))
			action(to!(ulong)(sVal));
		else static if (is(Action : void function (float)) || is(Action : void delegate (float)))
			action(to!(float)(sVal));
		else static if (is(Action : void function (double)) || is(Action : void delegate (double)))
			action(to!(double)(sVal));
		return true;
	}
	bool parse (ref string s, out Variant v, Parser skipper = null)
	{
		auto fs = s;
		if (!parser.parse(s, skipper))
			return false;
		auto sVal = fs[0 .. $ - s.length];
		static if (is(Action : void function (char)) || is (Action : void delegate (char)))
		{
			v = fs[0];
			action(fs[0]);
		}
		else static if (is(Action : void function (string)) || is (Action : void delegate (string)))
		{
			v = sVal;
			action(sVal);
		}
		else static if (is(Action : void function (byte)) || is (Action : void delegate (byte)))
		{
			v = sVal;
			action(to!(byte)(sVal));
		}
		else static if (is(Action : void function (ubyte)) || is (Action : void delegate (ubyte)))
		{
			v = sVal;
			action(to!(ubyte)(sVal));
		}
		else static if (is(Action : void function (short)) || is (Action : void delegate (short)))
		{
			v = sVal;
			action(to!(short)(sVal));
		}
		else static if (is(Action : void function (ushort)) || is (Action : void delegate (ushort)))
		{
			v = sVal;
			action(to!(ushort)(sVal));
		}
		else static if (is(Action : void function (int)) || is (Action : void delegate (int)))
		{
			v = sVal;
			action(to!(int)(sVal));
		}
		else static if (is(Action : void function (uint)) || is (Action : void delegate (uint)))
		{
			v = sVal;
			action(to!(uint)(sVal));
		}
		else static if (is(Action : void function (long)) || is (Action : void delegate (long)))
		{
			v = sVal;
			action(to!(long)(sVal));
		}
		else static if (is(Action : void function (ulong)) || is (Action : void delegate (ulong)))
		{
			v = sVal;
			action(to!(ulong)(sVal));
		}
		else static if (is(Action : void function (float)) || is (Action : void delegate (float)))
		{
			v = sVal;
			action(to!(float)(sVal));
		}
		else static if (is(Action : void function (double)) || is (Action : void delegate (double)))
		{
			v = sVal;
			action(to!(double)(sVal));
		}
		return true;
	}
	ActionParser!(Action) opIndex (Action action)
	{	// ???
		this.action = action;
		return this;
	}
}

unittest
{
	new Test!(ActionParser!char, "!char")(
	{
		char ch;
		void setChar (char c)
		{
			ch = c;
		}
		auto p = char_('&')[&setChar];
		auto s = "F";
		assert(!p(s));
		assert(char.init == ch);
		s = "&saff";
		assert(p(s));
		assert('&' == ch);
	});
	new Test!(ActionParser!string, "!string")(
	{
		string value;
		void setValue (string s)
		{
			value = s;
		}
		auto s = "ABCD";
		auto p = string_("ABcd")[&setValue];
		assert(!p(s));
		assert("" == value);
		s = "ABcdEF";
		assert(p(s));
		assert("ABcd" == value);
	});
	new Test!(ActionParser!uint, "!uint")(
	{
		uint value;
		void setValue (uint v)
		{
			value = v;
		}
		auto p = uint_[&setValue];
		auto s = "ABCD";
		assert(!p(s));
		assert(uint.init == value);
		s = "2432";
		assert(p(s));
		assert(2432 == value);
	});
	new Test!(ActionParser!int, "!int")(
	{
		int value;
		void setValue (int v)
		{
			value = v;
		}
		auto p = int_[&setValue];
		auto s = "ABCD";
		assert(!p(s));
		assert(int.init == value);
		s = "-2432";
		assert(p(s));
		assert(-2432 == value);
	});
	new Test!(ActionParser!double, "!double")(
	{
		double value;
		void setValue (double v)
		{
			value = v;
		}
		auto p = double_[&setValue];
		auto s = "ABCD";
		assert(!p(s));
		s = "-2432.54e-2";
		assert(p(s));
		assert((value - -2432.54e-2) < 0.01);
	});
}
/+
class FunctionActionParser (T): ActionParser!(void function (T))
{
	this (Parser parser, void function (T) action)
	{
		super(parser, action);
	}
	bool parse (out string s, Parser skipper = null)
	{
		auto res = match(s, skipParser);
		if (NoMatch != res)
			static if (is(T == char))
				action(s[0]);
			else
				action(to!(T)(s[0 .. res]));
		return res;
	}
}

class VoidFunctionActionParser: ActionParser!(void function ())
{
	this (Parser parser, void function () action)
	{
		super(parser, action);
	}
	bool parse (ref string s, Parser skipper = null)
	{
		auto fs = s;
		if (!parser(s))
		{
			s = fs;
			return false;
		}
		action();
		return true;
	}
}

class DelegateActionParser (T): ActionParser!(void delegate (T))
{
	this (Parser parser, void delegate (T) action)
	{
		super(parser, action);
	}
	MatchLen parse (string s, Parser skipParser = null)
	{
		auto res = match(s, skipParser);
		if (NoMatch != res)
			static if (is(T == char))
				action(s[0]);
			else
				action(to!(T)(s[0 .. res]));
		return res;
	}
}

class VoidDelegateActionParser: ActionParser!(void delegate ())
{
	this (Parser parser, void delegate () action)
	{
		super(parser, action);
	}
	bool parse (ref string s, Parser skipper = null)
	{
		auto fs = s;
		if (!parser(s, skipper))
		{
			s = fs;
			return false;
		}
		action();
		return true;
	}
	unittest
	{
		scope t = new Test!VoidDelegateActionParser();
		uint value;
		void setValueTo5 ()
		{
			value = 5;
		}
		auto p = int_[&setValueTo5];
		assert(!p("asc", space));
		assert(0 == value);
		assert(3 == p("234", space));
		assert(5 == value);
		value = 0;
		assert(!p("asc", space));
		assert(8 == p(" 	\r\n	234", space));
		assert(5 == value);
	}
}+/

/++
 + PrimitiveParser
 +/

class PrimitiveParser (Type): Parser
{
	protected:
	public:
		bool match (ref string s)
		{
			try
			{
				std.conv.parse!(Type)(s);
			}
			catch
			{
				return false;
			}
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			try
			{
				v = std.conv.parse!(Type)(s);
			}
			catch
			{
				return false;
			}
			return true;
		}
}

unittest
{
	new Test!uint_(
	{
		auto s = (78_245_235).stringof;
		assert(uint_(s));
		s = (0).stringof;
		assert(uint_(s));
		s = (-45_235_901).stringof;
		assert(!uint_(s));
		s = "g";
		assert(!uint_(s));
		s = "";
		assert(!uint_(s));
	});
	new Test!int_(
	{
		auto s = (-78_245_235).stringof;
		assert(int_(s));
		s = (0).stringof;
		assert(int_(s));
		s = (45_235_901).stringof;
		assert(int_(s));
		s = "g";
		assert(!int_(s));
		s = "";
		assert(!int_(s));
	});
	new Test!double_(
	{
		auto s = "-78245.5294e42";
		assert(double_(s));
		s = "0.00001";
		assert(double_(s));
		s = "546";
		assert(double_(s));
		s = ".05e-24";
		assert(double_(s));
		s = "ebcd";
		assert(!double_(s));
		s = "";
		assert(!double_(s));
	});
}

/++
 + CharParser
 +/

class CharParser: Parser
{
	protected:
		char value;
	public:
		this (char v)
		{
			value = v;
		}
		bool match (ref string s)
		{
			if (0 == s.length || s[0] != value)
				return false;
			s = s[1 .. $];
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			if (0 == s.length || s[0] != value)
				return false;
			v = s[0];
			s = s[1 .. $];
			return true;
		}

	unittest
	{
		scope t = new Test!CharParser();
		auto p = char_('A');
		auto s = "ABCDE";
		assert(1 == p(s));
		s = "BCDE";
		assert(!p(s));
		s = "";
		assert(!p(s));
		s = "A";
		assert(p(s));
		s = "	A";
		assert(p(s, space));
	}
}

/++
 + EndParser
 +/

class EndParser: Parser
{
	public:
		bool match (ref string s)
		{
			if (0 != s.length)
				return false;
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			if (0 != s.length)
				return false;
			return true;
		}
	unittest
	{
		scope t = new Test!EndParser();
		auto s = "";
		assert(end(s));
		s = "A";
		assert(!end(s));
		s = "  	 ";
		assert(end(s, space));
	}
}

/++
 + StrParser
 +/

class StrParser: Parser
{
	protected:
		string value;
	public:
		this (string v)
		{
			value = v;
		}
		bool match (ref string s)
		{
			if (s.length < value.length || s[0 .. value.length] != value)
				return false;
			s = s[value.length .. $];
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			if (s.length < value.length || s[0 .. value.length] != value)
				return false;
			v = value;
			s = s[value.length .. $];
			return true;
		}

	unittest
	{
		scope t = new Test!StrParser();
		auto p = string_("CDE");
		auto s = "CDEFGH";
		assert(p(s, space));
		s = "CDFG";
		assert(!p(s, space));
		s = "";
		assert(!p(s, space));
		s = "	 \r\nCDE";
		assert(p(s, space));
	}
}

/++
 + SequenceParser
 +/

class SequenceParser: NaryParser
{
	public:
		this (Parser[] parsers)
		{
			this.parsers = parsers;
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			foreach (p; parsers)
			{
				if (!p(s, skipper))
				{
					s = fs;
					return false;
				}
			}
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			v = new Variant[](parsers.length);
			foreach (i, p; parsers)
			{
				if (!p(s, *v[i].peek!(Variant)(), skipper))
				{
					s = fs;
					return false;
				}
			}
			return true;
		}
		SequenceParser opShr (SequenceParser parser) { return new SequenceParser(parsers ~ parser.parsers); }
		SequenceParser opShr (Parser parser) { return new SequenceParser(parsers ~ parser); }
		SequenceParser opShr (char c) { return new SequenceParser(parsers ~ [new CharParser(c)]); }

	unittest
	{
		scope t = new Test!SequenceParser();
		auto p = char_('A') >> 'B' >> 'C' >> 'D';
		auto s = "ABCDE";
		assert(p(s, space));
		s = "BCDE";
		assert(!p(s, space));
		s = "";
		assert(!p(s, space));
		s = "ABCD";
		assert(p(s, space));
		s = "	 \r	ABCD";
		assert(p(s, space));
	}
}

/++
 + RepeatParser
 +/

class RepeatParser: UnaryParser
{
	protected:
		uint from, to;
	public:
		this (Parser parser, uint from, uint to = 0)
		{
			this.parser = parser;
			this.from = from;
			if (to > 0)
				this.to = to;
			else
				this.to = to.max;
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			uint counter;
			while (counter < to)
			{
				if (!parser(s, skipper))
					break;
				++counter;
			}
			if (counter < from)
			{
				s = fs;
				return false;
			}
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			uint counter;
			Variant[] res;
			while (counter < to)
			{
				if (res.length <= counter)
				{
					res.length = res.length * 2 + 1;
				}
				if (!parser(s, res[counter], skipper))
					break;
				++counter;
			}
			res.length = counter - 1;
			v = res;
			if (counter < from)
			{
				s = fs;
				return false;
			}
			return true;
		}

	unittest
	{
		scope t = new Test!RepeatParser();
		auto p = char_('Z')[3..5];
		auto s = "";
		assert(!p(s, space));
		s = "ZZ";
		assert(!p(s, space));
		s = "ZZZ";
		assert(p(s, space));
		s = "ZZZZ";
		assert(p(s));
		s = "ZZZZZ";
		assert(p(s));
		s = "ZZZZZZ";
		assert(p(s, space));
		s = "	   ZZZZZZ";
		assert(p(s, space));
		auto sp = char_('A') >> 'B' >> 'C' >> 'D';
		auto p2 = sp[0..2];
		s = "";
		assert(p2(s, space));
		s = "ABECDABCDEFGH";
		assert(p2(s, space));
		s = "ABCDABC";
		assert(p2(s, space));
		s = "ABCDABCDEFGH";
		assert(p2(s, space));
		s = "ABCDABCDABCDEFGH";
		assert(p2(s, space));
		s = "	\rABCDABCDABCDEFGH";
		assert(p2(s, space));
		auto p3 = *char_('X');
		s = "YXZ";
		assert(p3(s, space));
		s = "X";
		assert(p3(s, space));
		s = "XYZ";
		assert(p3(s, space));
		s = "XXXYZ";
		assert(p3(s, space));
		s = "XXXXX";
		assert(p3(s, space));
		s = "		\r\n\nXXXXX";
		assert(p3(s, space));
	}
}

class AndParser: NaryParser
{
	public:
		this (Parser[] parsers)
		{
			this.parsers = parsers;
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			uint max = 0;
			foreach (p; parsers)
			{
				s = fs;
				if (!p(s, skipper))
				{
					s = fs;
					return false;
				}
				auto matchLen = fs.length - s.length; 
				if (matchLen > max)
					max = matchLen;
			}
			s = fs[max .. $];
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			uint max = 0;
			Variant[] res;
			res.length = parsers.length;
			foreach (i, p; parsers)
			{
				s = fs;
				if (!p(s, res[i], skipper))
				{
					s = fs;
					return false;
				}
				auto matchLen = fs.length - s.length; 
				if (matchLen > max)
					max = matchLen;
			}
			v = res;
			s = fs[max .. $];
			return true;
		}

	unittest
	{
		scope t = new Test!AndParser();
		auto p = char_('A') + string_("ABC");
		auto s = "";
		assert(!p(s, space));
		s = "A";
		assert(!p(s, space));
		s = "ABC";
		assert(p(s, space));
		s = "ABCDE";
		assert(p(s, space));
		s = "\v\r\nABCDE";
		assert(p(s, space));
		auto p2 = string_("ABC") - string_("ABCDE");
		s = "";
		assert(!p2(s, space));
		s = "ABC";
		assert(p2(s, space));
		s = "ABCD";
		assert(p2(s, space));
		s = "\rABCD";
		assert(p2(s, space));
		s = "ABCDE";
		assert(!p2(s, space));
		s = "ABCDEF";
		assert(!p2(s, space));
		s = "\r\nABCDEF";
		assert(!p2(s, space));
	}
}

/++
 + OrParser
 +/

class OrParser: NaryParser
{
	public:
		this (Parser[] parsers)
		{
			this.parsers = parsers;
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			foreach (p; parsers)
			{
				if (p(s, skipper))
					return true;
			}
			s = fs;
			return false;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			foreach (p; parsers)
			{
				if (p(s, v, skipper))
					return true;
			}
			s = fs;
			return false;
		}

	unittest
	{
		scope t = new Test!OrParser();
		auto p = string_("ABC") | string_("DEF");
		auto s = "\r\n";
		assert(!p(s, space));
		s = "ABC";
		assert(p(s, space));
		s = "DEF";
		assert(p(s, space));
		s = "\r\nDEF";
		assert(p(s, space));
		s = "BCDEF";
		assert(!p(s, space));
	}
}

class NotParser: UnaryParser
{
	this (Parser parser)
	{
		this.parser = parser;
	}
	bool match (ref string s)
	{
		return !parser.match(s);
	}
	bool match (ref string s, out Variant v)
	{
		return !parser.match(s, v);
	}
	bool parse (ref string s, Parser skipper = null)
	{
		auto fs = s;
		if (parser(s, skipper))
		{
			s = fs;
			return false;
		}
		s = s[$ > 0? 1 : 0 .. $];
		return true;
	}
	bool parse (ref string s, out Variant v, Parser skipper = null)
	{
		auto fs = s;
		if (parser(s, skipper))
		{
			s = fs;
			return false;
		}
		if (s.length)
			v = s[0];
		s = s[$ > 0? 1 : 0 .. $];
		return true;
	}
	Parser opNeg ()
	{
		return parser;
	}
	unittest
	{
		scope t = new Test!NotParser();
		auto ap = char_('A') + string_("ABC");
		auto p = -ap;
		assert(-p is ap);
		auto s = "";
		assert(p(s, space));
		s = "A";
		assert(p(s, space));
		s = "\r A";
		assert(p(s, space));
		s = "ABC";
		assert(!p(s, space));
		s = "ABCDE";
		assert(!p(s, space));
	}
}

/++
 + RangeParser
 +/

class RangeParser: Parser
{
	protected:
		uint start, end;
	public:
		this (uint start, uint end)
		{
			this.start = start;
			this.end = end;
		}
		bool match (ref string s)
		{
			if (!s.length || s[0] < start || s[0] > end)
				return false;
			s = s[1 .. $];
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			if (!s.length || s[0] < start || s[0] > end)
				return false;
			v = s[0];
			s = s[1 .. $];
			return true;
		}

	unittest
	{
		scope t = new Test!RangeParser();
		auto p = range('A', 'C');
		auto s = "  ";
		assert(!p(s, space));
		s = "AB";
		assert(p(s, space));
		s = "BCDEF";
		assert(p(s, space));
		s = "C";
		assert(p(s, space));
		s = "\r\nC";
		assert(p(s, space));
		s = "DEF";
		assert(!p(s, space));
	}
}

/++
 + ContextParser
 +/

abstract class ContextParser: UnaryParser
{
	ContextParser* opAssign (Parser parser)
	{
		this.parser = parser;
		return &this;
	}
}

/++
 + LazyParser
 +/

class LazyParser: Parser
{
	protected:
		Parser* parser;
	public:
		this (Parser* parser)
		{
			this.parser = parser;
		}
		bool match (ref string s)
		{
			return parser.match(s);
		}
		bool match (ref string s, out Variant v)
		{
			return parser.match(s, v);
		}
		bool parse (ref string s, Parser skipper = null)
		{
			return parser.parse(s, skipper);
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			return parser.parse(s, v, skipper);
		}

	unittest
	{
		scope t = new Test!LazyParser();
		Parser p = char_('A');
		auto p2 = lazy_(&p) >> char_('C');
		auto s = "AC";
		assert(p2(s));
		s = "ABC";
		assert(!p2(s));
		p = char_('A') >> char_('B');
		assert(p2(s));
	}
}

LazyParser lazy_ (Parser* p)
{
	return new LazyParser(p);
}

/+
abstract class Grammar
{
	abstract Parser start ();
	this (string s)
	{
		auto res = new ParseInfo(this, s);
		if (!res.full)
			throw new Exception("parse error");
	}
}

class ParseInfo
{
	Parser parser;
	bool hit, full;
	this(Parser parser, string s)
	{
		this.parser = parser;
		auto result = parser(s);
		hit = NoMatch != result;
		full = s.length == result;
	}
	this (Grammar grammar, string s)
	{
		this(grammar.start(), s);
	}
}

ParseInfo parse (Parser parser, string s)
{
	return new ParseInfo(parser, s);
}

ParseInfo parse (Grammar grammar, string s)
{
	return new ParseInfo(grammar, s);
}
+//+
void delegate (T) appendTo (T) (ref T[] v)
{
	void res (T arg1) { v.length += 1; v[$ - 1] = arg1; }
	return &res;
}

void delegate (T) assignTo (T) (ref T v)
{
	void res (T arg1) { v = arg1; }
	return &res;
}
+/

/++
 + Helper functions
 +/

CharParser char_ (char ch)
{
	return new CharParser(ch);
}
/+
SequenceParser sequence (Parser[] parsers)
{
	return new SequenceParser(parsers);
}
+/
StrParser string_ (string str)
{
	return new StrParser(str);
}

RangeParser range (uint start, uint end)
{
	return new RangeParser(start, end);
}

/++
 + Parsers
 +/

static EndParser end = void;
static Parser alpha = void, alnum = void, digit = void, eol = void,
	anychar = void, space = void, byte_ = void, ubyte_ = void,
	short_ = void, ushort_ = void, int_ = void, uint_ = void,
	long_ = void, ulong_ = void, float_ = void, double_ = void;
static this ()
{
	alpha = range('a', 'z') | range('A', 'Z');
	digit = range('0', '9');
	alnum = alpha | digit;
	anychar = range(0, 255);
	end = new EndParser();
	eol = char_('\n') | ('\r' >> ~char_('\n'));
	auto e = (char_('e') | 'E') >> ~(char_('+') | '-') >> +digit;
	byte_ = new PrimitiveParser!(byte)();
	ubyte_ = new PrimitiveParser!(ubyte)();
	short_ = new PrimitiveParser!(short)();
	ushort_ = new PrimitiveParser!(ushort)();
	int_ = new PrimitiveParser!(int)();
	uint_ = new PrimitiveParser!(uint)();
	long_ = new PrimitiveParser!(long)();
	ulong_ = new PrimitiveParser!(ulong)();
	float_ = new PrimitiveParser!(float)();
	double_ = new PrimitiveParser!(double)();
	space = char_(' ') | '\t' | '\v' | eol;
	/*debug
	{
		traceParser(end_p, "end_p");
		traceParser(alpha_p, "alpha_p");
		traceParser(alnum_p, "alnum_p");
		traceParser(anychar_p, "anychar_p");
		traceParser(eol_p, "eol_p");
		traceParser(uint_p, "uint_p");
	}*/
}

/++
 + Unittest
 +/

unittest
{
	new Test!alpha(
	{
		auto s = "b";
		assert(alpha(s, space));
		s = "D";
		assert(alpha(s, space));
		s = "  D";
		assert(alpha(s, space));
		s = "0";
		assert(!alpha(s, space));
		s = "\r\n";
		assert(!alpha(s, space));
	});
	new Test!digit(
	{
		auto s = "8";
		assert(digit(s));
		s = "2";
		assert(digit(s));
		s = "h";
		assert(!digit(s));
		s = "";
		assert(!digit(s));
	});
	new Test!alnum(
	{
		auto s = "8";
		assert(alnum(s));
		s = "y";
		assert(alnum(s));
		s = "$";
		assert(!alnum(s));
		s = "";
		assert(!alnum(s));
	});
	new Test!anychar(
	{
		auto s = "8";
		assert(anychar(s));
		s = "y";
		assert(anychar(s));
		s = "$";
		assert(anychar(s));
		s = "";
		assert(!anychar(s));
	});
	new Test!eol(
	{
		auto s = "\r\n";
		assert(eol(s));
		s = "\n";
		assert(eol(s));
		s = "\r";
		assert(eol(s));
		s = "\n\r";
		assert(eol(s));
		s = "g";
		assert(!eol(s));
		s = "";
		assert(!eol(s));
	});
}

/++
 + Debugging
 +/

debug(parser)
{
	class ParseTracer: UnaryParser
	{
		protected:
			static uint depth;
			string name;
			void writeBeginOut (string stream)
			{
				writefln("%srule (%s) \"%s\"", repeat(" ", depth), name, stream[0 .. ($ > 5)? 5 : $]);
				++depth;
			}
			void writeEndOut (string stream, bool result)
			{
				--depth;
				writefln("%s%srule (%s) \"%s\"", repeat(" ", depth), result? "/" : "#", name, stream[0 .. ($ > 5)? 5 : $]);
			}
		public:
			this (Parser parser, string name)
			{
				this.parser = parser;
				this.name = name;
			}
			bool match (ref string s)
			{
				writeBeginOut(s);
				auto res = parser.match(s);
				writeEndOut(s, res);
				return res;
			}
			bool match (ref string s, out Variant v)
			{
				writeBeginOut(s);
				auto res = parser.match(s, v);
				writeEndOut(s, res);
				return res;
			}
	}
	ParseTracer trace (Parser p, string name)
	{
		return new ParseTracer(p, name);
	}
}
