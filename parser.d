module parser;

import std.stdio, std.stdarg, std.conv;
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
	abstract int match (string stream);
	abstract Parser performSuccessActions(string, int);
	auto parse (string s)
	{
		//debug performBeforeActions(stream);
		auto result = match(s);
		//debug performAfterActions(stream, result);
		if (result >= 0)
			performSuccessActions(s, result);
		return result;
	}
	auto opCall (string stream) { return parse(s); }
	auto opNeg () { return new NotParser(this); }
	auto opAdd (Parser p) { return new AndParser([this, p]); }
	auto opSlice (uint from = 0, uint to = 0) { return new RepeatParser(this, from, to); }
	auto opStar () { return new RepeatParser(this, 0, 0); }
	auto opCom () { return new RepeatParser(this, 0, 1); }
	auto opPos () { return new RepeatParser(this, 1, 0); }
	auto opShr (Parser p) { return new SequenceParser([this, p]); }
	auto opShr (char ch) { return new SequenceParser([this, new CharParser(ch)]); }
	auto opShr_r (char ch) { return new SequenceParser([cast(Parser)new CharParser(ch), this]); }
	auto opSub (Parser p) { return new AndParser([this, -p]); }
	auto opOr (Parser p) { return new OrParser([this, p]); }
	auto opOr (char ch) { return new OrParser([this, new CharParser(ch)]); }
	auto opIndex (void function (string) act) { return new StrActionParser(this, act); }
	auto opIndex (void delegate (string) act) { return new StrActionParser(this, act); }
	auto opIndex (void function () act) { return new EmptyActionParser(this, act); }
	auto opIndex (void delegate () act) { return new EmptyActionParser(this, act); }
}

abstract class UnaryParser: Parser
{
	Parser parser;
}

abstract class ComposeParser: Parser
{
	Parser[] parsers;
}

abstract class ActionParser (T): UnaryParser
{
	T action;
	this (Parser parser, T action)
	{
		this.parser = parser;
		this.action = action;
	}
	int match (string s)
	{
		return parser(s);
	}
	ActionParser!(T) opIndex (T action)
	{
		this.action = action;
		return this;
	}
}

class EmptyActionParser (T): FunctionActionParser
{
	
	this (Parser parser, T action)
	{
		super(parser, action); 
	}
	Parser performSuccessActions (string s, int result)
	{
		action();
		return this;
	}
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
	this (Parser parser, F action)
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
	this (Parser parser, F action)
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
	int match (string s)
	{
		if (0 == s.length || s[0] != value)
			return -1;
		return 1;
	}
	auto opIndex (void function (char) action) { return new CharActionParser!(this, action); }
	auto opIndex (void delegate (char) action) { return new CharActionParser!(this, action); }
}

class EndParser: Parser
{
	auto match (string s)
	{
		return (0 == s.length)? 0 : -1;
	}
	auto opIndex (void function () action) { return new EmptyActionParser(this, action); }
	auto opIndex (void delegate () action) { return new EmptyActionParser(this, action); }
}

class StrParser: Parser
{
	string value;
	this (string v)
	{
		value = v;
	}
	auto match (string s)
	{
		if (s.length < value.length || s[0..value.length] != value)
			return -1;
		return value.length;
	}
}

class SequenceParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	auto match (string s)
	{
		int i;
		foreach (p; parsers)
		{
			int res = p(s[i..$]);
			if(-1 == res)
				return -1;
			i += res;
		}
		return i;
	}
	auto opShr (SequenceParser parser) { return new SequenceParser(parsers ~ parser.parsers); }
	auto opShr (Parser parser) { return new SequenceParser(parsers ~ parser); }
	auto opShr (char c) { return new SequenceParser(parsers ~ [new CharParser(c)]); }
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
	auto match (string s)
	{
		int counter, i, res;
		while (counter < to && (res = parser(s[i .. $])) > 0)
		{
			++counter;
			i += res;
		}
		if (counter < from)
			return -1;
		return i;
	}
}

class AndParser: ComposeParser
{
	this (Parser[] parsers)
	{
		this.parsers = parsers;
	}
	auto match (string s)
	{
		int max;
		foreach (p; parsers)
		{
			int res = p(s);
			if (-1 == res)
				return -1;
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
	auto match (string s)
	{
		foreach (p; parsers)
		{
			auto res = p(s);
			if (res >= 0)
				return res;
		}
		return -1;
	}
}

class NotParser: UnaryParser
{
	this (Parser parser)
	{
		this.parser = parser;
	}
	auto match (string s)
	{
		return (-1 == parser(s))? (s.length > 0? 1 : 0) : -1;
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
	auto match (string s)
	{
		return (s.length && s[0] >= start && s[0] <= end)? 1 : -1;
	}
}

class UintParser: RepeatParser
{
	this ()
	{
		super(new RangeParser('0', '9'), 1);
	}
	auto opIndex (void function (uint) action)
	{
		return new UintActionParser(this, action);
	}
	auto opIndex (void delegate (uint) action)
	{
		return new UintActionParser(this, action);
	}
	
}

CharParser ch (char ch)
{
	return new CharParser(ch);
}

SequenceParser seq (Parser[] parsers)
{
	return new SequenceParser(parsers);
}

StrParser str (string str)
{
	return new StrParser(str);
}

static EndParser end;
static Parser alpha, alnum, digit, eol, anychar;
static UintParser uint;

RangeParser range (uint start, uint end)
{
	return new RangeParser(start, end);
}

abstract class ContextParser: Parser
{
	Parser parser;
	ContextParser* opAssign (Parser parser)
	{
		this.parser = parser;
		return &this;
	}
	auto match (string s)
	{
		if (!parser)
			return -1;
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
		auto result = p(stream);
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
	void res (T[] arg1) { v.length = v.length+1; v[$-1] = arg1; }
	return &res;
}

void delegate (T) assignTo (T) (ref T v)
{
	void res (T arg1) { v = arg1; }
	return &res;
}

static this ()
{
	end_p = new EndParser!();
	alpha_p = range_p('a', 'z') | range_p('A', 'Z');
	digit_p = range_p('0', '9');
	alnum_p = alpha_p | digit_p;
	anychar_p = range_p(0, 255);
	eol_p = ('\n' >> ch_p('\r')[0..1]) | ('\r' >> ch_p('\n')[0..1]);
	uint_p = new UintParser!();
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
	auto ch = ch_p('A');
	assert(1 == ch("ABCDE"));
	assert(-1 == ch("BCDE"));
	assert(-1 == ch(""));
	assert(1 == ch("A"));
	// SequenceParser
	auto seq = ch_p('A') >> ch_p('B') >> ('C' >> ch_p('D'));
	assert(4 == seq("ABCDE"));
	assert(-1 == seq("BCDE"));
	assert(-1 == seq(""));
	assert(4 == seq("ABCD"));
	// StrParser
	auto str = str_p("CDE");
	assert(3 == str("CDEFGH"));
	assert(-1 == str("CDFG"));
	assert(-1 == str(""));
	// EndParser
	assert(0 == end_p(""));
	assert(-1 == end_p("A"));
	// RepeatParser
	auto rep = ch_p('Z')[3..5];
	assert(-1 == rep(""));
	assert(-1 == rep("ZZ"));
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
	
	auto rep3 = ch_p('X')[0..inf];
	assert(0 == rep3("YXZ"));
	assert(1 == rep3("X"));
	assert(1 == rep3("XYZ"));
	assert(3 == rep3("XXXYZ"));
	assert(5 == rep3("XXXXX"));
	// AndParser
	auto andP = ch_p('A') + str_p("ABC");
	assert(-1 == andP(""));
	assert(-1 == andP("A"));
	assert(3 == andP("ABC"));
	assert(3 == andP("ABCDE"));
	// NotParser
	auto notP = -andP;
	assert(-notP is andP);
	assert(0 == notP(""));
	assert(1 == notP("A"));
	assert(-1 == notP("ABC"));
	assert(-1 == notP("ABCDE"));
	// AndNotParser
	auto andNot = str_p("ABC") - str_p("ABCDE");
	assert(-1 == andNot(""));
	assert(3 == andNot("ABC"));
	assert(3 == andNot("ABCD"));
	assert(-1 == andNot("ABCDE"));
	assert(-1 == andNot("ABCDEF"));
	// OrParser
	auto orP = str_p("ABC") | str_p("DEF");
	debug traceParser(orP, "orP");
	assert(-1 == orP(""));
	assert(3 == orP("ABC"));
	assert(3 == orP("DEF"));
	assert(-1 == orP("BCDEF"));
	// RangeParser
	auto range = range_p('A', 'C');
	debug traceParser(range, "range");
	assert(-1 == range(""));
	assert(1 == range("AB"));
	assert(1 == range("BCDEF"));
	assert(1 == range("C"));
	assert(-1 == range("DEF"));
}
