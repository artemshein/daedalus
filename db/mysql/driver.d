/**
 * Database driver
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.mysql.driver;

import std.string, std.conv, std.variant, core.stdc.string, std.typetuple;
import db.driver, db.db, db.mysql.libmysqlclient, fixes;

version(unittest)
{
	import qc;
	enum string MYSQL_UNITTEST_HOST = null;
	enum string MYSQL_UNITTEST_USER = null;
	enum string MYSQL_UNITTEST_PASSWORD = null;
	enum string MYSQL_UNITTEST_DB = "unittest";
	enum uint MYSQL_UNITTEST_PORT = 3306;
}

class MysqlError: DbError
{
	this (string s) @safe
	{
		super(s);
	}
}

class MysqlSelect: Select
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
		string asSql () @safe const
		{
			return "SELECT " ~ db.constructFields(fields_, tables)
				~ db.constructFrom(tables) ~ db.constructJoins(joins)
				~ db.constructWhere(whereConditions, orWhereConditions)
				~ db.constructOrder(orderConditions)
				~ db.constructLimit(limitCondition) ~ ";";
		}
}

class MysqlSelectRow: SelectRow
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
		string asSql () @safe const
		{
			return "SELECT " ~ db.constructFields(fields_, tables)
				~ db.constructFrom(tables) ~ db.constructJoins(joins)
				~ db.constructWhere(whereConditions, orWhereConditions)
				~ db.constructOrder(orderConditions)
				~ db.constructLimit(limitCondition) ~ ";";
		}
}

class MysqlSelectCell: SelectCell
{
	public:
		this (SqlDriver db, string field)
		{
			super(db, field);
		}
		string asSql () @safe const
		{
			return "SELECT " ~ db.constructFields(fields_, tables)
				~ db.constructFrom(tables) ~ db.constructJoins(joins)
				~ db.constructWhere(whereConditions, orWhereConditions)
				~ db.constructOrder(orderConditions)
				~ db.constructLimit(limitCondition) ~ ";";
		}
}

class MysqlInsert: Insert
{
	public:
		this (SqlDriver db, string expr, string[] fieldsNames ...) @safe
		{
			this.db = db;
			this.fieldsExpr = expr;
			foreach (field; fieldsNames)
				this.fieldsNames[field] = field;
		}
		string asSql () @safe const
		{
			return "INSERT INTO " ~ db.processPlaceholder("?#", table)
				~ " (" ~ db.constructFields(fieldsNames, [table: table]) ~ ") VALUES "
				~ db.constructValues(fieldsExpr, values_) ~ ";";
		}
}

class MysqlInsertRow: InsertRow
{
	public:
		this (SqlDriver db) @safe
		{
			this.db = db;
		}
		string asSql () @safe const
		{
			return "INSERT INTO " ~ db.processPlaceholder("?#", table)
				~ db.constructSet(sets) ~ ";";
		}
}

class MysqlCreateTable: CreateTable
{
	public:
		this (SqlDriver db, string table) @safe
		{
			this.db = db;
			this.table = table;
		}
		string asSql () @safe const
		{
			return "CREATE TABLE " ~ db.processPlaceholder("?#", table)
				~ " (" ~ db.constructFieldsDefinition(fields)
				~ db.constructPrimaryKey(primaryKey_)
				~ db.constructUnique(unique)
				~ db.constructConstraints(constraints) ~ ")"
				~ db.constructOptions(options) ~ ";";
		}
}

class MysqlDriver: SqlDriver
{
	protected:
		MYSQL mysql;
		
		static
		{
			Variant fldVal (MYSQL_FIELD* fldInfo, const(char)* val) @trusted
			{
				Variant res;
				if (val is null)
					return res;
				string s = to!string(val);
				switch (fldInfo.type)
				{
					case enum_field_types.MYSQL_TYPE_DECIMAL,
						enum_field_types.MYSQL_TYPE_TINY,
						enum_field_types.MYSQL_TYPE_SHORT,
						enum_field_types.MYSQL_TYPE_LONG,
						enum_field_types.MYSQL_TYPE_INT24,
						enum_field_types.MYSQL_TYPE_NEWDECIMAL:
						res = Variant(to!int(s));
						break;
					case enum_field_types.MYSQL_TYPE_FLOAT:
						res = Variant(to!float(s));
						break;
					case enum_field_types.MYSQL_TYPE_DOUBLE:
						res = Variant(to!double(s));
						break;
					case enum_field_types.MYSQL_TYPE_NULL:
						break;
					case enum_field_types.MYSQL_TYPE_LONGLONG:
						res = Variant(to!long(s));
						break;
					default:
						assert(false, "not implemented " ~ to!string(cast(uint)fldInfo.type));
				}
				return res;
			}
		}
		
	public:
		this (string host = null, string user = null, string passwd = null, string db = null, uint port = 3306) @trusted
		{
			super(host, user, passwd, db, port);
			mysql_init(&mysql);
			if (!mysql_real_connect(&mysql, toStringz(host), toStringz(user), toStringz(passwd), toStringz(db), port, null, 0))
				throw new MysqlError(errorMsg);
		}
		~this ()
		{
			mysql_close(&mysql);
		}
		bool query (string q) @trusted
		{
			return 0 == mysql_query(&mysql, toStringz(q));
		}
		uint errorNum () @safe const
		{
			return mysql_errno(&mysql);
		}
		string errorMsg () @trusted const
		{
			return to!string(mysql_error(&mysql));
		}
		ulong rowsAffected () @safe const
		{
			return mysql_affected_rows(&mysql);
		}
		bool selectDb (string db) @trusted
		{
			return 0 == mysql_select_db(&mysql, toStringz(db));
		}
		VariantProxy[string] fetchRow (string q) @trusted
		{
			if (!query(q))
				throw new MysqlError(errorMsg);
			MYSQL_RES* res = mysql_store_result(&mysql);
			if (res is null)
				throw new MysqlError("no result");
			auto fldsCnt = mysql_num_fields(res);
			//auto fldsLens = mysql_fetch_lengths(res);
			MYSQL_ROW row = mysql_fetch_row(res);
			VariantProxy[string] v;
			for (auto i = 0; i < fldsCnt; ++i)
			{
				MYSQL_FIELD* fldInfo = mysql_fetch_field(res);
				v[to!string(fldInfo.name)] = new VariantProxy(fldVal(fldInfo, row[i]));
			}
			mysql_free_result(res);
			return v;
		}
		VariantProxy[string][] fetchAll (string q) @trusted
		{
			if (!query(q))
				throw new MysqlError(errorMsg);
			MYSQL_RES* res = mysql_store_result(&mysql);
			if (res is null)
				throw new MysqlError("no result");
			auto fldsCnt = mysql_num_fields(res);
			//auto fldsLens = mysql_fetch_lengths(res);
			VariantProxy[string][] v;
			auto rowsCnt = mysql_num_rows(res);
			v.length = cast(uint)rowsCnt;
			MYSQL_FIELD*[] fldsInfo;
			fldsInfo.length = fldsCnt;
			string[] fldsNames;
			fldsNames.length = fldsCnt;
			for (auto f = 0; f < fldsCnt; ++f)
			{
				fldsInfo[f] = mysql_fetch_field(res);
				fldsNames[f] = to!string(fldsInfo[f].name);
			}
			for (auto r = 0; r < rowsCnt; ++r)
			{
				MYSQL_ROW row = mysql_fetch_row(res);
				for (auto i = 0; i < fldsCnt; ++i)
					v[r][fldsNames[i]] = new VariantProxy(fldVal(fldsInfo[i], row[i]));
			}
			mysql_free_result(res);
			return v;
		}
		Variant fetchCell (string q) @safe
		{
			if (!query(q))
				throw new MysqlError(errorMsg);
			MYSQL_RES* res = mysql_store_result(&mysql);
			if (res is null)
				throw new MysqlError("no result");
			//auto fldsCnt = mysql_num_fields(res);
			//auto fldsLens = mysql_fetch_lengths(res);
			MYSQL_ROW row = mysql_fetch_row(res);
			MYSQL_FIELD* fldInfo = mysql_fetch_field(res);
			Variant v = fldVal(fldInfo, row[0]);
			mysql_free_result(res);
			return v;
		}
		string escape (string s) @trusted const
		{	// dumb & slow function, i know
			auto sz = toStringz(s);
			auto len = strlen(sz);
			auto resz = cast(char*)(new char[len * 2 + 1]); // result string may be twice as long
			mysql_real_escape_string(&mysql, resz, sz, len);
			auto res = to!string(resz);
			delete resz;
			return res;
		}
		ulong insertId () @safe const
		{
			return mysql_insert_id(&mysql);
		}
		MysqlSelect select (string[] fields ...) @safe
		{
			return new MysqlSelect(this, fields);
		}
		MysqlSelectRow selectRow (string fields ...) @safe
		{
			return new MysqlSelectRow(this, fields);
		}
		MysqlSelectCell selectCell (string field) @safe
		{
			return new MysqlSelectCell(this, field);
		}
		MysqlInsert insert (string expr, string[] fields ...) @safe
		{
			return new MysqlInsert(this, expr, fields);
		}
		MysqlInsertRow insertRow () @safe
		{
			return new MysqlInsertRow(this);
		}
		MysqlCreateTable createTable (string table) @safe
		{
			return new MysqlCreateTable(this, table);
		}
		string constructFields (in string[string] fields, in string[string] tables) @trusted const
		{
			string[] res;
			foreach (k, v; fields)
			{
				if (k != v)
					res ~= processPlaceholder("?#", v) ~ " AS " ~ processPlaceholder("?#", k);
				else
					if ("*" == v)
						res ~= v;
					else
						res ~= processPlaceholder("?#", v);
			}
			string str = res.join(", ");
			if (!str.length || "*" == res)
				return processPlaceholder("?#", tables.values[0]) ~ ".*";
			return str;
		}
		string constructFrom (in string[string] from) @trusted const
		{
			string[string] res;
			foreach (k, v; from)
				if (k != v)
					res ~= processPlaceholder("?#", v) ~ " AS "
						~ processPlaceholder("?#", k);
				else
					res ~= processPlaceholder("?#", v);
			return " FROM " ~ join(res.values, ", ");
		}
		string constructJoins (in BaseSelect.Join[][string] joins) @trusted const
		{
			string[] res;
			foreach (v; joins["inner"])
				if (v.tableAlias.length)
					res ~= processPlaceholders("JOIN ?# AS ?# ON ", v.table, v.tableAlias)
						~ processPlaceholders(v.condition, v.values);
				else
					res ~= processPlaceholders("JOIN ?# ON ", v.table)
						~ processPlaceholders(v.condition, v.values);
			auto str = res.join(" ");
			return str.length? (" " ~ str) : "";
		}
		string constructWhere (in Expr[] where, in Expr[] orWhere) @trusted const
		{
			string[] w, ow;
			foreach (v; where)
				w ~= processPlaceholders(v.expr, v.values);
			foreach (v; orWhere)
				ow ~= processPlaceholders(v.expr, v.values);
			auto res = w.join(") AND (");
			if (!res.length)
				res = " WHERE (" ~ res ~ ")";
			auto res2 = ow.join(") OR (");
			if (res2.length)
				res2 = res.length? (" OR (" ~ res2 ~ ")") : (" WHERE (" ~ res2 ~ ")");
			return res ~ res2;
		}
		string constructOrder (in string[] orders) @safe const
		{
			string[] res;
			foreach (order; orders)
				if ("*" == order)
					res ~= "RAND()";
				else if (order.startsWith("-"))
					res ~= processPlaceholder("?#", order[1 .. $]) ~ " DESC";
				else
					res ~= processPlaceholder("?#", order) ~ " ASC";
			auto str = res.join(", ");
			return str.length? (" ORDER BY " ~ str) : "";
		}
		string constructLimit (in TypeTuple!(uint, uint) limitCondition) @safe const
		{
			return limit[1]
				? (limit[0]
					? (" LIMIT " ~ to!string(limit[1] - limit[0]) ~ " OFFSET " ~ limit[0])
					: (" LIMIT " ~ limit[1]))
				: (limit[0]? (" LIMIT " ~ to!string(limit[0])) : "");
		}
		string constructValues (in string placeholders, in Variant[][] values) @safe const
		{
			string[] res;
			foreach (v; values)
				res ~= processPlaceholders(placeholders, values);
			return "(" ~ res.join("), (") ~ ")";
		}
		string constructSet (in Expr[] sets) @safe const
		{
			string[] exprs;
			foreach (set; sets)
				exprs ~= processPlaceholders(set.expr, set.values);
			return " SET " ~ exprs.join(", ");
		}
		string constructFieldsDefinition (in CreateTable.Field[] fields) @safe const
		{
			string[] res;
			foreach (v; fields)
			{
				auto fld = processPlaceholder("?#", v.name) ~ " " ~ v.type;
				auto options = v.options;
				if ((("primaryKey" in options) !is null) && cast(bool) options["primaryKey"])
					fld ~= " PRIMARY KEY";
				if ((("serial" in options) !is null) && cast(bool) options["serial"])
					fld ~= " AUTO_INCREMENT";
				if ((("null" in options) !is null) && cast(bool) options["null"])
					fld ~= " NULL";
				else
					fld ~= " NOT NULL";
				if ((("unique" in options) !is null) && cast(bool) options["unique"])
					fld ~= " UNIQUE";
				if (("default" in options) !is null)
				{
					auto type = typeid(options["default"]);
					if (type == typeid(string))
					{
						if (options["default"].get!string() == "NULL")
							fld ~= " DEFAULT NULL";
						else
							fld ~= " DEFAULT " ~ processPlaceholder("?", options["default"].get!string);
					}	
					else if (type == typeid(uint) || type == typeid(int))
						fld ~= processPlaceholder("?d", options["default"]);
					else
						throw new Error("unsupported default option type " ~ to!string(options["default"].type), __FILE__, __LINE__);
				}
				res ~= fld;
			}
			return res.join(", ");
		}
		string constructPrimaryKey (in string[] primary) @safe const
		{
			if (!primary.length)
				return "";
			string[] res;
			foreach (v; primary)
				res ~= processPlaceholder("?#", v);
			return ", PRIMARY KEY (" ~ res.join(", ") ~ ")";
		}
		string constructUnique (in string[][] unique) @safe const
		{
			string[] res;
			if (!unique.length)
				return "";
			foreach (v; unique)
			{
				string[] uniq;
				foreach (v2; v)
					uniq ~= processPlaceholder("?#", v2);
				res ~= ", UNIQUE (" ~ uniq.join(", ") ~ ")";
			}
			return res.join(",");
		}
		string constructConstraints (in CreateTable.Constraint[] refs) @safe const
		{
			string[] res;
			if (!refs.length)
				return "";
			foreach (v; refs)
			{
				auto refStr = processPlaceholders(", CONSTRAINT FOREIGN KEY (?#) REFERENCES ?# (?#)", v.name, v.table, v.field);
				if (v.onUpdate.length)
					refStr ~= " ON UPDATE " ~ v.onUpdate;
				if (v.onDelete.length)
					refStr ~= " ON DELETE " ~ v.onDelete;
				res ~= refStr;
			}
			return res.join("");
		}
		string constructOptions (in string[string] options) @safe const
		{
			string[] res;
			if (!options.length)
				return "";
			foreach (k, v; options)
				if ("charset" == k)
					res ~= "CHARACTER SET " ~ v;
				else if ("engine" == k)
					res ~= "ENGINE = " ~ v;
				else
					throw new Error("unsupported option " ~ k, __FILE__, __LINE__);
			return " " ~ res.join(" ");
		}
		
	unittest
	{
		auto m = new MysqlDriver(MYSQL_UNITTEST_HOST, MYSQL_UNITTEST_USER, MYSQL_UNITTEST_PASSWORD, MYSQL_UNITTEST_DB, MYSQL_UNITTEST_PORT);
		m.query("DROP TABLE `t`");
		assert(m.query("CREATE TABLE `t` (`id` INT)"));
		assert(m.query("INSERT INTO `t` (`id`) VALUES (10), (20), (30)"));
		assert(3 == m.rowsAffected);
		auto res = m.selectRow("SELECT * FROM `t` LIMIT 1");
		assert(10 == res["id"].v.get!int);
		auto res2 = m.selectAll("SELECT * FROM `t`");
		assert(3 == res2.length);
		assert(10 == res2[0]["id"].v.get!int);
		assert(20 == res2[1]["id"].v.get!int);
		assert(30 == res2[2]["id"].v.get!int);
		assert(10 == m.selectCell("SELECT `id` FROM `t` LIMIT 1").get!int);
		assert(m.query("DROP TABLE `t`"));
	}
}
