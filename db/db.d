module db.db;

import std.variant, std.string, std.typetuple;
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
		abstract string asSql () @safe const;
		
		typeof(this) into (string table) @safe
		{
			this.table = table;
			return this;
		}
		typeof(this) values (...) @safe
		{
			this.values_ ~= packArguments(_arguments, _argptr);
			return this;
		}
		bool opCall () @safe
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
		abstract string asSql () @safe const;
		
		typeof(this) into (string table) @safe
		{
			this.table = table;
			return this;
		}
		typeof(this) set (string expr, ...) @safe
		{
			sets ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		bool opCall () @safe
		{
			return db.query(asSql);
		}
}

abstract class BaseSelect
{
	protected:
		SqlDriver db;
		string[string] fields_, tables;
		Join[][string] joins;
		Expr[] whereConditions, orWhereConditions;
		string[] orderConditions;
		TypeTuple!(uint, uint) limitCondition;
		
	public:
		static struct Join
		{
			string table;
			string tableAlias;
			string condition;
			Variant[] values;
		}
		
		abstract string asSql () @safe const;
		
		this (SqlDriver db, string[] fields)
		{
			this.db = db;
			this.fields = fields;
			joins["inner"] = (Join[]).init;
		}
		this (SqlDriver db, string[] fields ...)
		{
			this(db, fields);
		}
		typeof(this) from (string[] tables ...) @safe
		{
			foreach (table; tables)
				this.tables[table] ~= table;
			return this;
		}
		typeof(this) from (string[string] tables) @safe
		{
			foreach (name, table; tables)
				this.tables[name] = table;
			return this;
		}
		typeof(this) fields (string[] fields ...) @safe
		{
			foreach (field; fields)
				this.fields_[field] = field;
			return this;
		}
		typeof(this) fields (string[string] fields) @safe
		{
			this.fields_ ~= fields;
			return this;
		}
		typeof(this) where (string expr, ...) @safe
		{
			whereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) orWhere (string expr, ...) @safe
		{
			orWhereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) order (string[] orders ...) @safe
		{
			orderConditions ~= orders;
			return this;
		}
		typeof(this) limit (uint from, uint to = 0) @safe
		{
			if (to)
				limitCondition = Tuple!(uint, from, uint, to);
			else
				limitCondition = Tuple!(uint, 0, uint, from);
			return this;
		}
		typeof(this) limitPage (uint page, uint onPage) @safe
		{
			return limit((page - 1) * onPage, page * onPage);
		}
		/+typeof(this) joinInternalProcess (string joinType, string[string] joinTable, string[] condition, string[string] fields)
		{
			auto tbl = joinTable.values[0];
			// Condition
			auto cndStr = db.processPlaceholders(condition[0], condition[1..$]);
			bool founded;
			foreach (v; tables)
				if (tbl == v)
				{
					founded = true;
					break;
				}
			if (!founded)
				foreach (v; joins[joinType])
					if (v.values[0] == tbl)
					{
						founded = true;
						
						v[2] = "("..v[2].." OR "..condition..")"
						break
					}
			if not founded then
				table.insert(joinType, {joinTable, condition})
			end
		}+/
		typeof(this) join (string[string] table, string condition, ...) @safe
		{
			return joinInner(table, condition, packArgs(_argument, _argptr));
		}
		typeof(this) joinInner (string[string] table, string condition, ...) @safe
		{
			return joinInternalProcess(joins["inner"], table, condition, packArgs(_arguments, _argptr));
		}
		typeof(this) joinOuter (string[string] table, string condition, ...) @safe
		{
			return joinInternalProcess(joins["outer"], table, condition, packArgs(_arguments, _argptr));
		}
		typeof(this) joinLeft (string[string] table, string condition, ...) @safe
		{
			return joinInternalProcess(joins["left"], table, condition, packArgs(_arguments, _argptr));
		}
		typeof(this) joinRight (string[string] table, string condition, ...) @safe
		{
			return joinInternalProcess(joins["right"], table, condition, packArgs(_arguments, _argptr));
		}
		typeof(this) joinFull (string[string] table, string condition, ...) @safe
		{
			return joinInternalProcess(joins["full"], table, condition, packArgs(_arguments, _argptr));
		}
		typeof(this) joinCross (string[string] table, string condition, ...) @safe
		{
			return joinInternalProcess(joins["cross"], table, condition, packArgs(_arguments, _argptr));
		}
		typeof(this) joinNatural (string[string] table, string condition, ...) @safe
		{
			return joinInternalProcess(joins["natural"], table, condition, packArgs(_arguments, _argptr));
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
		this (SqlDriver db, string[] fields)
		{
			super(db, fields);
		}
		this (SqlDriver db, string[] fields ...)
		{
			super(db, fields);
		}
		VariantProxy[string][] opCall () @safe
		{
			return db.fetchAll(asSql);
		}
}

abstract class SelectRow: BaseSelect
{
	public:
		this (SqlDriver db, string[] fields)
		{
			super(db, fields);
		}
		this (SqlDriver db, string[] fields ...)
		{
			super(db, fields);
		}
		VariantProxy[string] opCall () @safe
		{
			return db.fetchRow(asSql);
		}
}

abstract class SelectCell: BaseSelect
{
	public:
		this (SqlDriver db, string field)
		{
			super(db, fields);
		}
		Variant opCall () @safe
		{
			return db.fetchCell(asSql);
		}
}

class Update
{
	protected:
		string table;
		Expr[] sets;
		
	public:
		this (SqlDriver db, string table) @safe
		{
			this.db = db;
			this.table = table;
		}
		typeof(this) set (string expr, ...) @safe
		{
			sets ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) where (string expr, ...) @safe
		{
			whereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) orWhere (string expr, ...) @safe
		{
			orWhereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) order (string[] orders ...) @safe
		{
			orderConditions ~= orders;
			return this;
		}
		typeof(this) limit (uint from, uint to = 0) @safe
		{
			if (to)
				limitCondition = Tuple!(uint, from, uint, to);
			else
				limitCondition = Tuple!(uint, 0, uint, from);
			return this;
		}
		typeof(this) limitPage (uint page, uint onPage) @safe
		{
			return limit((page - 1) * onPage, page * onPage);
		}
		bool opCall () @safe
		{
			return db.query(asSql);
		}
}

class UpdateRow: Update
{
	public:
		this (SqlDriver db, string table) @safe
		{
			super(db, table);
		}
		typeof(this) limit (uint from, uint to = 0) @safe
		{
			if (to)
				limitCondition = Tuple!(uint, from, uint, from + 1);
			else
				limitCondition = Tuple!(uint, 0, uint, 1);
			return this;
		}
		typeof(this) limitPage (uint page, uint onPage) @safe
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
		this (SqlDriver db) @safe
		{
			this.db = db;
		}
		typeof(this) from (string table) @safe
		{
			this.table = table;
			return this;
		}
		typeof(this) where (string expr, ...) @safe
		{
			whereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) orWhere (string expr, ...) @safe
		{
			orWhereConditions ~= Expr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) order (string[] orders ...) @safe
		{
			orderConditions ~= orders;
			return this;
		}
		typeof(this) limit (uint from, uint to = 0) @safe
		{
			if (to)
				limitCondition = Tuple!(uint, from, uint, to);
			else
				limitCondition = Tuple!(uint, 0, uint, from);
			return this;
		}
		typeof(this) limitPage (uint page, uint onPage) @safe
		{
			return limit((page - 1) * onPage, page * onPage);
		}
		bool opCall () @safe
		{
			return db.query(asSql);
		}
}

class DeleteRow: Delete
{
	public:
		this (SqlDriver db) @safe
		{
			super(db);
		}
		typeof(this) limit (uint from, uint to = 0) @safe
		{
			if (to)
				limitCondition = Tuple!(uint, from, uint, from + 1);
			else
				limitCondition = Tuple!(uint, 0, uint, 1);
			return this;
		}
		typeof(this) limitPage (uint page, uint onPage) @safe
		{
			assert(false, "not implemented");
		}
}

class DropTable
{
	public:
		this (SqlDriver db, string table) @safe
		{
			this.db = db;
			this.table = table;
		}
		bool opCall () @safe
		{
			return db.query(asSql);
		}
		string asSql () @safe const
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
		static struct Field
		{
			string name;
			string type;
			string[string] params;
		}
		static struct Constraint
		{
			string name, table, field, onUpdate, onDelete;
		}
		
		abstract string asSql () @safe const;
		
		bool opCall () @safe
		{
			return db.query(asSql);
		}
		typeof(this) field (string name, string type, string[string] params) @safe
		{
			fields ~= Field(name, type, params);
			return this;
		}
		typeof(this) uniqueTogether (string[] fields) @safe
		{
			unique ~= fields;
			return this;
		}
		typeof(this) option (string key, string value) @safe
		{
			options[key] = value;
			return this;
		}
		typeof(this) constraint (string name, string table, string field, string onUpdate, string onDelete) @safe
		{
			constraints ~= Constraint(name, table, field, onUpdate, onDelete);
			return this;
		}
		typeof(this) primaryKey (string[] fields ...) @safe
		{
			primaryKey_ = fields;
			return this;
		}
}
