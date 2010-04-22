module templater;

debug = templater;

import std.variant, std.file, std.conv;
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

class Tornado: Templater
{
	protected:
		/++
		 + Execution
		 +/
		static
		{
			class Expr
			{
				public:
					Variant val;
					Type opCast (Type : bool) ()
					{
						if (val.type == typeid(null))
							return false;
						return val.get!(Type);
					}
					bool isBiggerThan (Expr e)
					{
						if (val.type == typeid(uint))
							return val.get!uint() > e.val.get!uint;
						else
							return val > e.val;
					}
					bool isBiggerOrEqThan (Expr e)
					{
						if (val.type == typeid(uint))
							return val.get!uint() >= e.val.get!uint;
						else
							return val >= e.val;
					}
			}
			abstract class TplEl
			{
				abstract string execute ();
				string opCall ()
				{
					return execute;
				}
			}
			class TplContent: TplEl
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
			class TplIfEl: TplEl
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
			class ScriptContext
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
		}
		/++
		 + Parsing
		 +/
		class AtomicExprParser: ContextParser!(Expr)
		{
			public:
				this ()
				{
					auto id = alpha >> *alnum;
					parser
						= string_("true")[{ context.val = Variant(true); }]
						| string_("false")[{ context.val = Variant(false); }]
						| uint_[(uint v){ context.val = Variant(v); }]
						| id[(string id){ context.val = this.outer.var(id); }]
						;
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
							>> (string_(">") | string_(">=") | string_("<") | string_("<="))[(string s){ op = s; }]
							>> *space
							>> atomicExpr[{
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
									default:
										assert(0);
								}
							}]
						)
						| atomicExpr[{ context.val = atomicExpr.context.val; }]
						;
				}
				
			unittest
			{
				auto tpl = new Tornado;
				scope t = new Test!(tpl.ExprParser);
				auto p = tpl.new ExprParser;
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
			public:
				this (ScriptParser* script)
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
					auto expr = new ExprParser();
					parser
						= (doBlockBgn
						>> *space
						>> string_("if")
						>> +space
						>> expr[{ context.expr = expr.context; }]
						>> *space
						>> doBlockEnd
						>> lazy_(script)[{ context.ifEls = script.context.els; }]
						>> ~(elseStmt >> lazy_(script)[{ context.elseEls = script.context.els; }])
						>> endIfStmt
						)
						;
				}

			unittest
			{
				scope t = new Test!IfStmtParser;
				auto tpl = new Tornado;
				auto p = tpl.new IfStmtParser(&tpl.parser);
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
			public:
				IfStmtParser ifStmt;
				this ()
				{
					auto commentBlockBgn = string_("{#");
					auto commentBlockEnd = string_("#}");
					auto comment =  commentBlockBgn >> *(-commentBlockEnd) >> commentBlockEnd;
					ifStmt = new IfStmtParser(&this.outer.parser);
					parser
						= (
						*	( comment
							| ifStmt[{ context.appendElement(ifStmt.context); }]
							| (anychar - (doBlockBgn | commentBlockBgn))[(char ch){ context.appendContent(ch); }]
							)
						)[{ context.closeContentBlock; context.els.length = context.elsCnt; }]
						;
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
		static Parser doBlockBgn, doBlockEnd;
		struct VariantProxy
		{
			Variant v;
			this (Variant v)
			{
				this.v = v;
			}
		}
		VariantProxy[string] vars;
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
		static this ()
		{
			doBlockBgn = string_("{%");
			doBlockEnd = string_("%}");
		}
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			parser = new ScriptParser();
		}
		string fetchString (string s)
		{
			auto context = new ScriptContext;
			auto s2 = s.idup;
			if (!parser(s2, context) || s2.length)
				throw new Exception("invalid template");
			return executeScript(context.els);
		}
		bool assign (Type) (string id, Type val)
		{
			static if (is(Type == Variant))
				vars[id] = *new VariantProxy(val);
			else
				vars[id] = *new VariantProxy(Variant(val));
			return true;
		}
		Variant var (string id)
		{
			auto val = id in vars;
			return (val is null)? Variant(null) : (*val).v;
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
	}
}
