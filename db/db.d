module db.db;

import std.variant, std.string;
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
		string[] fieldsNames;
		Variant[][] values_;
	
	public:
		abstract string asSql () @safe const;
		
		this (SqlDriver db, string expr, string[] fieldsNames ...) @safe
		{
			this.db = db;
			this.fieldsExpr = expr;
			this.fieldsNames = fieldsNames;
		}
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

class InsertRow
{
	protected:
		SqlDriver db;
		string table;
		Expr[] sets;
	
	public:
		abstract string asSql () @safe const;
		
		this (SqlDriver db) @safe
		{
			this.db = db;
		}
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
		string[] fields_, tables;
		
	public:
		abstract string asSql () @safe const;
		
		this (SqlDriver db, string[] fields ...)
		{
			this.db = db;
			this.fields = fields;
		}
		typeof(this) from (string[] tables ...) @safe
		{
			foreach (table; tables)
				this.tables ~= table;
			return this;
		}
		typeof(this) from (string[string] tables) @safe
		{
			foreach (tAlias, table; tables)
				this.tablesWithAliases[tAlias] = table;
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
			whereConditions ~= WhereExpr(expr, packArgs(_arguments, _argptr));
			return this;
		}
		typeof(this) orWhere (string expr, ...) @safe
		{
			orWhereConditions ~= WhereExpr(expr, packArgs(_arguments, _argptr));
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
		/+
	_joinInternalProcess = function (self, joinType, joinTable, condition, fields)
		local tbl = joinTable
		if "table" == type(tbl) then
			tbl = next(tbl)
		end
		-- Condition
		if "table" == type(condition) then
			condition = self._db:processPlaceholders(unpack(condition))
		end
		local founded
		for _, v in pairs(self._tables) do
			if v == joinTable then
				founded = true
				break
			end
		end
		if not founded then
			for _, v in ipairs(joinType) do
				if v[1] == joinTable then
					founded = true
					v[2] = "("..v[2].." OR "..condition..")"
					break
				end
			end
		end
		if not founded then
			table.insert(joinType, {joinTable, condition})
		end
	end;
	join = function (self, ...)
		return self:joinInner(...)
	end;
	joinInner = function (self, ...)
		self:_joinInternalProcess(self._joins.inner, ...)
		return self
	end;
	joinOuter = function (self, ...) table.insert(self._joins.outer, {...}) return self end;
	joinLeft = function (self, ...) table.insert(self._joins.left, {...}) return self end;
	joinRight = function (self, ...) table.insert(self._joins.right, {...}) return self end;
	joinFull = function (self, ...) table.insert(self._joins.full, {...}) return self end;
	joinCross = function (self, ...) table.insert(self._joins.cross, {...}) return self end;
	joinNatural = function (self, ...) table.insert(self._joins.natural, {...}) return self end;
	joinInnerUsing = function (self, ...) table.insert(self._joinsUsing.inner, {...}) return self end;
	joinOuterUsing = function (self, ...) table.insert(self._joinsUsing.outer, {...}) return self end;
	joinLeftUsing = function (self, ...) table.insert(self._joinsUsing.left, {...}) return self end;
	joinRightUsing = function (self, ...) table.insert(self._joinsUsing.right, {...}) return self end;
	joinFullUsing = function (self, ...) table.insert(self._joinsUsing.full, {...}) return self end;+/
}

abstract class Select: BaseSelect
{
	public:
		VariantProxy[string][] opCall () @safe
		{
			return db.fetchAll(asSql);
		}
}

abstract class SelectRow: BaseSelect
{
	public:
		VariantProxy[string] opCall () @safe
		{
			return db.fetchRow(asSql);
		}
}

abstract class SelectCell: BaseSelect
{
	public:
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
		
		SqlDriver db;
		string table;
		string[] primaryKey_;
		string[][] unique;
		string[string] options;
		Constraint[] constraints;
		
	public:
		abstract string asSql () @safe const;
		
		bool opCall () @safe
		{
			return db.query(asSql);
		}
		this (SqlDriver db, string table) @safe
		{
			this.db = db;
			this.table = table;
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
