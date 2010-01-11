module http.cgi;

import std.stdio : write, writeln, writef, writefln;
import http.wsapi : WsApi;
import func : passArguments;

class Cgi: WsApi
{
	protected:
		bool headersSent = false;
		string tmpDir;
		auto parseCookies ()
		{
		}
		auto parseGetData ()
		{
			auto data = requestHeader("REQUEST_URI");
			auto pos = indexOf(data, "?");
			if (-1 != pos)
				data = data[pos+1..$];
			if (data.length)
			{
				auto exprs = split(data, "&");
				foreach (expr; exprs)
				{
					auto eqPos = indexOf(expr, "=");
					if (-1 != eqPos)
					{
						auto key, value = expr[0..eqPos], urlDecode(expr[eqPos+1..$]);
						if (!key.empty)
							_getData[key] = value;
					}
				}
			}
			return this;
		}
		void parsePostData ()
		{
			if ("POST" != requestHeader("REQUEST_METHOD"))
				return;
		end
		local contentType = self:requestHeader"CONTENT_TYPE"
		if contentType:beginsWith"application/x-www-form-urlencoded" then
			local data = io.read(tonumber(self:requestHeader"CONTENT_LENGTH"))
			if data then
				data = data:explode"&"
				for _, v in ipairs(data) do
					local key, val = v:split"="
					val = urlDecode(val)
					if not self._post[key] then
						self._post[key] = val
					else
						if "table" == type(self._post[key]) then
							table.insert(self._post[key], val)
						else
							self._post[key] = {self._post[key];val}
						end
					end
				end
			end
		elseif contentType:beginsWith"multipart/form-data" then
			local _, boundaryStr = contentType:split";"
			local _, boundary = boundaryStr:split"="
			self:parseMultipartFormData("--"..boundary, io.read "*a")
		else
			Exception("not implemented for content-type: "..contentType)
		end
		}
	public:
		WsApi write (...)
		{
			mixin(passArguments("write"));
			return this;
		}
		WsApi writef (...)
		{
			mixin(passArguments("writef"));
			return this;
		}
		WsApi writeln (...)
		{
			mixin(passArguments("writeln"));
			return this;
		}
		WsApi writefln (...)
		{
			mixin(passArguments("writefln"));
			return this;
		}
		WsApi sendHeaders ()
		{
			headersSent = true;
		}
		this (string tmpDir)
		{
			this.tmpDir = tmpDir;
			parseCookies;
			parseGetData;
			parsePostData;
		}
}
