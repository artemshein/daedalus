/**
 * Database interface
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.db;

import std.variant, std.string, std.typetuple, std.conv;
import config, db.driver, fixes, strings;

version(MySQL) import db.mysql.driver;

struct Expr
{
	string expr;
	Variant[] values;
}

SqlDriver dbConnect (string dsn) @trusted
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
	struct Limit
	{
		uint from, to;
	}
	
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
	
@safe:

	typeof(this) joinInner (string[string] table, string condition, ...)
	{
		joins["inner"] ~= new Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinOuter (string[string] table, string condition, ...)
	{
		joins["outer"] ~= new Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinLeft (string[string] table, string condition, ...)
	{
		joins["left"] ~= new Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinRight (string[string] table, string condition, ...)
	{
		joins["right"] ~= new Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinFull (string[string] table, string condition, ...)
	{
		joins["full"] ~= new Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinCross (string[string] table, string condition, ...)
	{
		joins["cross"] ~= new Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
		return this;
	}
	
	typeof(this) joinNatural (string[string] table, string condition, ...)
	{
		joins["natural"] ~= new Join(table.keys[0], table.values[0], condition, packArgs(_arguments, _argptr));
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
		super(db, fields);
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
	Expr[] sets;
	
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
		if (to)
			limitCondition = Tuple!(uint, from, uint, to);
		else
			limitCondition = Tuple!(uint, 0, uint, from);
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
		if (to)
			limitCondition = Tuple!(uint, from, uint, from + 1);
		else
			limitCondition = Tuple!(uint, 0, uint, 1);
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
		if (to)
			limitCondition = Tuple!(uint, from, uint, to);
		else
			limitCondition = Tuple!(uint, 0, uint, from);
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
		if (to)
			limitCondition = Tuple!(uint, from, uint, from + 1);
		else
			limitCondition = Tuple!(uint, 0, uint, 1);
		return this;
	}
	typeof(this) limitPage (uint page, uint onPage)
	{
		throw new Error("not implemented", __FILE__, __LINE__);
	}
}

class DropTable
{
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
	const
	string asSql ()
	{
		db.processPlaceholders("DROP TABLE ?#", table);
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
			string[string] params;
		}
		struct Constraint
		{
			string name, table, field, onUpdate, onDelete;
		}
	}
	
	abstract const
	string asSql ();
	
	bool opCall ()
	{
		return db.query(asSql);
	}
	typeof(this) field (string name, string type, string[string] params)
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
