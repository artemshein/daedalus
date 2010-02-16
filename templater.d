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
		abstract class TplElement
		{
		}
		class TplContent: TplElement
		{
			public:
				string content;
				this (string content)
				{
					this.content = content;
				}
		}
		class TplIfElement: TplElement
		{
		}
		class IfStatementParser: ContextParser
		{
			protected:
				class ElseStatementParser: ContextParser
				{
					this ()
					{
						parser
							= doBlockBegin
							>> *space
							>> string_("else")
							>> *space
							>> doBlockEnd
							;
					}
				}
				class EndIfStatementParser: ContextParser
				{
					this ()
					{
						parser
							= doBlockBegin
							>> *space
							>> string_("endif")
							>> *space
							>> doBlockEnd
							;
					}
				}
				TplIfElement element;
			public:
				this ()
				{
					auto elseStatement = new ElseStatementParser();
					auto endIfStatement = new EndIfStatementParser();
					auto expression = space;
					parser
						= (doBlockBegin
						>> *space
						>> string_("if")
						>> +space
						//>> expression
						>> *space
						>> doBlockEnd
						>> lazy_(&script)
						>> ~(elseStatement >> script)
						>> endIfStatement
						)[{ element = new TplIfElement(); }]
						;
				}
		}
		class ScriptParser: ContextParser
		{
			public:
				TplElement[] elements;
				uint elsCnt;
				uint contentBlockCnt;
				char[] contentBlock;
				void appendContent (char ch)
				{
					debug(templater) writefln("Appending %s", ch);
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
				void appendElement (TplElement el)
				{
					if (elsCnt >= elements.length)
						elements.length = elements.length * 2 + 1;
					elements[elsCnt++] = el;
				}
				this ()
				{
					auto comment = string_("{#") >> *(-string_("#}")) >> string_("#}");
					parser
						= (
						*	( comment
							| ifStatement[{ appendElement(ifStatement.element); }]
							| anychar[&appendContent]
							)
						)[{ closeContentBlock; elements.length = elsCnt; }]
						;
				}
				bool parse (ref string s, Parser skipParser = null)
				{
					elsCnt = 0;
					contentBlockCnt = 0;
					return super.parse(s, skipParser);
				}
		}
		ScriptParser script;
		IfStatementParser ifStatement;
		Parser doBlockBegin, doBlockEnd;
	public:
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			doBlockBegin = string_("{%");
			doBlockEnd = string_("%}");
			ifStatement = trace(new IfStatementParser(), "ifStatement");
			script = new ScriptParser();
		}
		string fetchString (string s)
		{
			if (!script(s) || s.length)
				throw new Exception("invalid template");
			debug(templater) writefln("Elements.length = %d", script.elements.length);
			return to!(string)(script.elements);//executeScript(parser.elements);
		}
		bool assign (string, Variant) {return true;}
}
