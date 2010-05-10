module db.sqlite3.driver;

import core.stdc.string, std.variant, std.conv, std.string;
import db.driver, db.sqlite3.libsqlite3;

class Sqlite3Error: DbError
{
	this (string s)
	{
		super(s);
	}
}

class Sqlite3Driver: Driver
{
	protected:
		sqlite3* sqlite;
		
		static
		{
			Variant fldVal (sqlite3_stmt* stmt, int column)
			{
				switch (sqlite3_column_type(stmt, column))
				{
					case SQLITE_INTEGER:
						return Variant(sqlite3_column_int(stmt, column));
					case SQLITE_FLOAT:
						return Variant(sqlite3_column_double(stmt, column));
					case SQLITE_BLOB:
						auto len = sqlite3_column_bytes(stmt, column);
						ubyte[] data = new ubyte[len];
						memcpy(data.ptr, sqlite3_column_blob(stmt, column), len);
						return Variant(data);
					case SQLITE_NULL:
						return Variant(null);
					case SQLITE3_TEXT:
						return Variant(to!string(sqlite3_column_text(stmt, column)));
					default:
						assert(false, "not implemented");
				}
			}
		}
		
	public:
		this (string host = null, string user = null, string passwd = null, string db = null, uint port = 0)
		{
			super(host, user, passwd, db, port);
			if (!sqlite3_open(toStringz(host), &sqlite))
				throw new Sqlite3Error(errorMsg);
		}
		~this ()
		{
			sqlite3_close(sqlite);
		}
		bool query (string q)
		{
			return 0 == sqlite3_exec(sqlite, toStringz(q), null, null, null);
		}
		uint errorNum ()
		{
			return sqlite3_errcode(sqlite);
		}
		string errorMsg ()
		{
			return to!string(sqlite3_errmsg(sqlite));
		}
		ulong rowsAffected ()
		{
			assert(false, "not supported");
		}
		bool selectDb (string db)
		{
			return true;
		}
		/+VariantProxy[string] selectRow (string q)
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
				v[to!string(fldInfo.name)] = *new VariantProxy(fldVal(fldInfo, row[i]));
			}
			mysql_free_result(res);
			return v;
		}
		VariantProxy[string][] selectAll (string q)
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
					v[r][fldsNames[i]] = *new VariantProxy(fldVal(fldsInfo[i], row[i]));
			}
			mysql_free_result(res);
			return v;
		}+/
		Variant selectCell (string q)
		{
			sqlite3_stmt* stmt;
			scope(exit) sqlite3_finalize(stmt);
			if (sqlite3_prepare_v2(sqlite, toStringz(q), -1, &stmt, null))
				throw new Sqlite3Error(errorMsg);
			switch (sqlite3_step(stmt))
			{
				case SQLITE_ROW:
					return fldVal(stmt, 0);
				default:
					throw new Sqlite3Error(errorMsg);
			}
			assert(false);
		}
		string escape (string s)
		{	
			assert(false, "not implemented");
		}
		ulong insertId ()
		{
			assert(false, "not supported");
		}
}
