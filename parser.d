/**
 * Parsers (based on $(WEB boost.org, Boost::Spirit))
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2009 - 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module parser;

debug = parser;

import std.conv, std.array, std.variant;
version(unittest) import qc;
debug(parser) import std.string, std.stdio;

/++
 + Action
 +/

abstract class Action
{
	abstract Action opCall (string s);
}

/++
 + VoidAction
 + Action without arguments
 +/

class VoidAction: Action
{
	protected:
		void delegate () actor;

	public:
		this (void delegate () actor)
		{
			this.actor = actor;
		}
		Action opCall (string s)
		{
			actor();
			return this;
		}

	unittest
	{
		uint u;
		void test1 ()
		{
			u = 5;
		}
		auto act = new VoidAction(&test1);
		act("");
		assert(5 == u);
	}
}

template delegateFirstArg (Type)
{
	static if (is(Type == void delegate (char)))
		alias char delegateFirstArg;
	else static if (is(Type == void delegate (byte)))
		alias byte delegateFirstArg;
	else static if (is(Type == void delegate (ubyte)))
		alias ubyte delegateFirstArg;
	else static if (is(Type == void delegate (short)))
		alias short delegateFirstArg;
	else static if (is(Type == void delegate (ushort)))
		alias ushort delegateFirstArg;
	else static if (is(Type == void delegate (int)))
		alias int delegateFirstArg;
	else static if (is(Type == void delegate (uint)))
		alias uint delegateFirstArg;
	else static if (is(Type == void delegate (long)))
		alias long delegateFirstArg;
	else static if (is(Type == void delegate (ulong)))
		alias ulong delegateFirstArg;
	else static if (is(Type == void delegate (float)))
		alias float delegateFirstArg;
	else static if (is(Type == void delegate (double)))
		alias double delegateFirstArg;
	else static if (is(Type == void delegate (string)))
		alias string delegateFirstArg;
	else static assert(0, "not implemented");
}

/++
 + TypedAction
 + Action with one typed argument
 +/

class TypedAction (ActType): Action
{
	protected:
		ActType actor;

	public:
		this (ActType actor)
		{
			this.actor = actor;
		}
		Action opCall (string s)
		{
			static if (is(ActType == void delegate ()))
				actor();
			else static if (is(ActType == void delegate (char)))
				actor(s[0]);
			else static if (is(ActType == void delegate (string)))
				actor(s);
			else
			{
				alias delegateFirstArg!(ActType) ArgType;
				actor(to!(ArgType)(s));
			}
			return this;
		}
}

unittest
{
	uint u;
	void test1 (uint i)
	{
		u = i;
	}
	auto act = new TypedAction!(void delegate (uint))(&test1);
	act("25");
	assert(25 == u);
}


/++
 + Parser
 +/

abstract class Parser
{
	public:
		// Parse
		bool opCall (ref string s, Parser skipper = null)
		{
			return parse(s, skipper);
		}
		bool opCall (ref string s, Action[] actions, Parser skipper = null)
		{
			return parse(s, actions, skipper);
		}
		bool opCall (ref string s, out Variant v, Parser skipper = null)
		{
			return parse(s, v, skipper);
		}
		bool opCall (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		{
			return parse(s, v, actions, skipper);
		}
		// Negative parser (-p)
		Parser opNeg () { return new NotParser(this); }
		// And parser (p + p)
		AndParser opAdd (Parser p) { return new AndParser([this, p]); }
		AndParser opAdd (Parser* p) { return this + lazy_(p); }
		// Repeat parser (p[n..m])
		RepeatParser opSlice (uint from, uint to = 0) { return new RepeatParser(this, from, to); }
		// Repeat any parser (*p)
		RepeatParser opStar () { return this[0..0]; }
		// Repeat one or none parser (~p)
		RepeatParser opCom () { return this[0..1]; }
		// Repeat one or more parser (+p)
		RepeatParser opPos () { return this[1..0]; }
		// Sequence parser (p >> p)
		SequenceParser opShr (Parser p) { return new SequenceParser([this, p]); }
		SequenceParser opShr (Parser* p) { return this >> lazy_(p); }
		SequenceParser opShr (char ch) { return this >> char_(ch); }
		SequenceParser opShr (string str) { return this >> string_(str); }
		SequenceParser opShr_r (char ch) { return char_(ch) >> this; }
		SequenceParser opShr_r (string str) { return string_(str) >> this; }
		SequenceParser opShr_r (Parser* p) { return lazy_(p) >> this; }
		// First but not second parser (p - p)
		AndParser opSub (Parser p) { return this + -p; }
		AndParser opSub (Parser* p) { return this + -lazy_(p); }
		// Or parser (p | p)
		OrParser opOr (Parser p) { return new OrParser([this, p]); }
		OrParser opOr (Parser* p) { return this | lazy_(p); }
		OrParser opOr (char ch) { return this | char_(ch); }
		OrParser opOr (string str) { return this | string_(str); }
		// Separated by parser (p % p)
		SequenceParser opMod (char ch) { return this % char_(ch); }
		SequenceParser opMod (string str) { return this % string_(str); }
		SequenceParser opMod (Parser p) { return this >> *(p >> this); };
		SequenceParser opMod (Parser* p) { return this >> *(lazy_(p) >> this); };
		// Add an action to parse
		ActionParser opIndex (ActType) (ActType act)
		{
			static if (is(ActType : Action))
				return new ActionParser(this, act);
			else
				return new ActionParser(this, new TypedAction!(ActType)(act));
			assert(0);
		}
		// Try to parse
		abstract bool match (ref string s, Parser skipper = null);
		abstract bool match (ref string s, out Variant v, Parser skipper = null);
		// Execute parser actions
		Parser skipBy (ref string s, Parser skipper)
		{
			if (skipper !is null)
				while(skipper(s)) {}
			return this;
		}
		Parser doActions (string s, Action[] actions)
		{
			foreach (action; actions)
				action(s);
			return this;
		}
		// Parse and execute actions on success
		bool parse (ref string s, Action[] actions, Parser skipper = null)
		{
			debug(parser) doBeforeActions(s);
			auto fs = s;
			if (!match(s, skipper))
			{
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			if (actions && !actions.empty)
				doActions(fs[0 .. $ - s.length], actions);
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, Parser skipper = null)
		{
			return parse(s, null, skipper);
		}
		bool parse (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		{
			debug(parser) doBeforeActions(s);
			auto fs = s;
			if (!match(s, v, skipper))
			{
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			if (actions && !actions.empty)
				doActions(fs[0 .. $ - s.length], actions);
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			return parse(s, v, null, skipper);
		}

	debug(parser):
		protected:
			void function (Parser, string)[] beforeActions;
			void function (Parser, string, bool)[] afterActions;
			string name;
			static void writeBeginTrace (Parser p, string s)
			{
				writefln("%srule (%s) \"%s\"", repeat("  ", p.depth), p.name, s[0 .. ($ > 10)? 10 : $]);
				++p.depth;
			}
			static void writeEndTrace (Parser p, string s, bool result)
			{
				--p.depth;
				writefln("%s%srule (%s) \"%s\"", repeat("  ", p.depth), result? "/" : "#", p.name, s[0 .. ($ > 10)? 10 : $]);
			}
			Parser doBeforeActions (string s)
			{
				foreach (action; beforeActions)
					action(this, s);
				return this;
			}
			Parser doAfterActions (string s, bool result)
			{
				foreach (action; afterActions)
					action(this, s, result);
				return this;
			}
			Parser addBeforeAction (void function (string, string) action)
			{
				beforeActions.length += 1;
				beforeActions[$ - 1] = action;
				return this;
			}
			Parser addAfterAction (void function (string, string, bool) action)
			{
				afterActions.length += 1;
				afterActions[$ - 1] = action;
				return this;
			}
		public:
			static uint depth;
			Parser trace (string name)
			{
				this.name = name;
				addBeforeAction(&writeBeginTrace);
				addAfterAction(&writeEndTrace);
				return this;
			}
}

abstract class UnaryParser: Parser
{
	protected:
		Parser parser;
		
		bool parse (ref string s, Action[] actions, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = parser(s, actions, skipper);
				doAfterActions(s, res);
				return res;
			}
			else
				return parser(s, actions, skipper);
		}
		bool parse (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = parser(s, v, actions, skipper);
				doAfterActions(s, res);
				return res;
			}
			else
				return parser(s, v, actions, skipper);
		}
}

abstract class BinaryParser: Parser
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

abstract class NaryParser: Parser
{
	protected:
		Parser[] parsers;
}

/++
 + ActionParser
 +/

class ActionParser: UnaryParser
{
	public:
		Action action;
		
		this (Parser parser, Action action)
		{
			this.parser = parser;
			this.action = action;
		}
		bool match (ref string s, Parser skipper = null)
		{
			return parser.match(s, skipper);
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			return parser.match(s, v, skipper);
		}
		bool parse (ref string s, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = parser(s, [action], skipper);
				doAfterActions(s, res);
				return res;
			}
			else
			{
				return parser(s, [action], skipper);
			}
		}
		bool parse (ref string s, Action[] actions, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = parser(s, this.action ~ actions, skipper);
				doAfterActions(s, res);
				return res;
			}
			else
			{
				return parser(s, this.action ~ actions, skipper);
			}
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = parser(s, v, [action], skipper);
				doAfterActions(s, res);
				return res;
			}
			else
			{
				return parser(s, v, [action], skipper);
			}
		}
		bool parse (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = parser(s, v, this.action ~ actions, skipper);
				doAfterActions(s, res);
				return res;
			}
			else
			{
				return parser(s, v, this.action ~ actions, skipper);
			}
		}

	unittest
	{
		uint ui;
		void setUi ()
		{
			ui = 6;
		}
		auto p = char_('&')[&setUi];
		auto s = "F";
		assert(!p(s));
		assert(uint.init == ui);
		s = "&saff";
		assert(p(s));
		assert(6 == ui);
		// 2 actions
		ui = 0;
		uint ab;
		void setAb ()
		{
			ab = 20;
		}
		auto p2 = p[&setAb];
		s = "&";
		assert(p(s));
		assert(6 == ui);
		assert(uint.init == ab);
		ui = typeof(ui).init;
		s = "&";
		assert(p2(s));
		assert(6 == ui);
		assert(20 == ab);
	}
	
	unittest
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
	}
	
	unittest
	{
		string value;
		void setValue (string s)
		{
			value = s;
		}
		auto p = string_("ABcd")[&setValue];
		auto s = "ABCD";
		assert(!p(s));
		assert("" == value);
		s = "ABcdEF";
		assert(p(s));
		assert("ABcd" == value);
	}
	
	unittest
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
	}
	
	unittest
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
	}
	
	unittest
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
	}
}

/++
 + PrimitiveParser
 +/

class PrimitiveParser (Type): Parser
{
	public:
		bool match (ref string s, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			try // We should catch parse errors
			{
				std.conv.parse!(Type)(s);
			}
			catch
			{
				return false;
			}
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			try // We should catch parse errors
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
}

unittest
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
}

unittest
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
		bool match (ref string s, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (0 == s.length || s[0] != value)
				return false;
			s = s[1 .. $];
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (0 == s.length || s[0] != value)
				return false;
			v = s[0];
			s = s[1 .. $];
			return true;
		}

	unittest
	{
		auto p = char_('A');
		auto s = "ABCDE";
		assert(1 == p(s));
		s = "BCDE";
		assert(!p(s));
		s = "";
		assert(!p(s));
		s = "A";
		assert(p(s));
		s = "   A";
		assert(p(s, char_(' ')));
	}
}

/++
 + EndParser
 + Matches empty string only.
 +/

class EndParser: Parser
{
	public:
		bool match (ref string s, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (0 != s.length)
				return false;
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (0 != s.length)
				return false;
			return true;
		}

	unittest
	{
		auto s = "";
		assert(end(s));
		s = "A";
		assert(!end(s));
		s = "   ";
		assert(end(s, char_(' ')));
	}
}

/++
 + StrParser
 + Matches string.
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
		bool match (ref string s, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (s.length < value.length || s[0 .. value.length] != value)
				return false;
			s = s[value.length .. $];
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (s.length < value.length || s[0 .. value.length] != value)
				return false;
			v = value;
			s = s[value.length .. $];
			return true;
		}

	unittest
	{
		auto p = string_("CDE");
		auto s = "CDEFGH";
		assert(p(s));
		s = "CDFG";
		assert(!p(s));
		s = "";
		assert(!p(s));
		s = "   CDE";
		assert(p(s, char_(' ')));
	}
}

/++
 + SequenceParser
 + Matches if all parsers in sequence are match.
 +/

class SequenceParser: NaryParser
{
	public:
		this (Parser[] parsers)
		{
			this.parsers = parsers;
		}
		bool match (ref string s, Parser skipper = null)
		{
			foreach (p; parsers)
				if (!p(s, skipper))
					return false;
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			v = new Variant[](parsers.length);
			foreach (i, p; parsers)
				if (!p(s, *v[i].peek!(Variant)(), skipper))
					return false;
			return true;
		}
		SequenceParser opShr (string str) { return new SequenceParser(parsers ~ string_(str)); }
		SequenceParser opShr (SequenceParser parser) { return new SequenceParser(parsers ~ parser.parsers); }
		SequenceParser opShr (Parser parser) { return new SequenceParser(parsers ~ parser); }
		SequenceParser opShr (Parser* parser) { return this >> lazy_(parser); }
		SequenceParser opShr (char c) { return new SequenceParser(parsers ~ [new CharParser(c)]); }

	unittest
	{
		auto p = char_('A') >> 'B' >> 'C' >> 'D';
		auto s = "ABCDE";
		assert(p(s));
		s = "BCDE";
		assert(!p(s));
		s = "";
		assert(!p(s));
		s = "ABCD";
		assert(p(s));
		s = "   ABCD";
		assert(p(s, char_(' ')));
		s = "ABED";
		assert(!p(s));
		assert("ABED" == s);
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
		bool match (ref string s, Parser skipper = null)
		{
			uint counter;
			while (counter < to)
			{
				if (!parser.match(s, skipper))
					break;
				++counter;
			}
			if (counter < from)
				return false;
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			uint counter;
			Variant[] res;
			while (counter < to)
			{
				if (res.length <= counter)
					res.length = res.length * 2 + 1;
				if (!parser.match(s, res[counter], skipper))
					break;
				++counter;
			}
			res.length = counter - 1;
			v = res;
			if (counter < from)
				return false;
			return true;
		}
		bool parse (ref string s, Action[] actions, Parser skipper = null)
		{
			debug(parser) doBeforeActions(s);
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
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			if (actions && !actions.empty)
				doActions(fs[0 .. $ - s.length], actions);
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		{
			debug(parser) doBeforeActions(s);
			auto fs = s;
			uint counter;
			Variant[] res;
			while (counter < to)
			{
				if (res.length <= counter)
					res.length = res.length * 2 + 1;
				if (!parser(s, res[counter], skipper))
					break;
				++counter;
			}
			res.length = counter - 1;
			v = res;
			if (counter < from)
			{
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			if (actions && !actions.empty)
				doActions(fs[0 .. $ - s.length], actions);
			debug(parser) doAfterActions(s, true);
			return true;
		}

	unittest
	{
		auto p = char_('Z')[3..5];
		auto s = "";
		assert(!p(s));
		s = "ZZ";
		assert(!p(s));
		s = "ZZZ";
		assert(p(s));
		s = "ZZZZ";
		assert(p(s));
		s = "ZZZZZ";
		assert(p(s));
		s = "ZZZZZZ";
		assert(p(s));
		s = "   ZZZZZZ";
		assert(p(s, char_(' ')));
		auto sp = char_('A') >> 'B' >> 'C' >> 'D';
		auto p2 = sp[0..2];
		s = "";
		assert(p2(s));
		s = "ABECDABCDEFGH";
		assert(p2(s));
		s = "ABCDABC";
		assert(p2(s));
		s = "ABCDABCDEFGH";
		assert(p2(s));
		s = "ABCDABCDABCDEFGH";
		assert(p2(s));
		s = "   ABCDABCDABCDEFGH";
		assert(p2(s, char_(' ')));
		auto p3 = *char_('X');
		s = "YXZ";
		assert(p3(s));
		s = "X";
		assert(p3(s));
		s = "XYZ";
		assert(p3(s));
		s = "XXXYZ";
		assert(p3(s));
		s = "XXXXX";
		assert(p3(s));
		s = "   XXXXX";
		assert(p3(s, char_(' ')));
		auto p4 = ~(char_('A') >> 'B');
		s = "ABCD";
		assert(p4(s));
		assert("CD" == s);
		assert(p4(s));
		assert("CD" == s);
	}
}

class AndParser: NaryParser
{
	public:
		this (Parser[] parsers)
		{
			this.parsers = parsers;
		}
		bool match (ref string s, Parser skipper = null)
		{
			auto fs = s;
			uint max = 0;
			foreach (p; parsers)
			{
				s = fs;
				if (!p(s, skipper))
					return false;
				auto matchLen = fs.length - s.length; 
				if (matchLen > max)
					max = matchLen;
			}
			s = fs[max .. $];
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			uint max = 0;
			Variant[] res;
			res.length = parsers.length;
			foreach (i, p; parsers)
			{
				s = fs;
				if (!p(s, res[i], skipper))
					return false;
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
		bool match (ref string s, Parser skipper = null)
		{
			foreach (p; parsers)
				if (p(s, skipper))
					return true;
			return false;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			foreach (p; parsers)
				if (p(s, v, skipper))
					return true;
			return false;
		}

	unittest
	{
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

/++
 + NotParser
 +/

class NotParser: UnaryParser
{
	public:
		this (Parser parser)
		{
			this.parser = parser;
		}
		bool match (ref string s, Parser skipper = null)
		{
			if (parser.match(s, skipper))
				return false;
			s = s[$ > 0? 1 : 0 .. $];
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			if (parser.match(s, skipper))
				return false;
			if (s.length)
				v = s[0];
			s = s[$ > 0? 1 : 0 .. $];
			return true;
		}
		bool parse (ref string s, Action[] actions, Parser skipper = null)
		{
			debug(parser) doBeforeActions(s);
			auto fs = s;
			if (parser(s, skipper))
			{
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			s = s[$ > 0? 1 : 0 .. $];
			if (actions && !actions.empty)
				doActions(fs[0 .. $ - s.length], actions);
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		{
			debug(parser) doBeforeActions(s);
			auto fs = s;
			if (parser(s, skipper))
			{
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			if (s.length)
				v = s[0];
			s = s[$ > 0? 1 : 0 .. $];
			if (actions && !actions.empty)
				doActions(fs[0 .. $ - s.length], actions);
			debug(parser) doAfterActions(s, true);
			return true;
		}
		Parser opNeg ()
		{
			return parser;
		}

	unittest
	{
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
		bool match (ref string s, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (!s.length || s[0] < start || s[0] > end)
				return false;
			s = s[1 .. $];
			return true;
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			if (skipper !is null)
				skipBy(s, skipper);
			if (!s.length || s[0] < start || s[0] > end)
				return false;
			v = s[0];
			s = s[1 .. $];
			return true;
		}

	unittest
	{
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
		bool match (ref string s, Parser skipper = null)
		{
			return parser.match(s, skipper);
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			return parser.match(s, v, skipper);
		}
		bool parse (ref string s, Action[] actions, Parser skipper = null)
		in
		{
			assert(parser !is null);
			assert(*parser !is null);
		}
		body
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = (*parser)(s, actions, skipper);
				doAfterActions(s, res);
				return res;
			}
			else
				return (*parser)(s, actions, skipper);
		}
		bool parse (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		in
		{
			assert(parser !is null);
			assert(*parser !is null);
		}
		body
		{
			debug(parser)
			{
				doBeforeActions(s);
				auto res = (*parser)(s, v, actions, skipper);
				doAfterActions(s, res);
				return res;
			}
			else
				return (*parser)(s, v, actions, skipper);
		}

	unittest
	{
		Parser p = char_('A');
		auto p2 = &p >> char_('C');
		auto s = "AC";
		assert(p2(s));
		s = "ABC";
		assert(!p2(s));
		p = char_('A') >> char_('B');
		assert(p2(s));
		auto p3 = string_("aba");
		Parser p4;
		p4 = 'c' >> (p3 | lazy_(&p4)) >> 'c';
		auto p5 = p3 | p4;
		auto s2 = "aba";
		assert(p5(s2));
		auto s3 = "cabac";
		assert(p5(s3));
		auto s4 = "ccabacc";
		assert(p5(s4));
	}
}

LazyParser lazy_ (Parser* p)
{
	return new LazyParser(p);
}

/++
 + ContextParser
 +/

class ContextParser (ContextType): UnaryParser
{
	public:
		ContextType context;
		
		alias UnaryParser.opCall opCall;
		bool opCall (ref string s, ContextType context, Parser skipper = null)
		{
			return parse(s, context, skipper);
		}
		bool opCall (ref string s, ContextType context, Action[] actions, Parser skipper = null)
		{
			return parse(s, context, actions, skipper);
		}
		bool match (ref string s, Parser skipper = null)
		{
			return parser.match(s, skipper);
		}
		bool match (ref string s, out Variant v, Parser skipper = null)
		{
			return parser.match(s, v, skipper);
		}
		bool parse (ref string s, Parser skipper = null)
		{
			return parse(s, cast(Action[])null, skipper);
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			return parse(s, v, null, skipper);
		}
		bool parse (ref string s, Action[] actions, Parser skipper = null)
		{
			auto oldContext = context;
			scope(exit)
				if (oldContext)
					context = oldContext;
			return parse(s, new ContextType, actions, skipper);
		}
		bool parse (ref string s, out Variant v, Action[] actions, Parser skipper = null)
		{
			auto oldContext = context;
			scope(exit)
				if (oldContext)
					context = oldContext;
			return parse(s, new ContextType, actions, skipper);
		}
		bool parse (ref string s, ContextType context, Parser skipper = null)
		{
			return parse(s, context, null, skipper);
		}
		bool parse (ref string s, ContextType context, Action[] actions, Parser skipper = null)
		{
			this.context = context;
			return super.parse(s, actions, skipper);
		}
		void reset ()
		{
			context = cast(ContextType)null;
		}
}

version(unittest)
{
	class StmtContext
	{
		alias value this;
		int value;
	}
	class StmtParser: ContextParser!StmtContext
	{
		this (ExprParser* expr)
		{
			parser
				= uint_[(uint val){ context = val; }]
				| ('(' >> lazy_(expr)[{ context = expr.context; }] >> ')')
				;
		}
	}
	class ExprContext
	{
		alias value this;
		int value;
	}
	class ExprParser: ContextParser!ExprContext
	{
		this (StmtParser stmt)
		{
			parser
				= stmt[{ context = stmt.context; }]
				>> *(
					'+'
					>> stmt[{ context += stmt.context; }]
				)
				;
		}
	}
}

unittest
{
	StmtParser stmt;
	ExprParser expr;
	stmt = new StmtParser(&expr);
	expr = new ExprParser(stmt);
	auto context = new ExprContext;
	auto s = "1+(3+1)+4+2";
	assert(expr(s, context));
	assert(context.value == 11);
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

static EndParser end;
static Parser alpha, alnum, digit, eol, anychar, space, byte_, ubyte_,
	short_, ushort_, int_, uint_, long_, ulong_, float_, double_;

static this ()
{
	alpha = range('a', 'z') | range('A', 'Z');
	digit = range('0', '9');
	alnum = alpha | digit;
	anychar = range(0, 255);
	end = new EndParser;
	eol = char_('\n') | ('\r' >> ~char_('\n'));
	auto e = (char_('e') | 'E') >> ~(char_('+') | '-') >> +digit;
	byte_ = new PrimitiveParser!byte;
	ubyte_ = new PrimitiveParser!ubyte;
	short_ = new PrimitiveParser!short;
	ushort_ = new PrimitiveParser!ushort;
	int_ = new PrimitiveParser!int;
	uint_ = new PrimitiveParser!uint;
	long_ = new PrimitiveParser!long;
	ulong_ = new PrimitiveParser!ulong;
	float_ = new PrimitiveParser!float;
	double_ = new PrimitiveParser!double;
	space = char_(' ') | '\t' | '\v' | eol;
}

/++
 + Unittest
 +/

version(unittest)
{
	class TestContext
	{
		string val;
	}
	class TestContextParser: ContextParser!(TestContext)
	{
		this ()
		{
			auto rep = +anychar;
			parser
				= rep[(string s){ context.val = s; }]
				;
			assert((cast(ActionParser)parser).parser is rep);
			assert((cast(RepeatParser)(cast(ActionParser)parser).parser).parser is anychar);
		}
	}
}

unittest
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
}

unittest
{
	auto s = "8";
	assert(digit(s));
	s = "2";
	assert(digit(s));
	s = "h";
	assert(!digit(s));
	s = "";
	assert(!digit(s));
}

unittest
{
	auto s = "8";
	assert(alnum(s));
	s = "y";
	assert(alnum(s));
	s = "$";
	assert(!alnum(s));
	s = "";
	assert(!alnum(s));
}

unittest
{
	auto s = "8";
	assert(anychar(s));
	s = "y";
	assert(anychar(s));
	s = "$";
	assert(anychar(s));
	s = "";
	assert(!anychar(s));
}

unittest
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
}

unittest
{	// Complex parser
	uint a, b;
	void setA ()
	{
		assert(0 == b);
		a += 20;
	}
	void setB ()
	{
		assert(60 == a);
		b = 30;
	}
	auto ch = char_('a');
	auto chact = ch[&setA];
	auto rep = +chact;
	auto p = rep[&setB];
	assert((cast(ActionParser)p).parser is rep);
	assert((cast(RepeatParser)(cast(ActionParser)p).parser).parser is chact);
	assert((cast(ActionParser)(cast(RepeatParser)(cast(ActionParser)p).parser).parser).parser is ch);
	auto s = "aaa";
	assert(p(s));
}

unittest
{	// Complex parser 2
	uint a, b;
	void setA ()
	{
		assert(0 == b);
		a += 20;
	}
	void setB ()
	{
		assert(60 == a);
		b = 30;
	}
	Parser p2;
	auto p = (+(lazy_(&p2)[&setA]))[&setB];
	p2 = char_('a');
	auto s = "aaa";
	assert(p(s));
}

unittest
{	// Complex parser 3
	auto p = new TestContextParser;
	auto s = "abcdef";
	auto c = new TestContext;
	assert(p(s, c));
	assert("abcdef" == c.val);
	
}
