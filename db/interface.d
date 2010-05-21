module db.interface;

import db.driver;

version(MySQL) import db.mysql.driver;

Driver dbConnect (string dsn) @safe pure
{
	string login, pass, port;
	string[string] params;
	auto v = dsn.split("://", "/", "?");
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
		paramsArr = paramsStr.splitAll("&");

	foreach (param; paramsArr)
	{
		auto v = param.split("=");
		params[v[0]] = v[1];
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

class Select
{
	protected:
		Driver db;
		string[] fields;
		string[] tables;
		
	
	public:
		string asSql () abstract @safe const;
	
		auto opCall () @safe const
		{
			return evaluate;
		}
		auto evaluate () @safe const
		{
			return db.fetchAll(asSql);
		}
		this (Driver db, string[] fields ...)
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
		typeof(this) fields (string[] fields ...)
		{
			
		}
	fields = function (self, ...)
		if 0 == select("#", ...) then
			return self
		end
		for _, v in ipairs{select(1, ...)} do
			if type(v) == "table" then
				for k, v2 in pairs(v) do
					if not table.find(self._fields, v2) then
						self._fields[k] = v2
					end
				end
			else
				if not table.find(self._fields, v) then
					table.insert(self._fields, v)
				end
			end
		end
		return self
	end;
	where = function (self, ...) table.insert(self._conditions.where, {...}) return self end;
	orWhere = function (self, ...) table.insert(self._conditions.orWhere, {...}) return self end;
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._conditions.order, v)
		end
		return self
	end;
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = to
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = from
		end
		return self
	end;
	limitPage = function (self, page, onPage)
		self._conditions.limit.from = (page-1)*onPage
		self._conditions.limit.to = page*onPage
		return self
	end;
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
	joinFullUsing = function (self, ...) table.insert(self._joinsUsing.full, {...}) return self end;
}
