/**
 * Database driver
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.mysql.driver;

import db.driver, db.db, db.mysql.libmysqlclient, fixes;
import std.string, std.conv, std.variant, core.stdc.string;

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
}

class MysqlSelectRow: SelectRow
{
}

class MysqlSelectCell: SelectCell
{
}

class MysqlInsert: Insert
{
	public:
		this (SqlDriver db, string expr, string[] fieldsNames ...) @safe
		{
			this.db = db;
			this.fieldsExpr = expr;
			this.fieldsNames = fieldsNames;
		}
}

class MysqlInsertRow: InsertRow
{
}

class MysqlCreateTable: CreateTable
{
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
		MysqlSelectRow selectRow (string expr, ...) @safe
		{
			return new MysqlSelectRow(this, expr, packArgs(_arguments, _argptr));
		}
		MysqlSelectCell selectCell () @safe
		{
			return new MysqlSelectCell(this);
		}
		MysqlInsert insert (string expr, ...) @safe
		{
			return new MysqlInsert(expr, packArgs(_arguments, _argptr));
		}
		MysqlInsertRow insertRow () @safe
		{
			return new MysqlInsertRow(this);
		}
		MysqlCreateTable createTable (string table) @safe
		{
			return new MysqlCreateTable(this, table);
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
