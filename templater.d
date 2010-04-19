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
						writeln("appending content ", ch);
						if (contentBlockCnt >= contentBlock.length)
							contentBlock.length = contentBlock.length * 2 + 1;
						contentBlock[contentBlockCnt++] = ch;
						writeln("now content = ", contentBlock[0 .. contentBlockCnt]);
					}
					void closeContentBlock ()
					{
						writeln("closing context");
						if (contentBlockCnt)
						{
							appendElement(new TplContent(contentBlock[0 .. contentBlockCnt].idup));
							contentBlockCnt = 0;
						}
					}
					void appendElement (TplEl el)
					{
						writeln("appending element");
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
				
			unittest
			{
				auto tpl = new Tornado;
				scope t = new Test!(tpl.ExprParser);
				auto p = tpl.new ExprParser;
				auto s = "true";
				auto context = new BoolExpr;
				assert(p(s, context));
				assert(context.val);
				s = "false";
				assert(p(s, context));
				assert(!context.val);
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
						>> lazy_(script)[{ writeln("context.ifEls = ", script.context.els.length); context.ifEls = script.context.els; }]
						>> ~(elseStmt >> lazy_(script)[{ writeln("context.elseEls = ", script.context.els.length); context.elseEls = script.context.els; }])
						>> endIfStmt
						)
						;
				}

			unittest
			{
				scope t = new Test!IfStmtParser;
				auto tpl = new Tornado();
				auto p = tpl.new IfStmtParser(&tpl.parser);
				auto s = "{% if true %}{% endif %}";
				auto context = new TplIfEl;
				assert(p(s, context));
				assert(context.expr.asBool);
				s = "{% if false %}abc{% else %}def{% endif %}";
				assert(p(s, context));
				assert(!context.expr.asBool);
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
					ifStmt = new IfStmtParser(&this);
					parser
						= (
						*	( comment
							| ifStmt[{ writeln("context.appendElement ", ifStmt.context); context.appendElement(ifStmt.context); }]
							| (anychar - (doBlockBgn | commentBlockBgn))[(char ch){ writeln("context.appendContent ", ch); context.appendContent(ch); }]
							)
						)[{ writeln("context.closeContentBlock ", context.elsCnt); context.closeContentBlock; context.els.length = context.elsCnt; }]
						;
				}
				
			unittest
			{
				auto tpl = new Tornado;
				scope t = new Test!ScriptParser;
				auto s = "{% if true %}yes{% else %}no{% endif %}";
				auto p = tpl.new ScriptParser;
				p.trace("script");
				auto context = new ScriptContext;
				assert(p(s, context));
				assert(5 == context.els.length);
			}
		}
		static Parser doBlockBgn, doBlockEnd;
		ScriptParser parser;
		ScriptContext context;
		string executeScript (TplEl[] els)
		{
			//writeln(els);
			auto res = "";
			foreach (el; els)
			{
				writefln("executing %s", el);
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
			writeln(context.els.length);
			return executeScript(context.els);
		}
		bool assign (string, Variant) {return true;}
		
	unittest
	{
		auto tpl = new Tornado;
		scope t = new Test!Tornado;
		auto s = "{% if true %}yes{% else %}no{% endif %}";
		//assert("yes" == tpl.fetchString(s));
	}
}
