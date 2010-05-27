/**
 * MySQL driver
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.driver;

import std.variant, std.regex, std.stdarg, std.conv, std.typetuple, std.string;
import fixes, strings;

version(MySQL) import db.mysql.driver;

class DbError: Error
{
	this (string s) @trusted
	{
		super(s);
	}
}

struct Expr
{
	string expr;
	Variant[] values;
}

struct Limit
{
	uint from, to;
}

@trusted
SqlDriver dbConnect (string dsn)
{
	string[string] params;
	auto v = dsn.splitBy("://", "/", "?");
	string driver, host, database, paramsStr;
	switch (v.length)
	{
		case 4:
			paramsStr = v[3];
		case 3:
			database = v[2];
		case 2:
			host = v[1];
		case 1:
			driver = v[0];
			break;
		default:
			assert(false, "invalid dsn");
	}
	string login, pass;
	v = host.split("@");
	if (1 < v.length)
	{
		login = v[0];
		host = v[1];
		v = login.split(":");
		if (1 < v.length)
		{
			login = v[0];
			pass = v[1];
		}
	}
	string port;
	v = host.split(":");
	if (1 < v.length)
	{
		host = v[0];
		port = v[1];
	}
	string[] paramsArr;
	if (paramsStr.length)
		paramsArr = paramsStr.splitBy("&");

	foreach (param; paramsArr)
	{
		auto v2 = param.split("=");
		params[v2[0]] = v2[1];
	}

	switch (tolower(driver))
	{
	case "mysql":
		return new MysqlDriver(host, login, pass, database, to!ushort(port));
	default:
		assert(false, "unsupported driver");
	}
	assert(false);
}

abstract class Insert
{
protected:

	SqlDriver db;
	string fieldsExpr, table;
	string[string] fieldsNames;
	Variant[][] values_;

public:
@safe:

	abstract const
	string asSql ();
	
	typeof(this) into (string table)
	{
		this.table = table;
		return this;
	}
	typeof(this) values (...)
	{
		this.values_ ~= packArgs(_arguments, _argptr);
		return this;
	}
	bool opCall ()
	{
		return db.query(asSql);
	}
}

abstract class InsertRow
{
protected:

	SqlDriver db;
	string table;
	Expr[] sets;

public:
@safe:

	abstract const
	string asSql ();
	
	typeof(this) into (string table)
	{
		this.table = table;
		return this;
	}
	typeof(this) set (string expr, ...)
	{
		sets ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	bool opCall ()
	{
		return db.query(asSql);
	}
}

abstract class BaseSelect
{
public:

	static
	struct Join
	{
		string tableAlias;
		string table;
		string condition;
		Variant[] values;
	}
	
protected:

	SqlDriver db;
	string[string] fields_, tables;
	Join[][string] joins;
	Expr[] whereConditions, orWhereConditions;
	string[] orderConditions;
	Limit limitCondition;
	
public:
@safe:
	
	abstract const
	string asSql ();
	
	this (SqlDriver db, string[] fields)
	{
		this.db = db;
		this.fields = fields;
		joins["inner"] = (Join[]).init;
		joins["outer"] = (Join[]).init;
		joins["left"] = (Join[]).init;
		joins["right"] = (Join[]).init;
		joins["full"] = (Join[]).init;
		joins["cross"] = (Join[]).init;
		joins["natural"] = (Join[]).init;
	}
	
	this (SqlDriver db, string[] fields ...)
	{
		this(db, fields);
	}
	
	typeof(this) from (string[] tables ...)
	{
		foreach (table; tables)
			this.tables[table] ~= table;
		return this;
	}
	
	@trusted
	typeof(this) from (string[string] tables)
	{
		foreach (name, table; tables)
			this.tables[name] = table;
		return this;
	}
	
	typeof(this) fields (string[] fields ...)
	{
		foreach (field; fields)
			this.fields_[field] = field;
		return this;
	}
	
	@trusted
	typeof(this) fields (string[string] fields)
	{
		foreach (name, field; fields)
			this.fields_[name] = field;
		return this;
	}
	
	typeof(this) where (string expr, ...)
	{
		whereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) orWhere (string expr, ...)
	{
		orWhereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) order (string[] orders ...)
	{
		orderConditions ~= orders;
		return this;
	}
	
	typeof(this) limit (uint from, uint to = 0)
	{
		limitCondition.from = to? from : 0;
		limitCondition.to = to? to : from;
		return this;
	}
	
	typeof(this) limitPage (uint page, uint onPage)
	{
		return limit((page - 1) * onPage, page * onPage);
	}
	
	typeof(this) join (string[string] table, string condition, Variant[] values)
	{
		return joinInner(table, condition, values);
	}
	
	typeof(this) join (string[string] table, string condition, ...)
	{
		return joinInner(table, condition, packArgs(_arguments, _argptr));
	}
	
@trusted:

	typeof(this) joinInner (string[string] table, string condition, ...)
	{
		joins["inner"] ~= Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinOuter (string[string] table, string condition, ...)
	{
		joins["outer"] ~= Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinLeft (string[string] table, string condition, ...)
	{
		joins["left"] ~= Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinRight (string[string] table, string condition, ...)
	{
		joins["right"] ~= Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinFull (string[string] table, string condition, ...)
	{
		joins["full"] ~= Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinCross (string[string] table, string condition, ...)
	{
		joins["cross"] ~= Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinNatural (string[string] table, string condition, ...)
	{
		joins["natural"] ~= Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	/+
	joinInnerUsing = function (self, ...) table.insert(self._joinsUsing.inner, {...}) return self end;
	joinOuterUsing = function (self, ...) table.insert(self._joinsUsing.outer, {...}) return self end;
	joinLeftUsing = function (self, ...) table.insert(self._joinsUsing.left, {...}) return self end;
	joinRightUsing = function (self, ...) table.insert(self._joinsUsing.right, {...}) return self end;
	joinFullUsing = function (self, ...) table.insert(self._joinsUsing.full, {...}) return self end;+/
}

abstract class Select: BaseSelect
{
public:
@safe:

	this (SqlDriver db, string[] fields)
	{
		super(db, fields);
	}
	this (SqlDriver db, string[] fields ...)
	{
		super(db, fields);
	}
	VariantProxy[string][] opCall ()
	{
		return db.fetchAll(asSql);
	}
}

abstract class SelectRow: BaseSelect
{
public:
@safe:

	this (SqlDriver db, string[] fields)
	{
		super(db, fields);
	}
	this (SqlDriver db, string[] fields ...)
	{
		super(db, fields);
	}
	VariantProxy[string] opCall ()
	{
		return db.fetchRow(asSql);
	}
}

abstract @safe class SelectCell: BaseSelect
{
public:

	this (SqlDriver db, string field)
	{
		super(db, field);
	}
	Variant opCall ()
	{
		return db.fetchCell(asSql);
	}
}

class Update
{
protected:

	SqlDriver db;
	string table;
	Expr[] sets, whereConditions, orWhereConditions;
	string[] orderConditions;
	Limit limitCondition;
	
public:
@safe:

	this (SqlDriver db, string table)
	{
		this.db = db;
		this.table = table;
	}
	
	typeof(this) set (string expr, ...)
	{
		sets ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) where (string expr, ...)
	{
		whereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) orWhere (string expr, ...)
	{
		orWhereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) order (string[] orders ...)
	{
		orderConditions ~= orders;
		return this;
	}
	
	typeof(this) limit (uint from, uint to = 0)
	{
		limitCondition.from = to? from : 0;
		limitCondition.to = to? to : from;
		return this;
	}
	
	typeof(this) limitPage (uint page, uint onPage)
	{
		return limit((page - 1) * onPage, page * onPage);
	}
	
	bool opCall ()
	{
		return db.query(asSql);
	}
	
abstract:

	const
	string asSql ();
}

class UpdateRow: Update
{
public:
@safe:

	this (SqlDriver db, string table)
	{
		super(db, table);
	}
	
	typeof(this) limit (uint from, uint to = 0)
	{
		limitCondition.from = to? from : 0;
		limitCondition.to = to? (from + 1) : 1;
		return this;
	}
	
	typeof(this) limitPage (uint page, uint onPage)
	{
		return limit((page - 1) * onPage, (page - 1) * onPage + 1);
	}
}

class Delete
{
protected:

	SqlDriver db;
	string table;
	Expr[] whereConditions, orWhereConditions;
	string[] orderConditions;
	Limit limitCondition;
	
public:
@safe:

	this (SqlDriver db)
	{
		this.db = db;
	}
	
	typeof(this) from (string table)
	{
		this.table = table;
		return this;
	}
	
	typeof(this) where (string expr, ...)
	{
		whereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) orWhere (string expr, ...)
	{
		orWhereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) order (string[] orders ...)
	{
		orderConditions ~= orders;
		return this;
	}
	
	typeof(this) limit (uint from, uint to = 0)
	{
		limitCondition.from = to? from : 0;
		limitCondition.to = to? to : from;
		return this;
	}
	
	typeof(this) limitPage (uint page, uint onPage)
	{
		return limit((page - 1) * onPage, page * onPage);
	}
	
	bool opCall ()
	{
		return db.query(asSql);
	}
	
abstract:

	const
	string asSql ();
}

class DeleteRow: Delete
{
public:
@safe:

	this (SqlDriver db)
	{
		super(db);
	}
	
	typeof(this) limit (uint from, uint to = 0)
	{
		limitCondition.from = to? from : 0;
		limitCondition.to = to? (from + 1) : 1;
		return this;
	}
	
	typeof(this) limitPage (uint page, uint onPage)
	{
		throw new Error("not implemented", __FILE__, __LINE__);
	}
}

class DropTable
{
protected:

	SqlDriver db;
	string table;
	
public:
@safe:

	this (SqlDriver db, string table)
	{
		this.db = db;
		this.table = table;
	}
	bool opCall ()
	{
		return db.query(asSql);
	}
	
	const @trusted
	string asSql ()
	{
		return db.processPlaceholders("DROP TABLE ?#", table);
	}
}

class CreateTable
{
protected:

	SqlDriver db;
	string table;
	string[] primaryKey_;
	string[][] unique;
	string[string] options;
	Constraint[] constraints;
	Field[] fields;
	
public:
@safe:

	static
	{
		struct Field
		{
			string name;
			string type;
			Variant[string] options;
		}
		struct Constraint
		{
			string name, table, field, onUpdate, onDelete;
		}
	}
	
	abstract /*const*/
	string asSql ();
	
	bool opCall ()
	{
		return db.query(asSql);
	}
	typeof(this) field (string name, string type, Variant[string] params)
	{
		fields ~= Field(name, type, params);
		return this;
	}
	typeof(this) uniqueTogether (string[] fields)
	{
		unique ~= fields;
		return this;
	}
	typeof(this) option (string key, string value)
	{
		options[key] = value;
		return this;
	}
	typeof(this) constraint (string name, string table, string field, string onUpdate, string onDelete)
	{
		constraints ~= Constraint(name, table, field, onUpdate, onDelete);
		return this;
	}
	typeof(this) primaryKey (string[] fields ...)
	{
		primaryKey_ = fields;
		return this;
	}
}

abstract class SqlDriver
{
protected:

	string host, user, passwd, db;
	uint port;
	
public:

	@trusted const
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
		string limitSql (in Limit limitCondition);
		string valuesSql (in string placeholders, in Variant[][] values);
		string setsSql (in Expr[] sets);
		string fieldsDefsSql (/*in*/ CreateTable.Field[] fields);
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
	Update update (string table);
	UpdateRow updateRow (string table);
	Delete delete_ ();
	DeleteRow deleteRow ();
}
