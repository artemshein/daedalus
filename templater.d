module templater;

debug = templater;

import std.variant, std.file, std.conv;
import http.wsapi : WsApi;
import parser;
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
		abstract class Expr
		{
			public:
				abstract bool asBool ();
		}
		class BoolExpr: Expr
		{
			public:
				bool value;
				this (bool value)
				{
					this.value = value;
				}
				bool asBool ()
				{
					return this.value;
				}
		}
		class ExprParser: ContextParser!(BoolExpr)
		{
			public:
				this ()
				{
					parser
						= string_("true")[{ context = new BoolExpr(true); }]
						| string_("false")[{ context = new BoolExpr(false); }]
						;
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
				this (Expr expr, TplEl[] ifEls, TplEl[] elseEls)
				{
					this.expr = expr;
					this.ifEls = ifEls;
					this.elseEls = elseEls;
				}
				string execute ()
				{
					auto res = "";
					foreach (el; expr.asBool? ifEls : elseEls)
						res ~= el.execute;
					return res;
				}
		}
		/++
		 + Parsing
		 +/
		class IfStmtParser: ContextParser!(TplIfEl)
		{
			public:
				this ()
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
					TplEl[] ifEls, elseEls;
					parser
						= (doBlockBgn
						>> *space
						>> string_("if")
						>> +space
						>> expr
						>> *space
						>> doBlockEnd
						>> lazy_(&script)[{ ifEls = script.context.els; }]
						>> ~(elseStmt >> script[{ elseEls = script.context.els; }])
						>> endIfStmt
						)[{ context = new TplIfEl(expr.context, ifEls, elseEls); }]
						;
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
		}
		class ScriptParser: ContextParser!(ScriptContext)
		{
			public:
				void appendContent (char ch)
				{
					with (context)
					{
						if (contentBlockCnt >= contentBlock.length)
							contentBlock.length = contentBlock.length * 2 + 1;
						contentBlock[contentBlockCnt++] = ch;
					}
				}
				void closeContentBlock ()
				{
					with (context) if (contentBlockCnt)
					{
						appendElement(new TplContent(contentBlock[0 .. contentBlockCnt].idup));
						contentBlockCnt = 0;
					}
				}
				void appendElement (TplEl el)
				{
					with (context)
					{
						if (elsCnt >= els.length)
							els.length = els.length * 2 + 1;
						els[elsCnt++] = el;
					}
				}
				this ()
				{
					auto commentBlockBgn = string_("{#");
					auto commentBlockEnd = string_("#}");
					auto comment =  commentBlockBgn >> *(-commentBlockEnd) >> commentBlockEnd;
					parser
						= (
						*	( comment
							| ifStmt[{ appendElement(ifStmt.context); }]
							| (anychar - (doBlockBgn | commentBlockBgn))[&appendContent]
							)
						)[{ closeContentBlock; context.content.length = context.elsCnt; }]
						;
				}
				bool parse (ref string s, Parser skipParser = null)
				{
					context = new ScriptContext();
					with (context)
					{
						elsCnt = 0;
						contentBlockCnt = 0;
					}
					return super.parse(s, context, skipParser);
				}
		}
		ScriptParser script;
		IfStmtParser ifStmt;
		Parser doBlockBgn, doBlockEnd;
		string executeScript (TplEl[] els)
		{
			auto res = "";
			foreach (el; els)
				res ~= el.execute;
			return res;
		}
	public:
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			doBlockBgn = string_("{%");
			doBlockEnd = string_("%}");
			script = new ScriptParser();
			ifStmt = new IfStmtParser();
		}
		string fetchString (string s)
		{
			if (!script(s) || s.length)
				throw new Exception("invalid template");
			return executeScript(script.els);
		}
		bool assign (string, Variant) {return true;}
}
