module parser;

import std.stdio, std.stdarg, std.conv, qc;
debug import std.string;

debug
{
	class Debugger (T = invariant(char))
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
private enum MatchLen NoMatch = MatchLen.max;

abstract class Parser
{
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
	auto parse (string s)
	{
		/+//debug performBeforeActions(stream);
		auto result = match(s);
		//debug performAfterActions(stream, result);
		if (result >= 0)
			performSuccessActions(s, result);
		return result;+/
		return match(s);
	}
	auto opCall (string s) { return parse(s); }
	Parser opNeg () { return new NotParser(this); }
	auto opAdd (Parser p) { return new AndParser([this, p]); }
	auto opSlice (uint from = 0, uint to = 0) { return new RepeatParser(this, from, to); }
	auto opStar () { return new RepeatParser(this, 0, 0); }
	auto opCom () { return new RepeatParser(this, 0, 1); }
	auto opPos () { return new RepeatParser(this, 1, 0); }
	SequenceParser opShr (Parser p) { return new SequenceParser([this, p]); }
	SequenceParser opShr (char ch) { return new SequenceParser([this, new CharParser(ch)]); }
	SequenceParser opShr_r (char ch) { return new SequenceParser([cast(Parser)new CharParser(ch), this]); }
	auto opSub (Parser p) { return new AndParser([this, -p]); }
	auto opOr (Parser p) { return new OrParser([this, p]); }
	auto opOr (char ch) { return new OrParser([this, new CharParser(ch)]); }
	Parser opIndex (void function (string) act) { return new StrActionParser!(void function (string))(this, act); }
	Parser opIndex (void delegate (string) act) { return new StrActionParser!(void delegate (string))(this, act); }
	Parser opIndex (void function () act) { return new EmptyActionParser!(void function ())(this, act); }
	Parser opIndex (void delegate () act) { return new EmptyActionParser!(void delegate ())(this, act); }
	/+abstract Parser performSuccessActions(string, int);+/
	abstract MatchLen match (string);
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
	MatchLen match (string s)
	{
		return parser(s);
	}
	ActionParser!(T) opIndex (T action)
	{
		this.action = action;
		return this;
	}
}

class EmptyActionParser (T): ActionParser!(T)
{
	
	this (Parser parser, T action)
	{
		super(parser, action); 
	}
	/+Parser performSuccessActions (string s, int result)
	{
		action();
		return this;
	}+/
}

class CharActionParser (T): ActionParser!(T)
{
	this (Parser parser, T action)
	{
		super(parser, action);
	}
	Parser performSuccessActions (string s, int result)
	{
		action(s[0]);
		return this;
	}
}

class StrActionParser (T): ActionParser!(T)
{
	this (Parser parser, T action)
	{
		super(parser, action);
	}
	Parser performSuccessActions (string s, int result)
	{
		action(s[0 .. result]);
		return this;
	}
}

class UintActionParser (T): ActionParser!(T)
{
	this (Parser parser, T action)
	{
		super(parser, action);
	}
	Parser performSuccessActions (string s, int result)
	{
		action(to!(uint)(s[0 .. result]));
		return this;
	}
}

class CharParser: Parser
{
	char value;
	this (char v)
	{
		value = v;
	}
	MatchLen match (string s)
	{
		if (0 == s.length || s[0] != value)
			return NoMatch;
		return 1;
	}
	auto opIndex (void function (char) action) { return new CharActionParser!(void function (char))(this, action); }
	auto opIndex (void delegate (char) action) { return new CharActionParser!(void delegate (char))(this, action); }
	unittest
	{
		scope t = new Test!CharParser();
		auto p = char_('A');
		assert(1 == p("ABCDE"));
		assert(NoMatch == p("BCDE"));
		assert(NoMatch == p(""));
		assert(1 == p("A"));
	}
}

class EndParser: Parser
{
	MatchLen match (string s)
	{
		return (0 == s.length)? 0 : NoMatch;
	}
	Parser opIndex (void function () act) { return new EmptyActionParser!(void function ())(this, act); }
	Parser opIndex (void delegate () act) { return new EmptyActionParser!(void delegate ())(this, act); }
}

class StrParser: Parser
{
	string value;
	this (string v)
	{
		value = v;
	}
	MatchLen match (string s)
	{
		if (s.length < value.length || s[0 .. value.length] != value)
			return NoMatch;
		return cast(MatchLen)value.length;
	}
}

class SequenceParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	MatchLen match (string s)
	{
		MatchLen i;
		foreach (p; parsers)
		{
			auto res = p(s[i .. $]);
			if(NoMatch == res)
				return NoMatch;
			i += res;
		}
		return i;
	}
	SequenceParser opShr (SequenceParser parser) { return new SequenceParser(parsers ~ parser.parsers); }
	SequenceParser opShr (Parser parser) { return new SequenceParser(parsers ~ parser); }
	SequenceParser opShr (char c) { return new SequenceParser(parsers ~ [new CharParser(c)]); }
	unittest
	{
		scope t = new Test!SequenceParser();
		auto p = char_('A') >> 'B' >> 'C' >> 'D';
		assert(4 == p("ABCDE"));
		assert(NoMatch == p("BCDE"));
		assert(NoMatch == p(""));
		assert(4 == p("ABCD"));
	}
}

class RepeatParser: UnaryParser
{
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
	MatchLen match (string s)
	{
		uint counter;
		MatchLen i, res;
		while (counter < to && (res = parser(s[i .. $])) > 0)
		{
			++counter;
			i += res;
		}
		if (counter < from)
			return NoMatch;
		return i;
	}
}

class AndParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	MatchLen match (string s)
	{
		MatchLen max;
		foreach (p; parsers)
		{
			auto res = p(s);
			if (-1 == res)
				return NoMatch;
			if (res > max)
				max = res;
		}
		return max;
	}
}

class OrParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	MatchLen match (string s)
	{
		foreach (p; parsers)
		{
			auto res = p(s);
			if (res >= 0)
				return res;
		}
		return NoMatch;
	}
}

class NotParser: UnaryParser
{
	this (Parser parser)
	{
		this.parser = parser;
	}
	MatchLen match (string s)
	{
		return (NoMatch == parser(s))? (s.length > 0? 1 : 0) : NoMatch;
	}
	Parser opNeg ()
	{
		return parser;
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
	MatchLen match (string s)
	{
		return (s.length && s[0] >= start && s[0] <= end)? 1 : NoMatch;
	}
}

abstract class ContextParser: UnaryParser
{
	ContextParser* opAssign (Parser parser)
	{
		this.parser = parser;
		return &this;
	}
	MatchLen match (string s)
	{
		if (!parser)
			return NoMatch;
		return parser.match(s);
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
		hit = result >= 0;
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

void delegate (T[]) appendTo (T) (ref T v)
{
	void res (T[] arg1) { v.length = v.length + 1; v[$ - 1] = arg1; }
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

SequenceParser sequence_ (Parser[] parsers)
{
	return new SequenceParser(parsers);
}

StrParser string_ (string str)
{
	return new StrParser(str);
}

RangeParser range_ (uint start, uint end)
{
	return new RangeParser(start, end);
}

static EndParser end_;
static Parser alpha_ = void, alnum_ = void, digit_ = void, eol_ = void,
	anychar_ = void, int_ = void, uint_ = void, double_ = void;

static this ()
{
	alpha_ = range_('a', 'z') | range_('A', 'Z');
	digit_ = range_('0', '9');
	alnum_ = alpha_ | digit_;
	anychar_ = range_(0, 255);
	eol_ = ('\n' >> ~char_('\r')) | ('\r' >> ~char_('\n'));
	auto e_ = (char_('e') | 'E') >> ~(char_('+') | '-') >> +digit_;
	uint_ = ~char_('+') >> +digit_ >> ~e_; 
	int_ = ~(char_('+') | '-') >> +digit_ >> ~e_;
	double_ = ~(char_('+') | '-') >> ((~(+digit_) >> ('.' >> +digit_)) | +digit_) >> ~e_;
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
	// CharParser
	
	// SequenceParser
	
	// StrParser
	/+
	auto str = string_("CDE");
	assert(3 == str("CDEFGH"));
	assert(NoMatch == str("CDFG"));
	assert(NoMatch == str(""));
	// EndParser
	assert(0 == end_(""));
	assert(NoMatch == end_("A"));
	// RepeatParser
	auto rep = char_('Z')[3..5];
	assert(NoMatch == rep(""));
	assert(NoMatch == rep("ZZ"));
	assert(3 == rep("ZZZ"));
	assert(4 == rep("ZZZZ"));
	assert(5 == rep("ZZZZZ"));
	assert(5 == rep("ZZZZZZ"));
	
	auto rep2 = seq[0..2];
	assert(0 == rep2(""));
	assert(0 == rep2("ABECDABCDEFGH"));
	assert(4 == rep2("ABCDABC"));
	assert(8 == rep2("ABCDABCDEFGH"));
	assert(8 == rep2("ABCDABCDABCDEFGH"));
	
	auto rep3 = *char_('X');
	assert(0 == rep3("YXZ"));
	assert(1 == rep3("X"));
	assert(1 == rep3("XYZ"));
	assert(3 == rep3("XXXYZ"));
	assert(5 == rep3("XXXXX"));
	// AndParser
	auto andP = char_('A') + string_("ABC");
	assert(NoMatch == andP(""));
	assert(NoMatch == andP("A"));
	assert(3 == andP("ABC"));
	assert(3 == andP("ABCDE"));
	// NotParser
	auto notP = -andP;
	assert(-notP is andP);
	assert(0 == notP(""));
	assert(1 == notP("A"));
	assert(NoMatch == notP("ABC"));
	assert(NoMatch == notP("ABCDE"));
	// AndNotParser
	auto andNot = string_("ABC") - string_("ABCDE");
	assert(NoMatch == andNot(""));
	assert(3 == andNot("ABC"));
	assert(3 == andNot("ABCD"));
	assert(NoMatch == andNot("ABCDE"));
	assert(NoMatch == andNot("ABCDEF"));
	// OrParser
	auto orP = string_("ABC") | string_("DEF");
	debug traceParser(orP, "orP");
	assert(NoMatch == orP(""));
	assert(3 == orP("ABC"));
	assert(3 == orP("DEF"));
	assert(NoMatch == orP("BCDEF"));
	// RangeParser
	auto range = range_('A', 'C');
	debug traceParser(range, "range");
	assert(NoMatch == range(""));
	assert(1 == range("AB"));
	assert(1 == range("BCDEF"));
	assert(1 == range("C"));
	assert(NoMatch == range("DEF"));+/
}
