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
			bool assign (string, Variant);
}

class Tornado: Templater
{
	protected:
		/++
		 + Execution
		 +/
		static
		{
			abstract class Expr
			{
				public:
					abstract bool asBool ();
			}
			class BoolExpr: Expr
			{
				public:
					bool val;
					bool asBool ()
					{
						return this.val;
					}
			}
			abstract class TplEl
			{
				abstract string execute ();
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
						return this.content;
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
						foreach (el; expr.asBool? ifEls : elseEls)
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
						if (contentBlockCnt >= contentBlock.length)
							contentBlock.length = contentBlock.length * 2 + 1;
						contentBlock[contentBlockCnt++] = ch;
					}
					void closeContentBlock ()
					{
						if (contentBlockCnt)
						{
							appendElement(new TplContent(contentBlock[0 .. contentBlockCnt].idup));
							contentBlockCnt = 0;
						}
					}
					void appendElement (TplEl el)
					{
						if (elsCnt >= els.length)
							els.length = els.length * 2 + 1;
						els[elsCnt++] = el;
					}
			}
		}
		/++
		 + Parsing
		 +/
		class ExprParser: ContextParser!(BoolExpr)
		{
			public:
				this ()
				{
					parser
						= string_("true")[{ context.val = true; }]
						| string_("false")[{ context.val = false; }]
						;
				}
		}
		class IfStmtParser: ContextParser!(TplIfEl)
		{
			public:
				this ()
				{
					auto elseStmt
						= doBlockBgn
						>> *space
						>> string_("else").trace("else")
						>> *space
						>> doBlockEnd
						;
					auto endIfStmt
						= doBlockBgn
						>> *space
						>> string_("endif").trace("endif")
						>> *space
						>> doBlockEnd
						;
					auto expr = new ExprParser();
					parser
						= (doBlockBgn
						>> *space
						>> string_("if").trace("if")
						>> +space
						>> expr[{ context.expr = expr.context; }]
						>> *space
						>> doBlockEnd
						>> lazy_(&script)[{ context.ifEls = script.context.els; }]
						>> ~(elseStmt.trace("elseStmt") >> lazy_(&script))[{ context.elseEls = script.context.els; }]
						>> endIfStmt.trace("endIfStmt")
						)
						;
				}
		}
		class ScriptParser: ContextParser!(ScriptContext)
		{
			public:
				this ()
				{
					auto commentBlockBgn = string_("{#");
					auto commentBlockEnd = string_("#}");
					auto comment =  commentBlockBgn >> *(-commentBlockEnd) >> commentBlockEnd;
					parser
						= (
						*	( comment
							| ifStmt.trace("ifStmt")[{ context.appendElement(ifStmt.context); }]
							| (anychar - (doBlockBgn | commentBlockBgn)).trace("anychar")[(char ch){ context.appendContent(ch); }]
							)
						).trace("script")[{ context.closeContentBlock; context.els.length = context.elsCnt; }]
						;
				}
		}
		ScriptParser script;
		IfStmtParser ifStmt;
		Parser doBlockBgn, doBlockEnd, parser;
		ScriptContext context;
		string executeScript (TplEl[] els)
		{
			writeln(els);
			auto res = "";
			foreach (el; els)
			{
				writefln("executing %s", el);
				res ~= el.execute;
			}
			return res;
		}
	public:
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			doBlockBgn = string_("{%");
			doBlockEnd = string_("%}");
			ifStmt = new IfStmtParser();
			script = new ScriptParser();
			parser = script[{ context = script.context; }];
		}
		string fetchString (string s)
		{
			if (!parser(s) || s.length)
				throw new Exception("invalid template");
			writeln(script.context.els.length);
			return executeScript(script.context.els);
		}
		bool assign (string, Variant) {return true;}
}

unittest
{
	scope t = new Test!Tornado();
	auto tpl = new Tornado();
	auto p = tpl.new IfStmtParser();
	auto s = "{% if true %}{% endif %}";
	assert(p(s));
	s = "{% if false %}abc{% else %}def{% endif %}";
	assert(p(s));
}
