module templater;

import std.variant, std.file;
import http.wsapi : WsApi;
import parser;

debug = templater;

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
			protected:
				uint offset;
			this (uint offset)
			{
				this.offset = offset;
			}
		}
		class TplContent: TplElement
		{
			string content;
			this (string content, uint offset = 0)
			{
				super(offset);
				this.content = content;
			}
		}
		abstract class Expression
		{
		}
		class BooleanExpression: Expression
		{
			bool value;
			this (bool value)
			{
				this.value = value;
			}
		}
		abstract class Statement
		{
		}
		class IfStatement: Statement
		{
			Expression expr;
			this (Expression expr)
			{
				this.expr = expr;
			}
		}
		class EndIfStatement: Statement
		{
		}
		class TplDoBlock: TplElement
		{
			Statement statement;
			this (Statement statement, uint offset = 0)
			{
				super(offset);
				this.statement = statement;
			}
		}
		class ExpressionParser: ContextParser
		{
			Expression expr = void;
			this ()
			{
				parser
					= string_("false")[{ expr = new BooleanExpression(false); }]
					| string_("true")[{ expr = new BooleanExpression(true); }]
					;
			}
		}
		class StatementParser: ContextParser
		{
			Statement statement = void;
			this ()
			{
				auto expr = new ExpressionParser();
				parser
					= (string_("if") >> *space >> expr)[{ statement = new IfStatement(expr.expr); }]
					| string_("endif")[{ statement = new EndIfStatement(); }]
					;
			}
		}
		class DoBlockParser: ContextParser
		{
			TplDoBlock doBlock = void;
			this ()
			{
				auto statement = new StatementParser();
				parser
					= string_("{%")
					>> *space
					>> statement
					>> *space
					>> string_("%}")[{ doBlock = new TplDoBlock(statement.statement, offset); }]
					;
			}
		}
		class TplParser: ContextParser
		{
			DoBlockParser doBlock;
			char[] contentBlock;
			uint contentBlockCnt;
			TplElement[] elements;
			uint elsCnt;
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
			void appendElement (TplElement el)
			{
				if (elsCnt >= elements.length)
					elements.length = elements.length * 2 + 1;
				elements[elsCnt++] = el;
			}
			this ()
			{
				doBlock = new DoBlockParser();
				auto printBlock = string_("{{") >> string_("}}");
				auto commentBlock = string_("{#") >> *(-string_("#}")) >> string_("#}");
				parser
					=
					*	(commentBlock
						| doBlock[{ closeContentBlock(); appendElement(doBlock.doBlock); }]
						| anychar[&appendContent]
						)
					>> end[{ closeContentBlock(); elements.length = elsCnt; }]
					;
			}
			MatchLen parse (string s, Parser skipParser = null)
			{
				elsCnt = 0;
				contentBlockCnt = 0;
				return super.parse(s, skipParser);
			}
		}
		TplParser parser;
		string executeScript (TplElements[] els)
		{
			string res;
			
			return res;
		}
	public:
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			parser = new TplParser();
		}
		string fetchString (string s)
		{
			auto res = parser(s);
			if (NoMatch == res)
				throw new Exception("invalid template");
			return executeScript(parser.elements);
		}
		bool assign (string, Variant) {return true;}
}
