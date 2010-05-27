/**
 * MySQL driver
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.driver;

import std.variant, std.regex, std.stdarg, std.conv, std.typetuple;
import db.db, fixes;

class DbError: Error
{
	this (string s) @trusted
	{
		super(s);
	}
}

abstract class SqlDriver
{
protected:

	string host, user, passwd, db;
	uint port;
	
public:

	static @trusted
	string processPlaceholders (string expr, ...)
	{
		string res;
		uint i;
		auto m = expr.match(regex("?[%#davnq]?"));
		while (!m.empty && i < _arguments.length)
		{
			Variant arg;
			auto argType = typeid(_arguments[i]);
			if (typeid(uint) == argType)
				arg = va_arg!uint(_argptr);
			else if (typeid(int) == argType)
				arg = va_arg!int(_argptr);
			else if (typeid(string) == argType)
				arg = va_arg!string(_argptr);
			else
				assert(false, "not implemented");
			res ~= m.pre ~ processPlaceholder(m.hit, arg);
			expr = m.post;
			m = expr.match(regex("?[%#davnq]?"));
			++i;
		}
		return res ~ expr;
	}
	
	abstract
	{
	@safe:
	
		Select select (string[] fields ...);
		SelectRow selectRow (string[] fields ...);
		SelectCell selectCell (string field);
		Insert insert (string expr, string[] fields ...);
		InsertRow insertRow ();
		
	const:
	
		string ordersSql (in string[] orders);
		string limitSql (in TypeTuple!(uint, uint) limitCondition);
		string valuesSql (in string placeholders, in Variant[][] values);
		string setsSql (in Expr[] sets);
		string fieldsDefsSql (in CreateTable.Field[] fields);
		string primaryKeySql (in string[] primary);
		string uniquesSql (in string[][] unique);
		string constraintsSql (in CreateTable.Constraint[] refs);
		string optionsSql (in string[string] options);
		
	@trusted:
	
		string fieldsSql (in string[string] fields, in string[string] tables);
		string fromsSql (in string[string] from);
		string joinsSql (in BaseSelect.Join[][string] joins);
		string wheresSql (in Expr[] where, in Expr[] orWhere);
	}

@safe:

	this (string host = null, string user = null, string passwd = null, string db = null, uint port = 0)
	{
		this.host = host;
		this.user = user;
		this.passwd = passwd;
		this.db = db;
		this.port = port;
	}
	Update update (string table)
	{
		return new Update(this, table);
	}
	UpdateRow updateRow (string table)
	{
		return new UpdateRow(this, table);
	}
	Delete delete_ ()
	{
		return new Delete(this);
	}
	DeleteRow deleteRow ()
	{
		return new DeleteRow(this);
	}
	DropTable dropTable (string table)
	{
		return new DropTable(this, table);
	}
	/+AddColumn addColumn () @safe const
	{
	}
	RemoveColumn removeColumn () @safe const
	{
	}+/
	typeof(this) beginTransaction ()
	{
		query("BEGIN");
		return this;
	}
	typeof(this) commit ()
	{
		query("COMMIT");
		return this;
	}
	typeof(this) rollback ()
	{
		query("ROLLBACK");
		return this;
	}
	
	@trusted const
	string processPlaceholder (string placeholder, ...)
	{
		auto type = _arguments[0];
		switch (placeholder)
		{
			case "?q":
				return "?";
			/+case "?":
				return "'"..string.gsub(tostring(value), "['?]", {["'"]="\\'";["?"]="?q"}).."'";+/
			case "?d":
				if (typeid(uint) == type)
					return to!string(va_arg!uint(_argptr));
				else if (typeid(int) == type)
					return to!string(va_arg!int(_argptr));
				else if (typeid(bool) == type)
					return va_arg!bool(_argptr)? "1" : "0";
				else if (typeid(string) == type)
					return to!string(to!int(va_arg!string(_argptr)));
				else
					throw new Error("not implemented", __FILE__, __LINE__);
			case "?#":
				if (typeid(string[]) == type)
				{
					string res;
					foreach (str; va_arg!(string[])(_argptr))
					{
						if (!res.length)
							res ~= ", ";
						res ~= processPlaceholder("?#", str);
					}
					return res;
				}
				else if (typeid(string) == type)
				{
					auto s = va_arg!string(_argptr);
					if (!s.match(regex("(")).empty)
						return s;
					if (!s.match(regex(".")).empty)
					{
						auto vals = s.split(regex("."));
						string res;
						foreach (val; vals)
						{
							if (!val.length)
								res ~= ".";
							if ("*" == val)
								res ~= "*";
							else
								res ~= processPlaceholder("?#", val);
						}
						return res;
					}
					else
						return escape(s);
				}
				else
					throw new Error("not implemented", __FILE__, __LINE__);
			case "?n":
				if (typeid(uint) == type)
				{
					auto v = va_arg!uint(_argptr);
					if (v)
						return processPlaceholder("?d", v);
					else
						return "NULL";
				}
				else if (typeid(int) == type)
				{
					auto v = va_arg!int(_argptr);
					if (v)
						return processPlaceholder("?d", v);
					else
						return "NULL";
				}
				else if (typeid(bool) == type)
					return processPlaceholder("?d", va_arg!bool(_argptr));
				else if (typeid(string) == type)
				{
					auto s = va_arg!string(_argptr);
					return s.length? processPlaceholder("?", s) : "NULL";
				}
				else
					throw new Error("not implemented", __FILE__, __LINE__);
			case "?a":
				string res;
				if (typeid(string[]) == type)
					foreach (str; va_arg!(string[])(_argptr))
					{
						if (!res.length)
							res ~= ", ";
						res ~= processPlaceholder("?", str);
					}
				else if (typeid(uint[]) == type)
					foreach (v; va_arg!(uint[])(_argptr))
					{
						if (!res.length)
							res ~= ", ";
						res ~= processPlaceholder("?d", v);
					}
				else if (typeid(int[]) == type)
					foreach (v; va_arg!(uint[])(_argptr))
					{
						if (!res.length)
							res ~= ", ";
						res ~= processPlaceholder("?d", v);
					}
				else
					throw new Error("not implemented", __FILE__, __LINE__);
				return res;
			case "?v":
				throw new Error("not implemented", __FILE__, __LINE__);
				/+
				 + local res = ""
		for k, v in pairs(value) do
			if res ~= "" then res = res..", " end
			res = res..self:processPlaceholder("?#", k)
			if type(v) == "number" then
				res = res.."="..self:processPlaceholder("?d", v)
			elseif type(v) == "string" then
				res = res.."="..self:processPlaceholder("?", v)
			else
				Exception"Invalid value type!"
			end
		end
		return res+/
			default:
				throw new Error("invalid placeholder", __FILE__, __LINE__);
		}
	}
		
abstract:
@safe:

	const
	{
		uint errorNum ();
		string errorMsg ();
		ulong rowsAffected ();
		string escape (string s);
		ulong insertId ();
	}
	
	bool query (string q);
	bool selectDb (string db);
	VariantProxy[string] fetchRow (string q);
	VariantProxy[string][] fetchAll (string q);
	Variant fetchCell (string q);
}
