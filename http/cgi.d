module http.cgi;

import std.stdio : write, writeln, writef, writefln, stdin;
import std.algorithm : startsWith;
import std.string : indexOf, split, strip;
import std.conv : to;
import std.uri : decode;
import http.wsapi : WsApi;
import func : passArguments;

class Cgi: WsApi
{
	protected:
		auto parseCookies ()
		{
			return this;
		}
		auto parseGetData ()
		{
			auto reqUri = requestHeader("REQUEST_URI");
			if (reqUri is null)
				return this;
			auto data = *reqUri;
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
						auto key = expr[0..eqPos], value = decode(expr[eqPos+1..$]);
						if (key.length)
							_getData[key] = value;
					}
				}
			}
			return this;
		}
		auto parsePostData ()
		{
			auto reqMeth = requestHeader("REQUEST_METHOD");
			if (reqMeth is null || "POST" != *reqMeth)
				return this;
			auto contType = requestHeader("CONTENT_TYPE");
			if (contType is null)
				throw new Exception("CONTENT_TYPE required");
			auto contentType = *contType;
			if (startsWith(contentType, "application/x-www-form-urlencoded"))
			{
				char[] data;
				auto contLen = requestHeader("CONTENT_LENGTH");
				if (contLen is null)
					throw new Exception("CONTENT_LENGTH required");
				data.length = to!(uint)(*contLen);
				stdin.rawRead(data);
				auto exprs = split(data, "&");
				foreach (expr; exprs)
				{
					auto ePos = indexOf(expr, "=");
					if (-1 != ePos)
					{
						auto key = expr[0..ePos], value = decode(expr[ePos+1..$].idup);
						if (key in _postData)
						{
							auto v = _postData[key];
							if (v.type == typeid(string[]))
							{
								auto val = *v.peek!(string[]);
								val.length += 1;
								val[$-1] = value;
							}
							else
								_postData[key] = [*v.peek!(string), value][];
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
						foreach (ubyte[] buf; stdin.byChunk(4096))
							inBuf ~= buf;
						parseMultipartFormData("--" ~ boundary, cast(string)inBuf);
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
			WsApi.sendHeaders();
			return this;
		}
		this (string tmpDir)
		{
			super(tmpDir);
			parseCookies.parseGetData.parsePostData;
		}
}
