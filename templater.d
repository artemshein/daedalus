/**
 * Templater
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2009 - 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */

module templater;

debug = templater;

import std.variant, std.file, std.conv, std.string;
import http.wsapi, parser;
version(unittest) import qc;
debug(templater) import std.stdio;

class TemplateNotFoundedError: Error
{
	this (string fileName, string[] searchDirs)
	{
		super("template " ~ fileName ~ " not founded in " ~ cast(string)searchDirs);
	}
}

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
		string tplContent (string fileName)
		{
			foreach (dir; tplsDirs)
				if (exists(dir ~ fileName))
					return cast(string)read(dir ~ fileName);
			throw new TemplateNotFoundedError(fileName, tplsDirs);
		}
		string fetch (string fileName)
		{
			return fetchString(tplContent(fileName));
		}
		bool display (string fileName)
		in
		{
			assert(ws !is null);
		}
		body
		{
			ws.write(fetch(fileName));
			return true;
		}
		bool displayString (string s)
		in
		{
			assert(ws !is null);
		}
		body
		{
			ws.write(fetchString(s));
			return true;
		}
		Templater assign (Type) (string name, Type val)
		{
			static if (is(Type == Variant))
				var(name, val);
			else
				var(name, Variant(val));
			return this;
		}
		abstract:
			string fetchString (string);
			Variant var (string);
			Templater var (string, Variant);
}

abstract class TplError: Error
{
	this ()
	{
		this("template error");
	}
	this (string msg)
	{
		super(msg);
	}
    this (string msg, string file, size_t line)
    {
		super(msg, file, line);
	}
}

class TplParseError: TplError
{
	this (string s, size_t pos)
	{
		super("parse error at " ~ to!string(pos) ~ ": " ~ s[0 .. (20 > $ - 1? $ - 1 : 20)]);
	}
	this (string s, size_t pos, string file, size_t line)
	{
		super("parse error at " ~ to!string(pos), file, line);
	}
}

abstract class TplExecutionError: TplError
{
	this (string msg)
	{
		super(msg);
	}
	this (string msg, string file, size_t line)
	{
		super(msg, file, line);
	}
}

class InvalidModifierError: TplExecutionError
{
	this ()
	{
		super("invlid modifier error");
	}
	this (string info)
	{
		super("invalid modifier " ~ info);
	}
}

class InvalidModifierParamTypeError: TplExecutionError
{
	this (string msg)
	{
		super(msg);
	}
	this (string msg, string file, size_t line)
	{
		super(msg, file, line);
	}
}

class IndexingError: TplExecutionError
{
	this (TypeInfo t)
	{
		super(t.toString);
	}
	this (TypeInfo t, string file, size_t line)
	{
		super(t.toString, file, line);
	}
	this (TypeInfo vT, TypeInfo iT, string file, size_t line)
	{
		super("index " ~ iT.toString ~ " on " ~ vT.toString, file, line);
	}
}

private abstract class Expr
{
	abstract Variant opCall (Tornado tpl = null);
}

private class RefExpr: Expr
{
	public:
		Expr expr;

		this () {}
		this (Expr expr)
		{
			this.expr = expr;
		}
		Variant opCall (Tornado tpl = null)
		{
			return expr(tpl);
		}
}

private class BoolExpr: Expr
{
	bool v;
	this (bool v)
	{
		this.v = v;
	}
	Variant opCall (Tornado tpl = null)
	{
		return Variant(v);
	}
}

private class UintExpr: Expr
{
	uint v;
	this (uint v)
	{
		this.v = v;
	}
	Variant opCall (Tornado tpl = null)
	{
		return Variant(v);
	}
}

private class IntExpr: Expr
{
	int v;
	this (int v)
	{
		this.v = v;
	}
	Variant opCall (Tornado tpl = null)
	{
		return Variant(v);
	}
}

private class StrExpr: Expr
{
	string v;
	this (string v)
	{
		this.v = v;
	}
	Variant opCall (Tornado tpl = null)
	{
		return Variant(v);
	}
}

private class VarExpr: Expr
{
	protected:
		auto addModifierCall (ModifierCall modifierCall)
		{
			modifiersCalls ~= modifierCall;
			return this;
		}
		VarExpr applyModifiersCalls (ref Variant v, Tornado tpl)
		in
		{
			assert(tpl !is null);
		}
		body
		{
			auto modifiers = tpl.modifiers;
			foreach (modifierCall; modifiersCalls)
			{
				Variant[] params;
				foreach (param; modifierCall.params)
					params ~= param(tpl);
				auto modifier = modifierCall.name in modifiers;
				if (modifier is null)
					throw new InvalidModifierError(modifierCall.name);
				(*modifier)(v, params);
			}
			return this;
		}
		VarExpr applyIndexes (ref Variant v, Tornado tpl)
		in
		{
			assert(tpl !is null);
		}
		body
		{
			foreach (index; indexes)
			{
				Variant i = index(tpl);
				auto vT = v.type;
				auto iT = i.type;
				if (vT == typeid(string))
				{
					if (iT == typeid(uint))
						v = v.get!string[i.get!uint - 1];
					else if (iT == typeid(int))
						v = v.get!string[i.get!int - 1];
					else
						throw new IndexingError(vT, iT, __FILE__, __LINE__);
				}
				else if (vT == typeid(Variant[string]))
				{
					if (iT == typeid(string))
						v = v.get!(Variant[string])[i.get!string];
					else
						throw new IndexingError(vT, iT, __FILE__, __LINE__);
				}
				else if (vT == typeid(string[]))
				{
					if (iT == typeid(uint))
						v = v.get!(string[])[i.get!uint - 1];
					else if (iT == typeid(int))
						v = v.get!(string[])[i.get!int - 1];
					else
						throw new IndexingError(vT, iT, __FILE__, __LINE__);
				}
				else
					throw new IndexingError(vT, __FILE__, __LINE__);
			}
			return this;
		}
		
	public:
		static
		{
			class ModifierCall
			{
				public:
					string name;
					Expr[] params;
					
					ModifierCall appendParam (Expr v)
					{
						params ~= v;
						return this;
					}
			}
		}
		
		string name;
		RefExpr[] indexes;
		ModifierCall[] modifiersCalls;
	
		Variant opCall (Tornado tpl = null)
		in
		{
			assert(tpl !is null);
		}
		body
		{
			auto v = tpl.var(name);
			applyIndexes(v, tpl);
			applyModifiersCalls(v, tpl);
			return v;
		}
}

private class OpExpr: Expr
{
	protected:
		static
		{
			bool isBiggerThan (Variant l, Variant r)
			{
				if (l.type == typeid(uint))
					return l.get!uint > ((typeid(uint) == r.type) ? r.get!uint : r.get!int);
				else if (l.type == typeid(int))
					return l.get!int > ((typeid(uint) == r.type) ? r.get!uint : r.get!int);
				else
					return l > r;
			}
			bool isBiggerOrEqThan (Variant l, Variant r)
			{
				if (l.type == typeid(uint))
					return l.get!uint >= ((typeid(uint) == r.type) ? r.get!uint : r.get!int);
				else if (l.type == typeid(int))
					return l.get!int >= ((typeid(uint) == r.type) ? r.get!uint : r.get!int);
				else
					return l >= r;
			}
			bool isEq (Variant l, Variant r)
			{
				if (l.type == typeid(uint))
					return l.get!uint == ((typeid(uint) == r.type) ? r.get!uint : r.get!int);
				else if (l.type == typeid(int))
					return l.get!int == ((typeid(uint) == r.type) ? r.get!uint : r.get!int);
				else
					return l == r;
			}
		}
	public:
		Expr left, right;
		string op;
		
		Variant opCall (Tornado tpl = null)
		in
		{
			assert(tpl !is null);
		}
		body
		{
			auto l = left(tpl), r = right(tpl);
			switch (op)
			{
				case ">":
					return Variant(isBiggerThan(l, r));
				case ">=":
					return Variant(isBiggerOrEqThan(l, r));
				case "<":
					return Variant(isBiggerThan(r, l));
				case "<=":
					return Variant(isBiggerOrEqThan(r, l));
				case "==":
					return Variant(isEq(l, r));
			}
			assert(false, "invalid operator");
		}
}

private abstract class TplEl
{
	public:
		abstract string execute (Tornado tpl = null);
		string opCall (Tornado tpl = null)
		{
			return execute(tpl);
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
		string execute (Tornado tpl = null)
		{
			return content;
		}
}

private class TplIfEl: TplEl
{
	public:
		Expr expr;
		TplEl[] ifEls, elseEls;
		
		string execute (Tornado tpl = null)
		in
		{
			assert(expr !is null);
		}
		body
		{
			auto res = "";
			auto v = expr(tpl);
			foreach (el; (v.hasValue && v.type != typeid(null) && v.get!bool)? ifEls : elseEls)
				res ~= el.execute(tpl);
			return res;
		}
}

string foreachIfStmt (string Type) ()
{
	return
	"foreach (k, v; val.get!(" ~ Type ~ "))
	{
		if (keyVar)
			tpl.assign(keyVar, k);
		tpl.assign(valVar, v);
		foreach (el; els)
			res ~= el.execute(tpl);
	}";
}

private class TplPrintEl: TplEl
{
	public:
		Expr expr;
		
		string execute (Tornado tpl = null)
		{
			auto v = expr(tpl);
			return v.toString;
		}
}

private class TplBlockEl: TplEl
{
	public:
		TplEl[] els;
		string name;
		
		string execute (Tornado tpl = null)
		{
			auto res = "";
			foreach (el; els)
				res ~= el(tpl);
			return res;
		}
}

private class TplForeachEl: TplEl
{
	public:
		string keyVar, valVar, exprVar;
		TplEl[] els;
		
		string execute (Tornado tpl = null)
		in
		{
			assert(tpl !is null);
		}
		body
		{
			auto res = "";
			Variant val = tpl.var(exprVar);
			if (val.type == typeid(string[]))
				mixin(foreachIfStmt!"string[]");
			else if (val.type == typeid(uint[]))
				mixin(foreachIfStmt!"uint[]");
			else if (val.type == typeid(int[]))
				mixin(foreachIfStmt!"int[]");
			else if (val.type == typeid(Variant[]))
				mixin(foreachIfStmt!"Variant[]");
			else if (val.type == typeid(Variant[]))
				mixin(foreachIfStmt!"Variant[]");
			else if (val.type == typeid(string[string]))
				mixin(foreachIfStmt!"string[string]");
			else if (val.type == typeid(uint[string]))
				mixin(foreachIfStmt!"uint[string]");
			else if (val.type == typeid(int[string]))
				mixin(foreachIfStmt!"int[string]");
			else if (val.type == typeid(Variant[string]))
				mixin(foreachIfStmt!"Variant[string]");
			else if (val.type == typeid(Variant[string]))
				mixin(foreachIfStmt!"Variant[string]");
			else
				assert(false, "not implemented");
			return res;
		}
}

private class TplExtendsEl: TplEl
{
	public:
		Expr tplName;
		
		string execute (Tornado tpl = null)
		in
		{
			assert(tpl !is null);
			assert(tpl.context !is null);
		}
		body
		{
			auto s = tpl.tplContent(tplName(tpl).get!string);
			auto thisContext = tpl.context;
			auto context = new ScriptContext;
			tpl.parse(s, context);
			foreach (name, block; thisContext.blocks)
				if (name in context.blocks)
					context.blocks[name].els = block.els;
			tpl.context = context;
			auto res = tpl.context(tpl);
			tpl.skipMode = true;
			return res;
		}
}

private class ScriptContext
{
	protected:
		uint elsCnt;
		uint contentBlockCnt;
		char[] contentBlock;
		TplBlockEl[string] blocks;
		TplEl[] els;
		
	public:		
		void appendContent (char ch)
		{
			if (contentBlockCnt >= contentBlock.length)
				contentBlock.length = contentBlock.length * 2 + 1;
			contentBlock[contentBlockCnt++] = ch;
		}
		void closeContentBlock ()
		{
			if (contentBlockCnt)
			{
				auto c = contentBlockCnt;
				contentBlockCnt = 0;
				appendElement(new TplContent(contentBlock[0 .. c].idup));
			}
		}
		void appendElement (TplEl el)
		{
			closeContentBlock;
			if (elsCnt >= els.length)
				els.length = els.length * 2 + 1;
			els[elsCnt++] = el;
		}		
		string execute (Tornado tpl = null)
		{
			auto res = "";
			foreach (el; els)
				if (tpl.skipMode)
					break;
				else
					res ~= el.execute(tpl);
			return res;
		}
		string opCall (Tornado tpl = null)
		{
			return execute(tpl);
		}
}

class SimpleExprParser: ContextParser!(RefExpr)
{
	public:
		this ()
		{
			parser
				= string_("true")[{ context.expr = new BoolExpr(true); }]
				| string_("false")[{ context.expr = new BoolExpr(false); }]
				| uint_[(uint v){ context.expr = new UintExpr(v); }]
				| int_[(int v){ context.expr = new IntExpr(v); }]
				| ('"' >> *(string_("\\\"") | -char_('"')) >> '"')[(string s){ context.expr = new StrExpr(parseString(s)); }]
				;
		}
		static string parseString (string s)
		{
			// FIXME: parse escape \"
			return s[1 .. $ - 1];
		}
}

class ModifierParser: ContextParser!(VarExpr.ModifierCall)
{
	public:
		SimpleExprParser simpleExpr;
		
		this ()
		{
			simpleExpr = new SimpleExprParser;
			parser
				= '|'
				>> id[(string s){ context.name = s; }]
				>> *(
					':' >> simpleExpr[{ context.appendParam(simpleExpr.context); }]
				)
				;
		}
}

class VarParser: ContextParser!(VarExpr)
{
	public:
		this ()
		{
			auto modifier = new ModifierParser;
			auto simpleExpr = new SimpleExprParser;
			RefExpr refExpr;
			parser
				= id[(string id){ context.name = id; }]
				>> *(('.' >> id[(string id){ context.indexes ~= new RefExpr(new StrExpr(id)); }])
					| ('[' >> simpleExpr[{ refExpr = simpleExpr.context; }] >> ']')[{ context.indexes ~= refExpr; }]
					)
				>> *(modifier[{ context.addModifierCall(modifier.context); }])
				;
		}
		
	unittest
	{
		auto tpl = new Tornado;
		auto p = new VarParser;
		auto context = new VarExpr;
		auto s = "abc245.efgh45.bca[3][1]";
		assert(p(s, context));
		string[] bca = ["a1", "b2", "c3", "d4"];
		Variant[string] efgh45 = ["bca": Variant(bca)];
		Variant[string] abc245 = ["efgh45": Variant(efgh45)];
		tpl.assign("abc245", abc245);
		assert('c' == context(tpl));
	}
}

class AtomicExprParser: ContextParser!(RefExpr)
{
	protected:
		SimpleExprParser simpleExpr;
		VarParser varP;

	public:
		this ()
		{
			simpleExpr = new SimpleExprParser;
			varP = new VarParser;
			parser
				= simpleExpr[{ context.expr = simpleExpr.context; }]
				| varP[{ context.expr = varP.context; }]
				;
		}
}

class ExprParser: ContextParser!(RefExpr)
{
	protected:
		AtomicExprParser atomicExpr;

	public:
		this ()
		{
			atomicExpr = new AtomicExprParser;
			parser
				=
				(	atomicExpr[{ auto expr = new OpExpr; expr.left = atomicExpr.context; context.expr = expr; }]
					>> *space
					>> (string_(">") | ">=" | "<" | "<=" | "==")[(string s){ (cast(OpExpr)context.expr).op = s; }]
					>> *space
					>> atomicExpr[{ (cast(OpExpr)context.expr).right = atomicExpr.context; }]
				)
				| atomicExpr[{ context.expr = atomicExpr.context; }]
				;
		}
		
	unittest
	{
		auto p = new ExprParser;
		auto s = "true";
		auto context = new RefExpr;
		assert(p(s, context));
		assert(context().get!bool);
		s = "false";
		assert(p(s, context));
		assert(!context().get!bool);
	}
}

class IfStmtParser: ContextParser!(TplIfEl)
{
	protected:
		ExprParser expr;

	public:
		this (ScriptParser script)
		{
			expr = new ExprParser;
			auto elseStmt
				= doBlockBgn
				>> *space
				>> "else"
				>> *space
				>> doBlockEnd
				;
			auto endIfStmt
				= doBlockBgn
				>> *space
				>> "endif"
				>> *space
				>> doBlockEnd
				;
			parser
				= doBlockBgn
				>> *space
				>> "if"
				>> +space
				>> expr[{ context.expr = expr.context; }]
				>> *space
				>> doBlockEnd
				>> lazy_(&script)[{ context.ifEls = script.context.els; }]
				>> ~(elseStmt >> lazy_(&script)[{ context.elseEls = script.context.els; }])
				>> endIfStmt
				;
		}

	unittest
	{
		auto tpl = new Tornado;
		auto p = new IfStmtParser(tpl.parser);
		auto s = "{% if true %}{% endif %}";
		auto context = new TplIfEl;
		assert(p(s, context));
		assert(context.expr().get!bool);
		s = "{% if false %}abc{% else %}def{% endif %}";
		assert(p(s, context));
		assert(!context.expr().get!bool);
		assert(1 == context.ifEls.length);
		assert("abc" == context.ifEls[0]());
		assert(1 == context.elseEls.length);
		assert("def" == context.elseEls[0]());
	}
}

class PrintStmtParser: ContextParser!(TplPrintEl)
{
	protected:
		AtomicExprParser atomicExpr;

	public:
		this ()
		{
			atomicExpr = new AtomicExprParser;
			parser
				= printBlockBgn
				>> *space
				>> atomicExpr[{ context.expr = atomicExpr.context; }]
				>> *space
				>> printBlockEnd
				;
		}
		
	unittest
	{
		auto p = new PrintStmtParser;
		auto tpl = new Tornado;
		tpl.assign("i", 123);
		auto s = "{{ i }}";
		auto context = new TplPrintEl;
		assert(p(s, context));
		assert("123" == context(tpl));
	}
}

class ForeachStmtParser: ContextParser!(TplForeachEl)
{
	protected:
	public:
		this (ScriptParser script)
		{
			auto foreachStmt
				= doBlockBgn
				>> *space
				>> "foreach"
				>> +space
				>> ~(id[(string s){ context.keyVar = s; }] >> *space >> ',' >> *space)
				>> id[(string s){ context.valVar = s; }]
				>> +space
				>> "in"
				>> +space
				>> id[(string s){ context.exprVar = s; }]
				>> *space
				>> doBlockEnd
				;
			auto endForeachStmt
				= doBlockBgn
				>> *space
				>> "endforeach"
				>> *space
				>> doBlockEnd
				;
			parser
				= foreachStmt
				>> lazy_(&script)[{ context.els = script.context.els; }]
				>> endForeachStmt
				;
		}
		
	unittest
	{
		auto tpl = new Tornado;
		tpl.assign("test", ["a", "b", "c", "d"]);
		auto s = "--{% foreach i, v in test %}{{ i }}:{{ v }}|{% endforeach %}++";
		assert("--0:a|1:b|2:c|3:d|++" == tpl.fetchString(s));
	}
}

class BlockStmtParser: ContextParser!(TplBlockEl)
{
	public:
		this (ScriptParser script)
		{
			parser
				= doBlockBgn
				>> *space
				>> "block"
				>> +space
				>> id[(string id){ context.name = id; }]
				>> *space
				>> doBlockEnd
				>> lazy_(&script)[{ context.els = script.context.els; }]
				>> doBlockBgn
				>> *space
				>> "endblock"
				>> *space
				>> doBlockEnd
				;
		}
}

class ExtendsStmtParser: ContextParser!(TplExtendsEl)
{
	public:
		SimpleExprParser simpleExpr;
		
		this ()
		{
			simpleExpr = new SimpleExprParser;
			
			parser
				= doBlockBgn
				>> *space
				>> "extends"
				>> +space
				>> simpleExpr[{ context.tplName = simpleExpr.context; }]
				>> *space
				>> doBlockEnd
				;
		}
}

class ScriptParser: ContextParser!(ScriptContext)
{
	protected:
		IfStmtParser ifStmt;
		ForeachStmtParser foreachStmt;
		PrintStmtParser printStmt;
		BlockStmtParser blockStmt;
		ExtendsStmtParser extendsStmt;
		
	public:
		this ()
		{
			auto comment =  commentBlockBgn >> *(-commentBlockEnd) >> commentBlockEnd;
			ifStmt = new IfStmtParser(this);
			foreachStmt = new ForeachStmtParser(this);
			printStmt = new PrintStmtParser;
			blockStmt = new BlockStmtParser(this);
			extendsStmt = new ExtendsStmtParser;
			
			parser
				= (
				*	( comment
					| ifStmt[{ context.appendElement(ifStmt.context); }]
					| foreachStmt[{ context.appendElement(foreachStmt.context); }]
					| printStmt[{ context.appendElement(printStmt.context); }]
					| blockStmt[{ context.appendElement(blockStmt.context); context.blocks[blockStmt.context.name] = blockStmt.context; }]
					| extendsStmt[{ context.appendElement(extendsStmt.context); }]
					| (anychar - (commentBlockBgn | doBlockBgn | printBlockBgn))[(char ch){ context.appendContent(ch); }]
					)
				)[{ context.closeContentBlock; context.els.length = context.elsCnt; }]
				;
		}
		
	unittest
	{
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

/++
 + Modifiers
 +/

void upperModifier (ref Variant v, Variant[] params)
{
	v = toupper(v.toString);
}

void lowerModifier (ref Variant v, Variant[] params)
{
	v = tolower(v.toString);
}

void sliceModifier (ref Variant v, Variant[] params)
{
	int from, to;
	if (params[0].type == typeid(int))
		from = params[0].get!int;
	else if (params[0].type == typeid(uint))
		from = params[0].get!uint;
	else
		throw new InvalidModifierParamTypeError("slice (first parameter)");
	string s = v.get!string;
	if (params.length > 1)
	{
		if (params[1].type == typeid(int))
			to = params[1].get!int;
		else if (params[1].type == typeid(uint))
			to = params[1].get!uint;
		else
			throw new InvalidModifierParamTypeError("slice (second parameter)");
	}
	else
		to = s.length;
	v = s[from - 1 .. to];
}

class Tornado: Templater
{
	protected:
		struct VariantProxy
		{
			Variant v;
			this (Variant v)
			{
				this.v = v;
			}
		}
		
		VariantProxy[string] vars;
		Modifier[string] modifiers;
		ScriptParser parser;
		ScriptContext context;
		
	public:
		alias void function (ref Variant, Variant[]) Modifier;
		bool skipMode;
		
		Variant var (string name)
		{
			auto val = name in vars;
			return (val is null)? Variant(null) : (*val).v;
		}
		Templater var (string name, Variant value)
		{
			vars[name] = *new VariantProxy(value);
			return this;
		}
		auto modifier (string name)
		{
			return modifiers[name];
		}
		auto modifier (string name, Modifier modifier)
		{
			modifiers[name] = modifier;
			return this;
		}
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			parser = new ScriptParser;
			modifier("upper", &upperModifier);
			modifier("lower", &lowerModifier);
			modifier("slice", &sliceModifier);
		}
		Tornado parse (string s, ScriptContext context)
		{
			this.context = context;
			auto s2 = s;
			skipMode = false;
			if (!parser(s2, context) || s2.length)
				throw new TplParseError(s2, s.length - s2.length);
			return this;
		}
		string fetchString (string s)
		{
			auto context = new ScriptContext;
			parse(s, context);
			return context(this);//executeScript(context.els);
		}
		
	unittest
	{
		auto tpl = new Tornado;
		//
		assert("yes" == tpl.fetchString("{% if true %}yes{% else %}no{% endif %}"));
		//
		tpl.assign("abc",true);
		assert("yeah" == tpl.fetchString("{% if abc %}yeah{% else %}nope{% endif %}"));
		tpl.assign("abc", null);
		assert("nope" == tpl.fetchString("{% if abc %}yeah{% else %}nope{% endif %}"));
		//
		tpl.assign("cbd5", 5);
		tpl.assign("def6", 6);
		assert("222" == tpl.fetchString("{% if cbd5 > def6 %}111{% else %}222{% endif %}"));
		tpl.assign("cbd5", 50);
		tpl.assign("def6", 20);
		assert("111" == tpl.fetchString("{% if cbd5 > def6 %}111{% else %}222{% endif %}"));
		//
		assertThrows!TplParseError({ tpl.fetchString("{% if true yes{% else %}no{% endif %}"); });
		// With modifiers
		tpl.assign("testStr", "testVal");
		assert("abcdefghwqw" == tpl.fetchString("abcdef{% if testStr|upper == \"TESTVAL\" %}gh{% else %}334{% endif %}wqw"));
		assert("abcdefghwqw" == tpl.fetchString("abcdef{% if testStr|upper|lower == \"testval\" %}gh{% else %}334{% endif %}wqw"));
		assert("abcdefghwqw" == tpl.fetchString("abcdef{% if testStr|slice:2:4 == \"est\" %}gh{% else %}334{% endif %}wqw"));
		// Foreach
		tpl.assign("testForeach", ["a", "b", "c", "d"]);
		assert("11abcd22" == tpl.fetchString("11{% foreach v in testForeach %}{{ v }}{% endforeach %}22"));
		assert("([a][b][2:c][d])" == tpl.fetchString("({% foreach i, v in testForeach %}[{% if v|upper == \"C\" %}{{ i }}:{{ v }}{% else %}{{ v }}{% endif %}]{% endforeach %})"));
		// Block
		tpl.assign("v", 1);
		assert("abc(def)ghi" == tpl.fetchString("abc{% block test %}({% if v == 1 %}def{% endif %}){% endblock %}ghi"));
		
	}
}

static Parser doBlockBgn, doBlockEnd, commentBlockBgn, commentBlockEnd, printBlockBgn, printBlockEnd, id;

static this ()
{
	id = alpha >> *alnum;
	doBlockBgn = string_("{%");
	doBlockEnd = string_("%}");
	commentBlockBgn = string_("{#");
	commentBlockEnd = string_("#}");
	printBlockBgn = string_("{{");
	printBlockEnd = string_("}}");
}
