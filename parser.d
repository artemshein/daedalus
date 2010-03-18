module parser;

debug = parser;

import std.conv, std.array, std.variant;
version(unittest) import qc;
debug(parser) import std.string, std.stdio;

abstract class Action
{
	abstract Action opCall ();
}

class TypedAction (ActionType): Action
{
	protected:
		ActionType actor;
		TypeInfo argumentType;

	public:
		this (ActionType actor)
		{
			this.actor = actor;
			static if (is(ActionType : void function ()) || is(ActionType : void delegate ()))
				argumentType = typeid(void);
			else static if (is(ActionType : void function (char)) || is(ActionType : void delegate (char)))
				argumentType = typeid(char);
			else static if (is(ActionType : void function (string)) || is(ActionType : void delegate (string)))
				argumentType = typeid(string);
			else static if (is(ActionType : void function (byte)) || is(ActionType : void delegate (byte)))
				argumentType = typeid(byte);
			else static if (is(ActionType : void function (ubyte)) || is(ActionType : void delegate (ubyte)))
				argumentType = typeid(ubyte);
			else static if (is(ActionType : void function (short)) || is(ActionType : void delegate (short)))
				argumentType = typeid(short);
			else static if (is(ActionType : void function (ushort)) || is(ActionType : void delegate (ushort)))
				argumentType = typeid(ushort);
			else static if (is(ActionType : void function (int)) || is(ActionType : void delegate (int)))
				argumentType = typeid(int);
			else static if (is(ActionType : void function (uint)) || is(ActionType : void delegate (uint)))
				argumentType = typeid(uint);
			else static if (is(ActionType : void function (long)) || is(ActionType : void delegate (long)))
				argumentType = typeid(long);
			else static if (is(ActionType : void function (ulong)) || is(ActionType : void delegate (ulong)))
				argumentType = typeid(ulong);
			else static if (is(ActionType : void function (float)) || is(ActionType : void delegate (float)))
				argumentType = typeid(float);
			else static if (is(ActionType : void function (double)) || is(ActionType : void delegate (double)))
				argumentType = typeid(double);
			else
				static assert(false, format("not implemented for %s", ActionType));
		}
		Action opCall ()
		{
			actor();
			return this;
		}
		Action opCall (ArgType) (ArgType arg) if (is(ActionType : void function (ArgType)) || is(ActionType : void delegate (ArgType)))
		{
			actor(arg);
			return this;
		}
}


/++
 + Parser
 +/

abstract class Parser
{
	protected:
		Action[] actions;

	public:
		bool opCall (ref string s, Parser skipper = null) { return parse(s, skipper); }
		bool opCall (ref string s, out Variant v, Parser skipper = null) { return parse(s, v, skipper); }
		Parser opNeg () { return new NotParser(this); }
		AndParser opAdd (Parser p) { return new AndParser([this, p]); }
		AndParser opAdd (Parser* p) { return this + lazy_(p); }
		RepeatParser opSlice (uint from, uint to = 0) { return new RepeatParser(this, from, to); }
		RepeatParser opStar () { return this[0..0]; }
		RepeatParser opCom () { return this[0..1]; }
		RepeatParser opPos () { return this[1..0]; }
		SequenceParser opShr (Parser p) { return new SequenceParser([this, p]); }
		SequenceParser opShr (Parser* p) { return this >> lazy_(p); }
		SequenceParser opShr (char ch) { return this >> char_(ch); }
		SequenceParser opShr (string str) { return this >> string_(str); }
		SequenceParser opShr_r (char ch) { return char_(ch) >> this; }
		SequenceParser opShr_r (string str) { return string_(str) >> this; }
		SequenceParser opShr_r (Parser* p) { return lazy_(p) >> this; }
		AndParser opSub (Parser p) { return this + -p; }
		AndParser opSub (Parser* p) { return this + -lazy_(p); }
		OrParser opOr (Parser p) { return new OrParser([this, p]); }
		OrParser opOr (Parser* p) { return this | lazy_(p); }
		OrParser opOr (char ch) { return this | char_(ch); }
		SequenceParser opMod (char ch) { return this % char_(ch); }
		SequenceParser opMod (string str) { return this % string_(str); }
		SequenceParser opMod (Parser p) { return this >> *(p >> this); };
		SequenceParser opMod (Parser* p) { return this >> *(lazy_(p) >> this); };
		Parser opIndex (ActionType) (ActionType act) { actions ~= new TypedAction!ActionType(act); return this; }
		abstract bool match (ref string s);
		abstract bool match (ref string s, out Variant v);
		Parser doActions (string s)
		{
			foreach (action; actions)
			return this;
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
			if (!actions.empty)
				doActions(fs[0 .. $ - s.length]);
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
			if (!actions.empty)
				doActions(fs[0 .. $ - s.length]);
			return true;
		}

	debug(parser):
		protected:
			void function (Parser, string)[] beforeActions;
			void function (Parser, string, bool)[] afterActions;
			string name;
			static void writeBeginTrace (Parser p, string s)
			{
				writefln("%srule (%s) \"%s\"", repeat("  ", p.depth), p.name, s[0 .. ($ > 5)? 5 : $]);
				++p.depth;
			}
			static void writeEndTrace (Parser p, string s, bool result)
			{
				--p.depth;
				writefln("%s%srule (%s) \"%s\"", repeat("  ", p.depth), result? "/" : "#", p.name, s[0 .. ($ > 5)? 5 : $]);
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
/+
class ActionParser (Action): UnaryParser
{
	protected:
		Action action;

	public:
		this (Parser parser, Action action)
		{
			this.parser = parser;
			this.action = action;
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			if (!super.parse(s, skipper))
				return false;
			auto sVal = fs[0 .. $ - s.length];
			static if (is(Action : void function ()) || is(Action : void delegate ()))
				action();
			else static if (is(Action : void function (char)) || is(Action : void delegate (char)))
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
			else
				static assert(false, format("not implemented for %s", Action));
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			if (!super.parse(s, skipper))
				return false;
			auto sVal = fs[0 .. $ - s.length];
			static if (is(Action : void function ()) || is(Action : void delegate ()))
			{
				action();
			}
			else static if (is(Action : void function (char)) || is(Action : void delegate (char)))
			{
				v = fs[0];
				action(fs[0]);
			}
			else static if (is(Action : void function (string)) || is(Action : void delegate (string)))
			{
				v = sVal;
				action(sVal);
			}
			else static if (is(Action : void function (byte)) || is(Action : void delegate (byte)))
			{
				v = sVal;
				action(to!(byte)(sVal));
			}
			else static if (is(Action : void function (ubyte)) || is(Action : void delegate (ubyte)))
			{
				v = sVal;
				action(to!(ubyte)(sVal));
			}
			else static if (is(Action : void function (short)) || is(Action : void delegate (short)))
			{
				v = sVal;
				action(to!(short)(sVal));
			}
			else static if (is(Action : void function (ushort)) || is(Action : void delegate (ushort)))
			{
				v = sVal;
				action(to!(ushort)(sVal));
			}
			else static if (is(Action : void function (int)) || is(Action : void delegate (int)))
			{
				v = sVal;
				action(to!(int)(sVal));
			}
			else static if (is(Action : void function (uint)) || is(Action : void delegate (uint)))
			{
				v = sVal;
				action(to!(uint)(sVal));
			}
			else static if (is(Action : void function (long)) || is(Action : void delegate (long)))
			{
				v = sVal;
				action(to!(long)(sVal));
			}
			else static if (is(Action : void function (ulong)) || is(Action : void delegate (ulong)))
			{
				v = sVal;
				action(to!(ulong)(sVal));
			}
			else static if (is(Action : void function (float)) || is(Action : void delegate (float)))
			{
				v = sVal;
				action(to!(float)(sVal));
			}
			else static if (is(Action : void function (double)) || is(Action : void delegate (double)))
			{
				v = sVal;
				action(to!(double)(sVal));
			}
			else
				static assert(false, "not implemented");
			return true;
		}
		ActionParser!(Action) opIndex (Action action)
		{
			this.action = action;
			return this;
		}

	debug(parser):
		Parser trace (string name)
		{
			parser.trace(name);
			return this;
		}
}

unittest
{
	new Test!(ActionParser!(void delegate (char)), "!(void delegate (char))")(
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
	new Test!(ActionParser!(void delegate (string)), "!(void delegate (string))")(
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
	new Test!(ActionParser!(void delegate (uint)), "!(void delegate (uint))")(
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
	new Test!(ActionParser!(void delegate (int)), "!(void delegate (int))")(
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
	new Test!(ActionParser!(void delegate (double)), "!(void delegate (double))")(
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
}+/

/++
 + PrimitiveParser
 +/

class PrimitiveParser (Type): Parser
{
	public:
		bool match (ref string s)
		{
			try
			{
				debug(parser) doBeforeActions(s);
				std.conv.parse!(Type)(s);
			}
			catch
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			try
			{
				debug(parser) doBeforeActions(s);
				v = std.conv.parse!(Type)(s);
			}
			catch
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			debug(parser) doAfterActions(s, true);
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
			debug(parser) doBeforeActions(s);
			if (0 == s.length || s[0] != value)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			s = s[1 .. $];
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			debug(parser) doBeforeActions(s);
			if (0 == s.length || s[0] != value)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			v = s[0];
			s = s[1 .. $];
			debug(parser) doAfterActions(s, true);
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
			debug(parser) doBeforeActions(s);
			if (0 != s.length)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			debug(parser) doBeforeActions(s);
			if (0 != s.length)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			debug(parser) doAfterActions(s, true);
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
			debug(parser) doBeforeActions(s);
			if (s.length < value.length || s[0 .. value.length] != value)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			s = s[value.length .. $];
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			debug(parser) doBeforeActions(s);
			if (s.length < value.length || s[0 .. value.length] != value)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			v = value;
			s = s[value.length .. $];
			debug(parser) doAfterActions(s, true);
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
		bool match (ref string s)
		{
			return parse(s);
		}
		bool match (ref string s, out Variant v)
		{
			return parse(s, v);
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			debug(parser) doBeforeActions(s);
			foreach (p; parsers)
			{
				if (!p(s, skipper))
				{
					debug(parser) doAfterActions(s, false);
					s = fs;
					return false;
				}
			}
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			v = new Variant[](parsers.length);
			debug(parser) doBeforeActions(s);
			foreach (i, p; parsers)
			{
				if (!p(s, *v[i].peek!(Variant)(), skipper))
				{
					debug(parser) doAfterActions(s, false);
					s = fs;
					return false;
				}
			}
			debug(parser) doAfterActions(s, true);
			return true;
		}
		SequenceParser opShr (SequenceParser parser) { return new SequenceParser(parsers ~ parser.parsers); }
		SequenceParser opShr (Parser parser) { return new SequenceParser(parsers ~ parser); }
		SequenceParser opShr (Parser* parser) { return this >> lazy_(parser); }
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
			debug(parser) doBeforeActions(s);
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
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			uint counter;
			Variant[] res;
			debug(parser) doBeforeActions(s);
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
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			debug(parser) doAfterActions(s, true);
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
		bool match (ref string s)
		{
			return parse(s);
		}
		bool match (ref string s, out Variant v)
		{
			return parse(s, v);
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			uint max = 0;
			debug(parser) doBeforeActions(s);
			foreach (p; parsers)
			{
				s = fs;
				if (!p(s, skipper))
				{
					debug(parser) doAfterActions(s, false);
					s = fs;
					return false;
				}
				auto matchLen = fs.length - s.length; 
				if (matchLen > max)
					max = matchLen;
			}
			s = fs[max .. $];
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			uint max = 0;
			Variant[] res;
			res.length = parsers.length;
			debug(parser) doBeforeActions(s);
			foreach (i, p; parsers)
			{
				s = fs;
				if (!p(s, res[i], skipper))
				{
					debug(parser) doAfterActions(s, false);
					s = fs;
					return false;
				}
				auto matchLen = fs.length - s.length; 
				if (matchLen > max)
					max = matchLen;
			}
			v = res;
			s = fs[max .. $];
			debug(parser) doAfterActions(s, true);
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
		bool match (ref string s)
		{
			return parse(s);
		}
		bool match (ref string s, out Variant v)
		{
			return parse(s, v);
		}
		bool parse (ref string s, Parser skipper = null)
		{
			auto fs = s;
			debug(parser) doBeforeActions(s);
			foreach (p; parsers)
			{
				if (p(s, skipper))
				{
					debug(parser) doAfterActions(s, true);
					return true;
				}
			}
			debug(parser) doAfterActions(s, false);
			s = fs;
			return false;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			debug(parser) doBeforeActions(s);
			foreach (p; parsers)
			{
				if (p(s, v, skipper))
				{
					debug(parser) doAfterActions(s, true);
					return true;
				}
			}
			debug(parser) doAfterActions(s, false);
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
	public:
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
			debug(parser) doBeforeActions(s);
			if (parser(s, skipper))
			{
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			s = s[$ > 0? 1 : 0 .. $];
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			auto fs = s;
			debug(parser) doBeforeActions(s);
			if (parser(s, skipper))
			{
				debug(parser) doAfterActions(s, false);
				s = fs;
				return false;
			}
			if (s.length)
				v = s[0];
			s = s[$ > 0? 1 : 0 .. $];
			debug(parser) doAfterActions(s, true);
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
			debug(parser) doBeforeActions(s);
			if (!s.length || s[0] < start || s[0] > end)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			s = s[1 .. $];
			debug(parser) doAfterActions(s, true);
			return true;
		}
		bool match (ref string s, out Variant v)
		{
			debug(parser) doBeforeActions(s);
			if (!s.length || s[0] < start || s[0] > end)
			{
				debug(parser) doAfterActions(s, false);
				return false;
			}
			v = s[0];
			s = s[1 .. $];
			debug(parser) doAfterActions(s, true);
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
/+
abstract class ContextParser: UnaryParser
{
	public:
		ContextParser* opAssign (Parser parser)
		{
			this.parser = parser;
			return &this;
		}
	debug(parser):
		public:
			Parser trace (string name)
			{
				parser.trace(name);
				return this;
			}
}+/

class ContextParser (ContextType): UnaryParser
{
	public:
		ContextType context;
	debug(parser):
		public:
			ContextParser!(ContextType) trace (string name)
			{
				parser.trace(name);
				return this;
			}
			bool parse (ref string s, Parser skipper = null)
			{
				auto oldContext = context;
				context = new ContextType();
				writeln("new context");
				scope(exit) { writeln("context back"); context = oldContext; }
				return super.parse(s, skipper);
			}
			bool parse (ref string s, out Variant v, Parser skipper = null)
			{
				auto oldContext = context;
				context = new ContextType();
				writeln("new context");
				scope(exit) { writeln("context back"); context = oldContext; }
				return super.parse(s, v, skipper);
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
			debug(parser)
			{
				doBeforeActions(s);
				if (!parser.match(s))
				{
					doAfterActions(s, false);
					return false;
				}
				doAfterActions(s, true);
				return true;
			}
			else
			{
				return parser.match(s);
			}
		}
		bool match (ref string s, out Variant v)
		{
			debug(parser)
			{
				doBeforeActions(s);
				if (!parser.match(s, v))
				{
					doAfterActions(s, false);
					return false;
				}
				doAfterActions(s, true);
				return true;
			}
			else
			{
				return parser.match(s, v);
			}
		}
		bool parse (ref string s, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				if (!parser.parse(s, skipper))
				{
					doAfterActions(s, false);
					return false;
				}
				doAfterActions(s, true);
				return true;
			}
			else
			{
				return parser.parse(s, skipper);
			}
		}
		bool parse (ref string s, out Variant v, Parser skipper = null)
		{
			debug(parser)
			{
				doBeforeActions(s);
				if (!parser.parse(s, v, skipper))
				{
					doAfterActions(s, false);
					return false;
				}
				doAfterActions(s, true);
				return true;
			}
			else
			{
				return parser.parse(s, v, skipper);
			}
		}
		Parser opIndex (ActionType) (ActionType action)
		{
			parser[action];
			return this;
		}

	unittest
	{
		scope t = new Test!LazyParser();
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
version(unittest)
{
	class StmtContext
	{
		int value;
	}
	class StmtParser: ContextParser!StmtContext
	{
		this ()
		{
			parser = uint_[(uint val){ context.value = val; }] | ('(' >> lazy_(&expr)[{ context.value = expr.context.value; }] >> ')');
		}
	}
	class ExprContext
	{
		int value;
		enum Op {Plus, Minus};
		Op op;
	}
	class ExprParser: ContextParser!ExprContext
	{
		this ()
		{
			parser
				= stmt[{ context.value = stmt.context.value; }]
				>> *((char_('-')[{ context.op = context.Op.Minus; }] | char_('+')[{ context.op = context.Op.Plus; }])
				>> stmt[{ context.value = (context.op == context.Op.Plus)? (context.value + stmt.context.value) : (context.value - stmt.context.value); }])
				;
		}
	}
}
unittest
{
	

	StmtParser stmt;
	ExprParser expr;
	stmt = new StmtParser();
	expr = new ExprParser();
	auto s = "1+(3-1)+4-2";
	assert(expr(s));
	assert(expr.value == 5);
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
	new Test!Action(
	{
		uint val;
		auto p = char_('Z')[{ val = 5; }];
		auto s = "ZZZ";
		assert(val == val.init);
		assert(p(s));
		assert(val == 5);
	});
}
