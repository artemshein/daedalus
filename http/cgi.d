/**
 * HTTP web-server CGI
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2009 - 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module http.cgi;

import std.stdio, std.stdarg, std.algorithm, std.string, std.conv, std.uri;
import http.wsapi, func;

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
			string castToTypeAndWrite (string type)
			{
				return " if (typeid(" ~ type ~ ") == arg) std.stdio.write(to!(string)(va_arg!(" ~ type ~ ")(_argptr))); ";
			}
			foreach (arg; _arguments)
				mixin(castToTypeAndWrite("string")
				~ "else" ~ castToTypeAndWrite("byte")
				~ "else" ~ castToTypeAndWrite("ubyte")
				~ "else" ~ castToTypeAndWrite("short")
				~ "else" ~ castToTypeAndWrite("ushort")
				~ "else" ~ castToTypeAndWrite("int")
				~ "else" ~ castToTypeAndWrite("uint")
				~ "else" ~ castToTypeAndWrite("long")
				~ "else" ~ castToTypeAndWrite("ulong")
				~ "else" ~ castToTypeAndWrite("float")
				~ "else" ~ castToTypeAndWrite("double")
				~ "else" ~ castToTypeAndWrite("void[]")
				~ "else throw new Exception(\"not implemented for write\");");
			return this;
		}
		/+WsApi write (...)
		{
			.writeln("hohoho");
			mixin(passArguments("std.stdio.write"));
			return this;
		}
		WsApi writef (...)
		{
			mixin(passArguments("std.stdio.writef"));
			return this;
		}
		WsApi writeln (...)
		{
			mixin(passArguments("std.stdio.writeln"));
			return this;
		}
		WsApi writefln (...)
		{
			mixin(passArguments("std.stdio.writefln"));
			return this;
		}+/
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
