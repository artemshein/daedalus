module templater;

debug = templater;

import std.variant, std.file, std.conv, std.string;
import http.wsapi : WsApi;
import parser;
version(unittest) import qc;
debug(templater) import std.stdio;


abstract class Templater
{
	protected:
		WsApi ws;
		string[] tplsDirs;
	public:
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			this.tplsDirs = tplsDirs;
			this.ws = ws;
		}
		string fetch (string fileName)
		{
			return fetchString(cast(string)read(fileName));
		}
		bool display (string fileName)
		{
			ws.write(fetch(fileName));
			return true;
		}
		bool displayString (string s)
		{
			ws.write(fetchString(s));
			return true;
		}
		abstract:
			string fetchString (string);
			//bool assign (string, Variant);
}

abstract class TplError: Error
{
	this ()
	{
		super("Template error", file, line);
	}
	this (string msg)
	{
		super(msg, file, line);
	}
	this (string msg, string file, size_t line)
	{
		super(msg, file, line);
	}
}

class TplParseError: TplError
{
	this (uint pos)
	{
		super("Invalid template at " ~ to!string(pos), file, line);
	}
}

abstract class TplExecutionError: TplError
{
	this ()
	{
		super("Template execution error", file, line);
	}
	this (string msg)
	{
		super(msg, file, line);
	}
	this (string msg, string file, size_t line)
	{
		super(msg, file, line);
	}
}

class InvalidModifierError: TplExecutionError
{
	this (string file, size_t line)
	{
		super("Invalid modifier", file, line);
	}
	this (string name)
	{
		super("Invalid modifier " ~ name, file, line);
	}
}

private struct VariantProxy
{
	Variant v;
	this (Variant v)
	{
		this.v = v;
	}
}

private abstract class Modifier
{
	abstract Variant opCall (Variant v, Variant[] params);
}

private class ModifierCall
{
	public:
		string name;
		Variant[] params;
		ModifierCall appendParam (Variant v)
		{
			params ~= v;
			return this;
		}
}
private class Expr
{
	protected:
		Modifier[string] modifiers;

	public:
		Variant val;
		ModifierCall[] modifiersCalls;
		Type opCast (Type : bool) ()
		{
			if (!val.hasValue || val.type == typeid(null))
				return false;
			return val.get!(Type);
		}
		bool isBiggerThan (Expr e)
		{
			if (val.type == typeid(uint))
				return val.get!uint > e.val.get!uint;
			else
				return val > e.val;
		}
		bool isBiggerOrEqThan (Expr e)
		{
			if (val.type == typeid(uint))
				return val.get!uint >= e.val.get!uint;
			else
				return val >= e.val;
		}
		bool isEq (Expr e)
		{
			if (val.type == typeid(uint))
				return val.get!uint == e.val.get!uint;
			else
				return val == e.val;
		}
		Expr addModifierCall (ModifierCall modifierCall)
		{
			modifiersCalls ~= modifierCall;
			return this;
		}
		Expr addModifier (string name, Modifier modifier)
		{
			modifiers[name] = modifier;
			return this;
		}
		Expr applyModifierCall (ref Variant v, ModifierCall modifierCall)
		{
			auto modifier = modifierCall.name in modifiers;
			if (modifier is null)
				throw new InvalidModifierError(modifierCall.name);
			(*modifier)(v, modifierCall.params);
			return this;
		}
		Expr applyModifiersCalls ()
		{
			foreach (modifierCall; modifiersCalls)
				applyModifierCall(val, modifierCall);
			return this;
		}
		
}
private abstract class TplEl
{
	abstract string execute ();
	string opCall ()
	{
		return execute;
	}
}
private class TplContent: TplEl
{
	public:
		string content;
		this (string content)
		{
			this.content = content;
		}
		string execute ()
		{
			return content;
		}
}
private class TplIfEl: TplEl
{
	public:
		Expr expr;
		TplEl[] ifEls, elseEls;
		string execute ()
		{
			auto res = "";
			foreach (el; cast(bool)expr? ifEls : elseEls)
				res ~= el.execute;
			return res;
		}
}
private class ScriptContext
{
	protected:
		uint elsCnt;
		uint contentBlockCnt;
		char[] contentBlock;
	public:
		TplEl[] els;
		void appendContent (char ch)
		{
			//writeln("appending content ", ch);
			if (contentBlockCnt >= contentBlock.length)
				contentBlock.length = contentBlock.length * 2 + 1;
			contentBlock[contentBlockCnt++] = ch;
			//writeln("now content = ", contentBlock[0 .. contentBlockCnt]);
		}
		void closeContentBlock ()
		{
			//writeln("closing context");
			if (contentBlockCnt)
			{
				appendElement(new TplContent(contentBlock[0 .. contentBlockCnt].idup));
				contentBlockCnt = 0;
			}
		}
		void appendElement (TplEl el)
		{
			//writeln("appending element");
			if (elsCnt >= els.length)
				els.length = els.length * 2 + 1;
			els[elsCnt++] = el;
		}
}

class SimpleExprParser: ContextParser!(Expr)
{
	public:
		this ()
		{
			parser
				= string_("true")[{ context.val = true; }]
				| string_("false")[{ context.val = false; }]
				| uint_[(uint v){ context.val = v; }]
				| (char_('"') >> *(string_("\\\"") | -char_('"')) >> char_('"'))[(string s){ context.val = parseString(s); }]
				;
		}
		static string parseString (string s)
		{
			// FIXME: parse escape \"
			return s[1 .. $ - 1];
		}
}
class ModifierParser: ContextParser!(ModifierCall)
{
	public:
		SimpleExprParser simpleExpr;
		this ()
		{
			simpleExpr = new SimpleExprParser;
			parser
				= char_('|')
				>> (alpha >> *alnum)[(string s){ context.name = s; }]
				>> *(
					char_(':') >> simpleExpr[{ context.appendParam(simpleExpr.context.val); }]
				)
				;
		}
}
class VarParser: ContextParser!(Expr)
{
	protected:
		VariantProxy[string] vars;

		Variant var (string name)
		{
			auto val = name in vars;
			return (val is null)? Variant(null) : (*val).v;
		}

	public:
		this ()
		{
			auto modifier = new ModifierParser;
			parser
				= (alpha >> *alnum)[(string id){ context.val = var(id); }]
				>> *(modifier[{ context.addModifierCall(modifier.context); }])
				;
		}
		VarParser assign (string name, VariantProxy value)
		{
			vars[name] = value;
			return this;
		}
		VarParser register (string name, Variant function (Variant) modifier)
		{
			var.register(name, modifier);
			return this;
		}
}
class AtomicExprParser: ContextParser!(Expr)
{
	protected:
		SimpleExprParser simpleExpr;
		VarParser var;

	public:
		this ()
		{
			simpleExpr = new SimpleExprParser;
			var = new VarParser;
			parser
				= simpleExpr.trace("simpleExpr")[{ context = simpleExpr.context; }]
				| var[{ context = var.context; }]
				;
		}
		AtomicExprParser assign (string name, VariantProxy value)
		{
			var.assign(name, value);
			return this;
		}
		AtomicExprParser register (string name, Variant function (Variant) modifier)
		{
			var.register(name, modifier);
			return this;
		}
}
class ExprParser: ContextParser!(Expr)
{
	protected:
		AtomicExprParser atomicExpr;

	public:
		this ()
		{
			atomicExpr = new AtomicExprParser;
			auto atomicExprContext = new Expr;
			string op;
			parser
				=
				(	atomicExpr[{ atomicExprContext = atomicExpr.context; }]
					>> *space
					>> (string_(">") | string_(">=") | string_("<") | string_("<=") | string_("=="))[(string s){ op = s; }]
					>> *space
					>> atomicExpr[{
						atomicExprContext.applyModifiersCalls;
						atomicExpr.context.applyModifiersCalls;
						switch (op)
						{
							case ">":
								context.val = atomicExprContext.isBiggerThan(atomicExpr.context);
								break;
							case ">=":
								context.val = atomicExprContext.isBiggerOrEqThan(atomicExpr.context);
								break;
							case "<":
								context.val = atomicExpr.context.isBiggerThan(atomicExprContext);
								break;
							case "<=":
								context.val = atomicExpr.context.isBiggerOrEqThan(atomicExprContext);
								break;
							case "==":
								context.val = atomicExpr.context.isEq(atomicExprContext);
								break;
							default:
								assert(0);
						}
					}]
				)
				| atomicExpr[{ context = atomicExpr.context; }]
				;
		}
		ExprParser assign (string name, VariantProxy value)
		{
			atomicExpr.assign(name, value);
			return this;
		}
		ExprParser register (string name, Variant function (Variant) modifier)
		{
			atomicExpr.register(name, modifier);
			return this;
		}
		
	unittest
	{
		scope t = new Test!ExprParser;
		auto p = new ExprParser;
		auto s = "true";
		auto context = new Expr;
		assert(p(s, context));
		assert(context);
		s = "false";
		assert(p(s, context));
		assert(!cast(bool)context);
	}
}
class IfStmtParser: ContextParser!(TplIfEl)
{
	protected:
		ExprParser expr;
	public:
		this (ScriptParser script)
		{
			auto elseStmt
				= doBlockBgn
				>> *space
				>> string_("else")
				>> *space
				>> doBlockEnd
				;
			auto endIfStmt
				= doBlockBgn
				>> *space
				>> string_("endif")
				>> *space
				>> doBlockEnd
				;
			expr = new ExprParser;
			parser
				= (doBlockBgn
				>> *space
				>> string_("if")
				>> +space
				>> expr.trace("expr")[{ context.expr = expr.context; }]
				>> *space
				>> doBlockEnd
				>> lazy_(&script)[{ context.ifEls = script.context.els; }]
				>> ~(elseStmt >> lazy_(&script)[{ context.elseEls = script.context.els; }])
				>> endIfStmt
				)
				;
		}
		IfStmtParser assign (string name, VariantProxy value)
		{
			expr.assign(name, value);
			return this;
		}
		IfStmtParser register (string name, Variant function (Variant) modifier)
		{
			expr.register(name, modifier);
			return this;
		}

	unittest
	{
		writeln("111");
		scope t = new Test!IfStmtParser;
		auto tpl = new Tornado;
		auto p = new IfStmtParser(tpl.parser);
		auto s = "{% if true %}{% endif %}";
		auto context = new TplIfEl;
		assert(p(s, context));
		assert(context.expr);
		s = "{% if false %}abc{% else %}def{% endif %}";
		assert(p(s, context));
		assert(!cast(bool)context.expr);
		assert(1 == context.ifEls.length);
		assert("abc" == context.ifEls[0].execute);
		assert(1 == context.elseEls.length);
		assert("def" == context.elseEls[0].execute);
	}
}

class ScriptParser: ContextParser!(ScriptContext)
{
	protected:
		IfStmtParser ifStmt;
		
	public:
		this ()
		{
			auto comment =  commentBlockBgn >> *(-commentBlockEnd) >> commentBlockEnd;
			auto p = this;
			ifStmt = new IfStmtParser(this);
			parser
				= (
				*	( comment
					| ifStmt[{ context.appendElement(ifStmt.context); }]
					| (anychar - (doBlockBgn | commentBlockBgn))[(char ch){ context.appendContent(ch); }]
					)
				)[{ context.closeContentBlock; context.els.length = context.elsCnt; }]
				;
		}
		ScriptParser assign (string name, VariantProxy value)
		{
			ifStmt.assign(name, value);
			return this;
		}
		ScriptParser register (string name, Variant function (Variant) modifier)
		{
			ifStmt.register(name, modifier);
			return this;
		}
		
	unittest
	{
		scope t = new Test!ScriptParser;
		auto tpl = new Tornado;
		//
		auto s = "{% if true %}yes{% else %}no{% endif %}";
		auto p = tpl.parser;
		auto c = new ScriptContext;
		assert(p(s, c));
		assert(1 == c.els.length);
		assert("yes" == c.els[0]());
		//
		s = "{% if false %}yes{% else %}no{% endif %}";
		c = new ScriptContext;
		assert(p(s, c));
		assert(1 == c.els.length);
		assert("no" == c.els[0]());
	}
}

class Tornado: Templater
{
	protected:
		ScriptParser parser;
		ScriptContext context;
		
		string executeScript (TplEl[] els)
		{
			auto res = "";
			foreach (el; els)
			{
				res ~= el.execute;
			}
			return res;
		}
		
	public:
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			parser = new ScriptParser;
		}
		string fetchString (string s)
		{
			auto context = new ScriptContext;
			auto s2 = s.idup;
			if (!parser(s2, context) || s2.length)
				throw new TplParseError(s.length - s2.length);
			return executeScript(context.els);
		}
		bool assign (Type) (string name, Type val)
		{
			static if (is(Type == Variant))
				parser.assign(name, *new VariantProxy(val));
			else
				parser.assign(name, *new VariantProxy(Variant(val)));
			return true;
		}
		Tornado register (string name, Variant function (Variant) modifier)
		{
			parser.register(name, modifier);
			return this;
		}
		
	unittest
	{
		scope t = new Test!Tornado;
		auto tpl = new Tornado;
		//
		auto s = "{% if true %}yes{% else %}no{% endif %}";
		assert("yes" == tpl.fetchString(s));
		//
		s = "{% if abc %}yeah{% else %}nope{% endif %}";
		tpl.assign("abc",true);
		assert("yeah" == tpl.fetchString(s));
		tpl.assign("abc", null);
		assert("nope" == tpl.fetchString(s));
		//
		s = "{% if cbd5 > def6 %}111{% else %}222{% endif %}";
		tpl.assign("cbd5", 5);
		tpl.assign("def6", 6);
		assert("222" == tpl.fetchString(s));
		tpl.assign("cbd5", 50);
		tpl.assign("def6", 20);
		assert("111" == tpl.fetchString(s));
		//
		s = "{% if true yes{% else %}no{% endif %}";
		assertThrows!TplParseError({ tpl.fetchString(s); });
		// With functions
		tpl.assign("testStr", "testVal");
		s = "abcdef{% if testStr|upper == \"TESTVAL\" %}gh{% else %}334{% endif %}wqw";
		assertThrows!InvalidModifierError({ tpl.fetchString(s); });
		tpl.register("upper", (Variant v){ return Variant(toupper(v.get!string)); });
		assert("abcdefghwqw" == tpl.fetchString(s));
	}
}

static Parser doBlockBgn, doBlockEnd, commentBlockBgn, commentBlockEnd;

static this ()
{
	doBlockBgn = string_("{%");
	doBlockEnd = string_("%}");
	commentBlockBgn = string_("{#");
	commentBlockEnd = string_("#}");
}
