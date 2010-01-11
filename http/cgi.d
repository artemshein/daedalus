module http.cgi;

import std.stdio : write, writeln, writef, writefln, stdin;
import std.algorithm : startsWith;
import std.conv : to;
import http.wsapi : WsApi;
import func : passArguments;

class Cgi: WsApi
{
	protected:
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
						auto key = expr[0..eqPos], value = urlDecode(expr[eqPos+1..$]);
						if (!key.empty)
							_getData[key] = value;
					}
				}
			}
			return this;
		}
		auto parsePostData ()
		{
			if ("POST" != requestHeader("REQUEST_METHOD"))
				return this;
			auto contentType = requestHeader("CONTENT_TYPE");
			if (startsWith(contentType, "application/x-www-form-urlencoded"))
			{
				string data;
				data.length = to!(uint)(requestHeader("CONTENT_LENGTH"));
				stdin.rawRead(data);
				auto exprs = split(data, "&");
				foreach (expr; exprs)
				{
					auto ePos = indexOf(expr, "=");
					if (-1 != ePos)
					{
						auto key = expr[0..ePos], value = urlDecode(expr[ePos+1..$]);
						if (key in _postData)
						{
							auto v = _postData[key];
							if (v.type == typeid(string[]))
							{
								v.length + 1;
								v[$-1] = value;
							}
							else
								_postData[key] = [v, value][];
						}
						else
							_postData[key] = value;
					}
				}
			}
			else if (startsWith(contentType, "multipart/form-data"))
			{
				auto dcPos = indexOf(contentType, ";");
				if (-1 != dcPos)
				{
					auto boundaryStr = contentType[dcPos+1..$];
					auto eqPos = indexOf(boundaryStr, "=");
					if (-1 != eqPos)
					{
						auto boundary = boundaryStr[eqPos+1..$];
						ubyte[] inBuf;
						foreach (buf; stdin.byChunk(4096))
							inBuf ~= buf;
						parseMultipartFormData("--" ~ boundary, inBuf);
					}
				}
			}
			else
				throw new Exception("not implemented for content-type: " ~ contentType);
			return this;
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
			super(tmpDir);
			parseCookies.parseGetData.parsePostData;
		}
}
