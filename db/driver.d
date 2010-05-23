/**
 * MySQL driver
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.driver;

import std.variant, std.regex, std.stdarg, std.conv;
import db.db, fixes;

class DbError : Error
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
		static string processPlaceholders (string expr, ...) @trusted
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
		
		abstract Select select (string[] fields ...) @safe;
		abstract SelectRow selectRow (string expr, ...) @safe;
		abstract SelectCell selectCell () @safe;
		abstract Insert insert (string expr, ...) @safe;
		abstract InsertRow insertRow () @safe;
		
		this (string host = null, string user = null, string passwd = null, string db = null, uint port = 0) @safe
		{
			this.host = host;
			this.user = user;
			this.passwd = passwd;
			this.db = db;
			this.port = port;
		}
		Update update (string table) @safe
		{
			return new Update(this, table);
		}
		UpdateRow updateRow (string table) @safe
		{
			return new UpdateRow(this, table);
		}
		Delete delete_ () @safe
		{
			return new Delete(this);
		}
		DeleteRow deleteRow () @safe
		{
			return new DeleteRow(this);
		}
		DropTable dropTable (string table) @safe
		{
			return new DropTable(this, table);
		}
		/+AddColumn addColumn () @safe const
		{
		}
		RemoveColumn removeColumn () @safe const
		{
		}+/
		typeof(this) beginTransaction () @safe
		{
			query("BEGIN");
			return this;
		}
		typeof(this) commit () @safe
		{
			query("COMMIT");
			return this;
		}
		typeof(this) rollback () @safe
		{
			query("ROLLBACK");
			return this;
		}
		
		string processPlaceholder (string placeholder, ...) @trusted const
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
						assert(false, "not implemented");
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
						assert(false, "not implemented");
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
						assert(false, "not implemented");
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
						assert(false, "not implemented");
					return res;
				case "?v":
					assert(false, "not implemented");
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
					assert(false, "invalid placeholder");
			}
		}
		
		abstract:
			bool query (string q) @safe;
			uint errorNum () @safe const;
			string errorMsg () @safe const;
			ulong rowsAffected () @safe const;
			bool selectDb (string db) @safe;
			VariantProxy[string] fetchRow (string q) @safe;
			VariantProxy[string][] fetchAll (string q) @safe;
			Variant fetchCell (string q) @safe;
			string escape (string s) @safe const;
			ulong insertId () @safe const;
}
