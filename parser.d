module parser;

import std.stdio, std.stdarg, std.conv;
version(unittest) import qc;
debug import std.string;

debug
{
	class Debugger
	{
		alias void function (string, T[]) beforeAction;
		alias void function (string, T[], int) afterAction;
		static uint depth = 0;
		static void beginOut (string parserName, T[] stream)
		{
			writefln("%srule (%s) \"%s\"", repeat(" ", depth), parserName, stream[0..(($ > 5)? 5 : $)]);
			depth += 1;
		}
		static void endOut (string parserName, T[] stream, int result)
		{
			depth -= 1;
			writefln("%s%srule (%s) \"%s\"", repeat(" ", depth), result >= 0? "/" : "#", parserName, stream[0..((result > 0)? result : 0)]);
		}
	}
}

typedef uint MatchLen;
enum MatchLen NoMatch = MatchLen.max;

abstract class Parser
{
	protected:
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
		MatchLen parse (string s, Parser skipParser = null)
		{
			/+//debug performBeforeActions(stream);
			auto result = match(s);
			//debug performAfterActions(stream, result);
			if (result >= 0)
				performSuccessActions(s, result);
			return result;+/
			return match(s, skipParser);
		}
		MatchLen opCall (string s, Parser skipParser = null) { return parse(s, skipParser); }
		Parser opNeg () { return new NotParser(this); }
		AndParser opAdd (Parser p) { return new AndParser([this, p]); }
		RepeatParser opSlice (uint from = 0, uint to = 0) { return new RepeatParser(this, from, to); }
		RepeatParser opStar () { return new RepeatParser(this, 0, 0); }
		RepeatParser opCom () { return new RepeatParser(this, 0, 1); }
		RepeatParser opPos () { return new RepeatParser(this, 1, 0); }
		SequenceParser opShr (Parser p) { return new SequenceParser([this, p]); }
		SequenceParser opShr (char ch) { return new SequenceParser([this, new CharParser(ch)]); }
		SequenceParser opShr_r (char ch) { return new SequenceParser([cast(Parser)new CharParser(ch), this]); }
		AndParser opSub (Parser p) { return new AndParser([this, -p]); }
		OrParser opOr (Parser p) { return new OrParser([this, p]); }
		OrParser opOr (char ch) { return new OrParser([this, new CharParser(ch)]); }
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
		abstract MatchLen match (string, Parser skipParser = null);
}

abstract class UnaryParser: Parser
{
	Parser parser;
}

abstract class ComposeParser: Parser
{
	Parser[] parsers;
	/+Parser performSuccessActions(string, int)
	{
		///????
	}+/
}

abstract class ActionParser (T): UnaryParser
{
	T action;
	this (Parser parser, T action)
	{
		this.parser = parser;
		this.action = action;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res = parser(s);
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	ActionParser!(T) opIndex (T action)
	{	// ???
		this.action = action;
		return this;
	}
}

class FunctionActionParser (T): ActionParser!(void function (T))
{
	this (Parser parser, void function (T) action)
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

class VoidFunctionActionParser: ActionParser!(void function ())
{
	this (Parser parser, void function () action)
	{
		super(parser, action);
	}
	MatchLen parse (string s)
	{
		auto res = match(s);
		if (NoMatch != res)
			action();
		return res;
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
	MatchLen parse (string s, Parser skipParser = null)
	{
		auto res = match(s, skipParser);
		if (NoMatch != res)
			action();
		return res;
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
		assert(NoMatch == p("asc", space));
		assert(0 == value);
		assert(3 == p("234", space));
		assert(5 == value);
		value = 0;
		assert(NoMatch == p("asc", space));
		assert(8 == p(" 	\r\n	234", space));
		assert(5 == value);
	}
}

class CharParser: Parser
{
	char value;
	this (char v)
	{
		value = v;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res = (0 == s.length || s[0] != value)? NoMatch : 1;
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	unittest
	{
		scope t = new Test!CharParser();
		auto p = char_('A');
		assert(1 == p("ABCDE", space));
		assert(NoMatch == p("BCDE", space));
		assert(NoMatch == p("", space));
		assert(1 == p("A"));
		assert(2 == p("	A", space));
	}
}

class EndParser: Parser
{
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res = (0 == s.length)? 0 : NoMatch;
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	unittest
	{
		scope t = new Test!EndParser();
		assert(0 == end(""));
		assert(NoMatch == end("A"));
		assert(4 == end("  	 ", space));
	}
}

class StrParser: Parser
{
	string value;
	this (string v)
	{
		value = v;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res = (s.length < value.length || s[0 .. value.length] != value)
			? NoMatch
			: cast(MatchLen)value.length;
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	unittest
	{
		scope t = new Test!StrParser();
		auto p = string_("CDE");
		assert(3 == p("CDEFGH", space));
		assert(NoMatch == p("CDFG", space));
		assert(NoMatch == p("", space));
		assert(7 == p("	 \r\nCDE", space));
	}
}

class SequenceParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res;
		foreach (p; parsers)
		{
			auto res2 = p(s[res .. $]);
			if (NoMatch == res2)
				return NoMatch;
			res += res2;
		}
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	SequenceParser opShr (SequenceParser parser) { return new SequenceParser(parsers ~ parser.parsers); }
	SequenceParser opShr (Parser parser) { return new SequenceParser(parsers ~ parser); }
	SequenceParser opShr (char c) { return new SequenceParser(parsers ~ [new CharParser(c)]); }
	unittest
	{
		scope t = new Test!SequenceParser();
		auto p = char_('A') >> 'B' >> 'C' >> 'D';
		assert(4 == p("ABCDE", space));
		assert(NoMatch == p("BCDE", space));
		assert(NoMatch == p("", space));
		assert(4 == p("ABCD", space));
		assert(8 == p("	 \r	ABCD", space));
	}
}

class RepeatParser: UnaryParser
{
	public:
		uint from, to;
		this (Parser parser, uint from)
		{
			this.parser = parser;
			this.from = from;
			to = to.max;
		}
		this (Parser parser, uint from, uint to)
		{
			this.parser = parser;
			this.from = from;
			if (to > 0)
				this.to = to;
			else
				this.to = to.max;
		}
		MatchLen match (string s, Parser skipParser = null)
		{
			MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
			if (NoMatch != skipRes)
				s = s[skipRes .. $];
			uint counter;
			MatchLen res;
			while (counter < to)
			{
				MatchLen res2 = parser(s[res .. $]);
				if (NoMatch == res2)
					break;
				++counter;
				res += res2;
			}
			if (counter < from)
				return NoMatch;
			return (NoMatch == res)
				? NoMatch
				: ((NoMatch == skipRes)
					? res
					: res + skipRes
				);
		}
		
	unittest
	{
		scope t = new Test!RepeatParser();
		auto p = char_('Z')[3..5];
		assert(NoMatch == p("", space));
		assert(NoMatch == p("ZZ", space));
		assert(3 == p("ZZZ", space));
		assert(4 == p("ZZZZ"));
		assert(5 == p("ZZZZZ"));
		assert(5 == p("ZZZZZZ", space));
		assert(9 == p("	   ZZZZZZ", space));
		auto sp = char_('A') >> 'B' >> 'C' >> 'D';
		auto p2 = sp[0..2];
		assert(0 == p2("", space));
		assert(0 == p2("ABECDABCDEFGH", space));
		assert(4 == p2("ABCDABC", space));
		assert(8 == p2("ABCDABCDEFGH", space));
		assert(8 == p2("ABCDABCDABCDEFGH", space));
		assert(10 == p2("	\rABCDABCDABCDEFGH", space));
		auto p3 = *char_('X');
		assert(0 == p3("YXZ", space));
		assert(1 == p3("X", space));
		assert(1 == p3("XYZ", space));
		assert(3 == p3("XXXYZ", space));
		assert(5 == p3("XXXXX", space));
		assert(10 == p3("		\r\n\nXXXXX", space));
	}
}

class AndParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res;
		foreach (p; parsers)
		{
			auto res2 = p(s);
			if (NoMatch == res2)
				return NoMatch;
			if (res2 > res)
				res = res2;
		}
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	unittest
	{
		scope t = new Test!AndParser();
		auto p = char_('A') + string_("ABC");
		assert(NoMatch == p("", space));
		assert(NoMatch == p("A", space));
		assert(3 == p("ABC", space));
		assert(3 == p("ABCDE", space));
		assert(6 == p("\v\r\nABCDE", space));
		auto p2 = string_("ABC") - string_("ABCDE");
		assert(NoMatch == p2("", space));
		assert(3 == p2("ABC", space));
		assert(3 == p2("ABCD", space));
		assert(4 == p2("\rABCD", space));
		assert(NoMatch == p2("ABCDE", space));
		assert(NoMatch == p2("ABCDEF", space));
		assert(NoMatch == p2("\r\nABCDEF", space));
	}
}

class OrParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res = NoMatch;
		foreach (p; parsers)
		{
			auto res2 = p(s);
			if (NoMatch != res2)
			{
				res = res2;
				break;
			}
		}
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	unittest
	{
		scope t = new Test!OrParser();
		auto p = string_("ABC") | string_("DEF");
		assert(NoMatch == p("\r\n", space));
		assert(3 == p("ABC", space));
		assert(3 == p("DEF", space));
		assert(5 == p("\r\nDEF", space));
		assert(NoMatch == p("BCDEF", space));
	}
}

class NotParser: UnaryParser
{
	this (Parser parser)
	{
		this.parser = parser;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res = (NoMatch == parser(s))? (s.length > 0? 1 : 0) : NoMatch;
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
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
		assert(0 == p("", space));
		assert(1 == p("A", space));
		assert(3 == p("\r A", space));
		assert(NoMatch == p("ABC", space));
		assert(NoMatch == p("ABCDE", space));
	}
}

class RangeParser: Parser
{
	uint start, end;
	this (uint start, uint end)
	{
		this.start = start;
		this.end = end;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		MatchLen skipRes = (skipParser is null)? NoMatch : matchSkipParser(s, skipParser);
		if (NoMatch != skipRes)
			s = s[skipRes .. $];
		MatchLen res = (s.length && s[0] >= start && s[0] <= end)? 1 : NoMatch;
		return (NoMatch == res)
			? NoMatch
			: ((NoMatch == skipRes)
				? res
				: res + skipRes
			);
	}
	unittest
	{
		scope t = new Test!RangeParser();
		auto p = range('A', 'C');
		assert(NoMatch == p("  ", space));
		assert(1 == p("AB", space));
		assert(1 == p("BCDEF", space));
		assert(1 == p("C", space));
		assert(3 == p("\r\nC", space));
		assert(NoMatch == p("DEF", space));
	}
}

abstract class ContextParser: UnaryParser
{
	ContextParser* opAssign (Parser parser)
	{
		this.parser = parser;
		return &this;
	}
	MatchLen match (string s, Parser skipParser = null)
	{
		if (!parser)
			return NoMatch;
		return parser.match(s, skipParser);
	}
}

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

CharParser char_ (char ch)
{
	return new CharParser(ch);
}

SequenceParser sequence (Parser[] parsers)
{
	return new SequenceParser(parsers);
}

StrParser string_ (string str)
{
	return new StrParser(str);
}

RangeParser range (uint start, uint end)
{
	return new RangeParser(start, end);
}

static EndParser end = void;
static Parser alpha = void, alnum = void, digit = void, eol = void,
	anychar = void, int_ = void, uint_ = void, double_ = void, space = void;

static this ()
{
	alpha = range('a', 'z') | range('A', 'Z');
	digit = range('0', '9');
	alnum = alpha | digit;
	anychar = range(0, 255);
	end = new EndParser();
	eol = ('\n' >> ~char_('\r')) | ('\r' >> ~char_('\n'));
	auto e = (char_('e') | 'E') >> ~(char_('+') | '-') >> +digit;
	uint_ = ~char_('+') >> +digit;
	int_ = ~(char_('+') | '-') >> +digit;
	double_ = ~(char_('+') | '-') >> ((~(+digit) >> ('.' >> +digit)) | +digit) >> ~e;
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

unittest
{
	new Test!alpha(
	{
		assert(1 == alpha("b", space));
		assert(1 == alpha("D", space));
		assert(3 == alpha("  D", space));
		assert(NoMatch == alpha("0", space));
		assert(NoMatch == alpha("\r\n", space));
	});
	new Test!digit(
	{
		assert(1 == digit("8"));
		assert(1 == digit("2"));
		assert(NoMatch == digit("h"));
		assert(NoMatch == digit(""));
	});
	new Test!alnum(
	{
		assert(1 == alnum("8"));
		assert(1 == alnum("y"));
		assert(NoMatch == alnum("$"));
		assert(NoMatch == alnum(""));
	});
	new Test!anychar(
	{
		assert(1 == anychar("8"));
		assert(1 == anychar("y"));
		assert(1 == anychar("$"));
		assert(NoMatch == anychar(""));
	});
	new Test!eol(
	{
		assert(2 == eol("\r\n"));
		assert(1 == eol("\n"));
		assert(1 == eol("\r"));
		assert(2 == eol("\n\r"));
		assert(NoMatch == eol("g"));
		assert(NoMatch == eol(""));
	});
	new Test!uint_(
	{
		assert(8 == uint_((78_245_235).stringof));
		assert(1 == uint_((0).stringof));
		assert(NoMatch == uint_((-45_235_901).stringof));
		assert(NoMatch == uint_("g"));
		assert(NoMatch == uint_(""));
	});
	new Test!int_(
	{
		assert(9 == int_((-78_245_235).stringof));
		assert(1 == int_((0).stringof));
		assert(8 == int_((45_235_901).stringof));
		assert(NoMatch == int_("g"));
		assert(NoMatch == int_(""));
	});
	new Test!double_(
	{
		assert(14 == double_("-78245.5294e42"));
		assert(7 == double_("0.00001"));
		assert(3 == double_("546"));
		assert(7 == double_(".05e-24"));
		assert(NoMatch == double_("ebcd"));
		assert(NoMatch == double_(""));
	});
	new Test!(ActionParser!char, "!char")(
	{
		char ch;
		void setChar (char c)
		{
			ch = c;
		}
		auto p = char_('&')[&setChar];
		assert(NoMatch == p("F"));
		assert(char.init == ch);
		assert(1 == p("&saff"));
		assert('&' == ch);
	});
	new Test!(ActionParser!string, "!string")(
	{
		string value;
		void setValue (string s)
		{
			value = s;
		}
		auto p = string_("ABcd")[&setValue];
		assert(NoMatch == p("ABCD"));
		assert("" == value);
		assert(4 == p("ABcdEF"));
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
		assert(NoMatch == p("ABCD"));
		assert(uint.init == value);
		assert(4 == p("2432"));
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
		assert(NoMatch == p("ABCD"));
		assert(int.init == value);
		assert(5 == p("-2432"));
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
		assert(NoMatch == p("ABCD"));
		assert(11 == p("-2432.54e-2"));
		assert((value - -2432.54e-2) < 0.01);
	});
}
