/**
 * MySQL driver
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.driver;

import std.variant;
import fixes;

class DbError : Error
{
	this (string s)
	{
		super(s);
	}
}

abstract class Driver
{
	protected:
		string host, user, passwd, db;
		uint port;
		
	public:
		this (string host = null, string user = null, string passwd = null, string db = null, uint port = 0)
		{
			this.host = host;
			this.user = user;
			this.passwd = passwd;
			this.db = db;
			this.port = port;
		}
		
		abstract:
			bool query (string q);
			uint errorNum ();
			string errorMsg ();
			ulong rowsAffected ();
			bool selectDb (string db);
			VariantProxy[string] selectRow (string q);
			VariantProxy[string][] selectAll (string q);
			Variant selectCell (string q);
			string escape (string s);
			ulong insertId ();
}
