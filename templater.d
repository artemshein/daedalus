module templater;

import std.variant, std.file;
import http.wsapi : WsApi;
import parser;

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
			string content;
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
			this (Statement statement)
			{
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
					>> string_("%}")[{ doBlock = new TplDoBlock(statement.statement); }]
					;
			}
		}
		DoBlockParser doBlock;
		Parser doBlock = void, printBlock = void, commentBlock = void, parser = void;
		TplElement[] elements;
		uint elsCnt;
	public:
		this (string[] tplsDirs = null, WsApi ws = null)
		{
			super(tplsDirs, ws);
			auto doBlock = new DoBlockParser();
			printBlock = string_("{{") >> string_("}}");
			commentBlock = string_("{#") >> *(-string_("#}")) >> string_("#}");
			bool contentFlag = true;
			char[] contentBlock;
			uint contentBlockCnt;
			void appendContent (char ch)
			{
			}
			parser
				= *	(commentBlock[{ contentFlag = false; }]
					| doBlock[{ contentFlag = false; appendElement(doBlock.doBlock); }]
					| anychar[(char ch) { if (!contentFlag) { elements.length} contentBlock.length += 1; contentBlock[$ - 1] = ch; }]
					)
				>> end
				;
		}
		void appendElement (TplElement el)
		{
			if (elsCnt >= elements.length)
				elements.length = elements.length * 2 + 1;
			elements[elsCnt++] = el;
		}
		string fetchString (string s)
		{
			contentBlock.length = 0;
			auto res = parser(s);
			if (NoMatch == res)
				throw new Exception("invalid template");
			return contentBlock.idup;
		}
		bool assign (string, Variant) {return true;}
}
