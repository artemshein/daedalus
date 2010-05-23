/**
 * HTTP web-server API
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2009 - 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module http.wsapi; 

private import std.string, std.regex, std.conv, std.variant, std.md5,
	std.random, std.algorithm, std.uri, std.stdarg, std.stdio, std.file;
import type, fixes;

string castToTypeAndConcat (string type) @safe pure
{
	return " if (typeid(" ~ type ~ ") == arg) dataToSend ~= to!(string)(va_arg!(" ~ type ~ ")(_argptr)); ";
}

abstract class WsApi
{
	protected:
		static string[uint] responseCodesStrings;
		static string[string] mimeTypes;
		
		string[string] _getData, _requestHeaders, _responseHeaders, _cookies;
		VariantProxy[string] _postData;
		string tmpDir;
		string dataToSend;
		
		typeof(this) getData (string[string] getData) @safe @property
		{
			_getData = getData;
			return this;
		}
		typeof(this) postData (VariantProxy[string] postData) @safe @property
		{
			_postData = postData;
			return this;
		}
		typeof(this) requestHeaders (string[string] requestHeaders) @safe @property
		{
			_requestHeaders = requestHeaders;
			return this;
		}
		typeof(this) responseHeaders (string[string] responseHeaders) @safe @property
		{
			_responseHeaders = responseHeaders;
			return this;
		}
		typeof(this) cookies (string[string] cookies) @safe @property
		{
			_cookies = cookies;
			return this;
		}
		typeof(this) get (string key, string value) @safe
		{
			_getData[key] = value;
			return this;
		}
		typeof(this) post (string key, Variant value) @trusted
		{
			_postData[key].v = value;
			return this;
		}
		typeof(this) parseMultipartFormData (string boundary, string data) @trusted
		{
			auto res = split(data, boundary);
			foreach (block; res[1 .. $ - 1])
			{
				auto eol2Pos = indexOf(block, "\r\n\r\n");
				if (-1 == eol2Pos)
					throw new Exception("block delimiter not founded");
				auto headersStr = block[0 .. eol2Pos];
				data = block[eol2Pos + 1 .. $];
				string[string] headers;
				foreach (header; split(headersStr, "\r\n"))
				{
					auto cPos = indexOf(header, ":");
					if (-1 == cPos)
						throw new Exception("colon delimiter not founded");
					auto name = header[0 .. cPos], value = header[cPos + 1 .. $];
					headers[tolower(name)] = value;
				}
				auto contentDispValues = split(headers["content-disposition"], ";");
				if ("form-data" != strip(contentDispValues[0]))
					throw new Exception("invalid Content-Disposition value");
				string key;
				bool isFile;
				foreach (contentDispValue; contentDispValues[1 .. $])
				{
					auto eqPos = indexOf(contentDispValue, "=");
					if (-1 == eqPos)
						throw new Exception("equal sign delimiter not founded");
					auto name = strip(contentDispValue[0 .. eqPos]), value = tolower(strip(contentDispValue[eqPos + 1 .. $]));
					if ("name" == name)
						key = value[1 .. $ - 1];
					else if ("filename" == name)
						isFile = true;
				}
				block = block[0 .. $ - 2];
				if (isFile)
				{
					if (block.length)
					{
						string[string] info;
						info["filename"] = key;
						_postData[key].v = info;
						if (tmpDir !is null)
						{
							auto fileName = tmpDir ~ getDigestString([uniform(0, 2_000_000_000)][]);
							(*_postData[key].v.peek!(string[string]))["tmpFilePath"] = fileName;
							write(fileName, block);
						}
						else
							(*_postData[key].v.peek!(string[string]))["data"] = data;
					}
					else
						_postData[key].v = block;
				}
			}
			return this;
		}
		typeof(this) parseRequestHeaders (string[] headers) @trusted
		{
			foreach (header; headers)
			{
				auto colsPos = indexOf(header, ":");
				if (-1 != colsPos)
					requestHeader(strip(header[0 .. colsPos]), strip(header[colsPos .. $]));
			}
			return this;
		}
		typeof(this) parseGetParams (string params) @trusted
		{
			foreach (param; params.split("&"))
			{
				auto eqPos = param.indexOf("=");
				if (-1 != eqPos)
					get(strip(param[0 .. eqPos]), decode(strip(param[eqPos + 1 .. $])));
			}
			return this;
		}
		bool appendPostValue (string key, string value) @trusted
		{
			auto leftBrPos = key.indexOf("["), rightBrPos = key.indexOf("]");
			if (-1 != leftBrPos && -1 != rightBrPos && rightBrPos > leftBrPos)
			{	// string[string]
				auto el = cast(Variant*) post(key[0 .. leftBrPos]);
				if (el is null)
				{
					string[string] v;
					v[key[leftBrPos + 1 .. rightBrPos]] = decode(value);
					post(key[0 .. leftBrPos], Variant(v));
				}
				else if (typeid(string[string]) == typeid(el))
				{
					(*el.peek!(string[string]))[key[leftBrPos + 1 .. rightBrPos]] = decode(value);
				}
				else
					return false;
			}
			else
			{	// string or string[]
				auto el = cast(Variant*) post(key);
				if (el is null)
					post(key, Variant(decode(value)));
				else if (typeid(string) == el.type)
				{
					string[] v;
					v.length = 2;
					v[0] = el.get!(string);
					v[1] = decode(value);
					post(key, Variant(v));
				}
				else if (typeid(string[]) == el.type)
				{
					auto s = el.peek!(string[]);
					s.length += 1;
					(*s)[$-1] = decode(value);
				}
				else
					return false;
			}
			return true;
		}
		WsApi parsePostData (string data) @trusted
		{
			auto contentType = *requestHeader("Content-Type");
			if (contentType.startsWith("application/x-www-form-urlencoded"))
			{
				foreach (param; data.split("&"))
				{
					auto eqPos = param.indexOf("=");
					if (-1 != eqPos)
						appendPostValue(param[0 .. eqPos], param[eqPos + 1 .. $]);
				}
			}
			else if (contentType.startsWith("multipart/form-data"))
			{
				auto boundary = contentType.split(";")[1].split("=")[1];
				parseMultipartFormData("--" ~ boundary, data);
			}
			else
				throw new Exception("not implemented for content-type: " ~ contentType);
			return this;
		}
		
	public:
		ushort responseCode;
		bool headersSent;
		
		const(string[string]) requestHeaders () @safe @property pure const
		{
			return _requestHeaders;
		}
		const(string[string]) getData () @safe @property pure const
		{
			return _getData;
		}
		const(VariantProxy[string]) postData () @safe @property pure const
		{
			return _postData;
		}
		const(string[string]) responseHeaders () @safe @property pure const
		{
			return _responseHeaders;
		}
		const(string[string]) cookies () @safe @property pure const
		{
			return _cookies;
		}
		const(VariantProxy*) post (string key) @safe pure const
		{
			return key in postData;
		}
		const(string*) get (string key) @safe pure const
		{
			return key in getData;
		}
		typeof(this) requestHeader (string key, string val) @safe
		{
			_requestHeaders[key] = val;
			return this;
		}
		const(string*) requestHeader (string key) @safe pure const
		{
			return key in requestHeaders;
		}
		const(string*) cookie (string key) @safe pure const
		{
			return key in cookies;
		}
		typeof(this) cookie (string key, string value) @safe
		{
			_cookies[key] = value;
			return this;
		}
		const(string*) responseHeader (string key) @safe pure const
		{
			return key in responseHeaders;
		}
		typeof(this) responseHeader (string key, string value) @safe
		{
			_responseHeaders[key] = value;
			return this;
		}
		this (string tmpDir) @safe
		{
			this.tmpDir = tmpDir;
		}
		static this ()
		{
			responseCodesStrings = [
				200: "OK", 201: "Created", 202: "Accepted", 203: "Non-Authoritative Information",
				204: "No Content", 205: "Reset Content", 206: "Partial Content",
				207: "Multi-Status", 300: "Multiple Choices", 301: "Moved permanently",
				302: "Found", 303: "See Other", 304: "Not Modified", 305: "Use Proxy",
				307: "Temporary Redirect", 400: "Bad Request", 401: "Unauthorized",
				402: "Payment Required", 403: "Forbidden", 404: "Not Found",
				405: "Method Not Allowed", 406: "Not Acceptable",
				407: "Proxy Authentication Required", 408: "Request Timeout",
				409: "Conflict", 410: "Gone", 411: "Length Required",
				412: "Precondition Failed", 413: "Request Entity Too Large",
				414: "Request-URI Too Long", 415: "Unsupported Media Type",
				416: "Requested Range Not Satisfiable", 417: "Expectation Failed",
				418: "I'm a teapot", 422: "Unprocessable Entity", 423: "Locked",
				424: "Failed Dependency", 425: "Unordered Collection",
				426: "Upgrade Required", 449: "Retry With", 450: "Blocked",
				500: "Internal Server Error", 501: "Not Implemented",
				502: "Bad Gateway", 503: "Service Unavailable", 504: "Gateway Timeout",
				505: "HTTP Version Not Supported", 506: "Variant Also Negotiates",
				507: "Insufficient Storage", 509: "Bandwidth Limit Exceeded",
				510: "Not Extended"
			];
			mimeTypes = [
				".png": "image/png", ".gif": "image/gif", ".jpg": "image/jpeg",
				".jpeg": "image/jpeg", ".css": "text/css", ".js": "text/javascript"
			];
		}
		typeof(this) sendHeaders () @safe
		{
			headersSent = true;
			return this;
		}
		typeof(this) flush () @safe
		{
			if (!headersSent)
				sendHeaders;
			return this;
		}
		typeof(this) write (...) @trusted
		{
			foreach (arg; _arguments)
				mixin(castToTypeAndConcat("string")
				~ "else" ~ castToTypeAndConcat("byte")
				~ "else" ~ castToTypeAndConcat("ubyte")
				~ "else" ~ castToTypeAndConcat("short")
				~ "else" ~ castToTypeAndConcat("ushort")
				~ "else" ~ castToTypeAndConcat("int")
				~ "else" ~ castToTypeAndConcat("uint")
				~ "else" ~ castToTypeAndConcat("long")
				~ "else" ~ castToTypeAndConcat("ulong")
				~ "else" ~ castToTypeAndConcat("float")
				~ "else" ~ castToTypeAndConcat("double")
				~ "else" ~ castToTypeAndConcat("void[]")
				~ "else throw new Exception(\"not implemented for write\");");
			return this;
		}
		WsApi writef (...) @trusted
		{
			switch (_arguments.length)
			{
				case 0:
					return write;
				case 1:
					return write(format(_arguments[0]));
				case 2:
					return write(format(_arguments[0], _arguments[1]));
				case 3:
					return write(format(_arguments[0], _arguments[1], _arguments[2]));
				case 4:
					return write(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3]));
				case 5:
					return write(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4]));
				case 6:
					return write(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5]));
				case 7:
					return write(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5], _arguments[6]));
				case 8:
					return write(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5], _arguments[6], _arguments[7]));
				default:
					throw new Exception("not implemented for writef");
			}
			return this;
		}
		typeof(this) writeln (...)
		{
			foreach (arg; _arguments)
				mixin(castToTypeAndConcat("string")
				~ "else" ~ castToTypeAndConcat("byte")
				~ "else" ~ castToTypeAndConcat("ubyte")
				~ "else" ~ castToTypeAndConcat("short")
				~ "else" ~ castToTypeAndConcat("ushort")
				~ "else" ~ castToTypeAndConcat("int")
				~ "else" ~ castToTypeAndConcat("uint")
				~ "else" ~ castToTypeAndConcat("long")
				~ "else" ~ castToTypeAndConcat("ulong")
				~ "else" ~ castToTypeAndConcat("float")
				~ "else" ~ castToTypeAndConcat("double")
				~ "else throw new Exception(\"not implemented for writeln\");");
			dataToSend ~= "\r\n";
			return this;
		}
		typeof(this) writefln (...) @trusted
		{
			switch (_arguments.length)
			{
				case 0:
					return writeln;
				case 1:
					return writeln(format(_arguments[0]));
				case 2:
					return writeln(format(_arguments[0], _arguments[1]));
				case 3:
					return writeln(format(_arguments[0], _arguments[1], _arguments[2]));
				case 4:
					return writeln(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3]));
				case 5:
					return writeln(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4]));
				case 6:
					return writeln(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5]));
				case 7:
					return writeln(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5], _arguments[6]));
				case 8:
					return writeln(format(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5], _arguments[6], _arguments[7]));
				default:
					throw new Exception("not implemented for writefln");
			}
			return this;
		}
}

class HttpRequest
{
	public:
		WsApi ws;
		
		this (WsApi ws) @safe
		{
			this.ws = ws;
		}
		// Headers
		const(string[string]) headers () @safe @property const
		{
			return ws.requestHeaders;
		}
		const(string*) header (string header) @safe pure const
		{
			return ws.requestHeader(header);
		}
		const(string*) method () @safe @property pure const
		{
			return header("REQUEST_METHOD");
		}
		// GET
		const(string[string]) getData () @safe @property const
		{
			return ws.getData;
		}
		const(string*) get (string key) @safe @property pure const
		{
			return ws.get(key);
		}
		// POST
		const(VariantProxy[string]) postData () @safe @property const
		{
			return ws.postData;
		}
		const(VariantProxy*) post (string key) @safe @property pure const
		{
			return ws.post(key);
		}
		// Cookies
		const(string[string]) cookies () @safe @property pure const
		{
			return ws.cookies;
		}
		const(string*) cookie (string key) @safe pure const
		{
			return ws.cookie(key);
		}
}

class HttpResponse
{
	public:
		WsApi ws;
		
		const(string*) header (string key) @safe pure const
		{
			return ws.responseHeader(key);
		}
		typeof(this) header (string key, string value) @safe
		{
			ws.responseHeader(key, value);
			return this;
		}
		typeof(WsApi.responseCode) code () @safe @property const
		{
			return ws.responseCode;
		}
		typeof(this) code (ushort code) @safe @property
		{
			ws.responseCode = code;
			return this;
		}
		const(string*) contentType () @safe @property const
		{
			return header("Content-Type");
		}
		typeof(this) contentType (in string type) @safe @property
		{
			header("Content-Type", type);
			return this;
		}
		typeof(this) sendHeaders () @safe
		{
			ws.sendHeaders;
			return this;
		}
}

class Route
{
	public:
		Regex!(char) regex;
		Variant handler;
		
		this (Regex!(char) regex, Variant handler) @trusted
		{
			this.regex = regex;
			this.handler = handler;
		}
}

Route route (R, H) (R re, H handler)
{
	static if (is(R : string))
		return new Route(regex(re), Variant(handler));
	else
		return new Route(re, Variant(handler));
}

class UrlConf
{
	public:
		alias void function (UrlConf, VariantProxy[string]) FuncHandler;
		alias void delegate (UrlConf, VariantProxy[string]) DlgHandler;
		
		HttpRequest request;
		string urlPrefix, uri, tailUri, baseUri;
		string[] captures;
		VariantProxy[string] environment;
		Route[] routes;
		
		this (HttpRequest request, string urlPrefix) @trusted
		{
			this.request = request;
			this.urlPrefix = urlPrefix;
			environment["urlConf"] = new VariantProxy(Variant(this));
			auto reqUri = request.header("Request-Uri");
			if (reqUri !is null)
			{
				uri = *reqUri;
				auto pos = indexOf(uri, "?");
				if (-1 != pos)
					uri = uri[0..pos];
			}
			if (urlPrefix.length)
			{
				tailUri = uri;
				if (!startsWith(tailUri, urlPrefix))
					throw new Exception("invalid URL prefix");
				tailUri = tailUri[urlPrefix.length+1..$];
			}
			else
				tailUri = uri;
		}
		this (HttpRequest request) @safe
		{
			this(request, "");
		}
		this (WsApi wsApi) @safe
		{
			this(new HttpRequest(wsApi));
		}
		UrlConf bind (Route route) @safe
		{
			routes.length += 1;
			routes[$ - 1] = route;
			return this;
		}
		bool dispatch (Route[] routes) @trusted
		{
			foreach (route; routes)
			{
				auto match = match(tailUri, route.regex);
				debug .writeln(tailUri);
				if (!match.empty)
				{
					foreach(capture; match.captures)
					{
						captures.length += 1;
						captures[$-1] = capture;
					}
					environment["captures"] = new VariantProxy(Variant(captures));
					baseUri ~= uri[0..match.pre.length];
					tailUri = tailUri[match.pre.length..$];
					if (activate(route.handler))
						return true;
				}
			}
			return false;
		}
		bool dispatch () @safe
		{
			return dispatch(routes);
		}
		bool dispatch (Route[] routes ...) @safe
		{
			return dispatch(routes);
		}
		bool activate (Variant handler) @trusted
		{
			.writefln("environment is 0x%x", &environment);
			if (typeid(FuncHandler) == typeid(handler))
				handler.get!FuncHandler()(this, environment);
			else if (typeid(DlgHandler) == typeid(handler))
				handler.get!DlgHandler()(this, environment);
			else
				throw new Exception("not implemented for activate");
			return true;
		}
}

UrlConf.DlgHandler serveStatic (in string path)
{
	return (UrlConf urlConf, VariantProxy[string] env)
	{
		auto request = urlConf.request;
		auto ws = request.ws;
		auto captures = env["captures"].v.get!(string[]);
		debug .writefln("Serving static in %s", path);
		debug .writeln(captures);
		auto fileName = path ~ captures[1];
		debug .writeln(fileName);
		if (exists(fileName))
		{
			foreach (ext, mime; ws.mimeTypes)
				if (fileName.endsWith(ext))
				{
					ws.responseHeader("Content-Type", mime);
					break;
				}
			auto contents = read(fileName);
			ws.write(contents);
		}
		else
			ws.responseCode = 404;
	};
}
