module http.wsapi; 

import std.string : split, indexOf, tolower, strip;
import std.regex : Regex, match;
import std.variant : Variant;
import std.md5 : getDigestString;
import std.random : uniform;
import std.algorithm : startsWith;
import type : constCast;

abstract class WsApi
{
	alias string[string] map;
	protected:
		map _getData, _requestHeaders, _responseHeaders, _cookies;
		Variant[string] _postData;
		string tmpDir;
		static string[uint] responseCodesStrings;
		@property
		{
			auto getData (map getData)
			{
				_getData = getData;
				return this;
			}
			auto postData (Variant[string] postData)
			{
				_postData = postData;
				return this;
			}
			auto requestHeaders (map requestHeaders)
			{
				_requestHeaders = requestHeaders;
				return this;
			}
			auto responseHeaders (map responseHeaders)
			{
				_responseHeaders = responseHeaders;
				return this;
			}
			auto cookies (map cookies)
			{
				_cookies = cookies;
				return this;
			}
		}
		auto get (string key, string value)
		{
			_getData[key] = value;
			return this;
		}
		auto post (string key, Variant value)
		{
			_postData[key] = value;
			return this;
		}
		WsApi parseMultipartFormData (string boundary, string data)
		{
			foreach (block; split(data, boundary)[1..$-1])
			{
				auto eol2Pos = indexOf(block, "\r\n\r\n");
				if (-1 == eol2Pos)
					throw new Exception("block delimiter not founded");
				auto headersStr = block[0..eol2Pos];
				data = block[eol2Pos+1..$];
				string[string] headers;
				foreach (header; split(headersStr, "\r\n"))
				{
					auto cPos = indexOf(header, ":");
					if (-1 == cPos)
						throw new Exception("colon delimiter not founded");
					auto name = header[0..cPos], value = header[cPos+1..$];
					headers[tolower(name)] = value;
				}
				auto contentDispValues = split(headers["content-disposition"], ";");
				if ("form-data" != strip(contentDispValues[0]))
					throw new Exception("invalid Content-Disposition value");
				string key;
				bool isFile;
				foreach (contentDispValue; contentDispValues[1..$])
				{
					auto eqPos = indexOf(contentDispValue, "=");
					if (-1 == eqPos)
						throw new Exception("equal sign delimiter not founded");
					auto name = strip(contentDispValue[0..eqPos]), value = tolower(strip(contentDispValue[eqPos+1..$]));
					if ("name" == name)
						key = value[1..$-1];
					else if ("filename" == name)
						isFile = true;
				}
				block = block[0..$-2];
				if (isFile)
				{
					if (block.length)
					{
						string[string] info;
						info["filename"] = key;
						_postData[key] = info;
						if (tmpDir !is null)
						{
							auto fileName = tmpDir ~ getDigestString([uniform(0, 2_000_000_000)][]);
							_postData[key]["tmpFilePath"] = fileName;
							write(fileName, block);
						}
						else
							_postData[key]["data"] = data;
					}
					else
						_postData[key] = block;
				}
			}
			return this;
		}
	public:
		ushort responseCode;
		bool headersSent;
		@property
		{
			auto requestHeaders () { return mixin(constCast(_requestHeaders.stringof)); }
			auto getData () { return mixin(constCast(_getData.stringof)); }
			auto postData () { return mixin(constCast(_postData.stringof)); }
			auto responseHeaders () { return mixin(constCast(_responseHeaders.stringof)); }
			auto cookies () { return mixin(constCast(_cookies.stringof)); }
		}
		auto post (string key) { return key in postData; }
		auto get (string key) { return key in getData; }
		string* requestHeader (string key) { return key in requestHeaders; }
		auto cookie (string key) { return key in cookies; }
		auto cookie (string key, string value)
		{
			_cookies[key] = value;
			return this;
		}
		auto responseHeader (string key) { return key in responseHeaders; }
		auto responseHeader (string key, string value)
		{
			_responseHeaders[key] = value;
			return this;
		}
		this (string tmpDir)
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
		}
		WsApi sendHeaders () { headersSent = true; return this; }
		abstract WsApi write(...);
		abstract WsApi writef(...);
		abstract WsApi writeln(...);
		abstract WsApi writefln(...);
}

class HttpRequest
{
	public:
		WsApi ws;
		this (WsApi ws)
		{
			this.ws = ws;
		}
		// Headers
		auto headers () { return ws.requestHeaders; }
		auto header (string header) { return ws.requestHeader(header); }
		@property auto method () { return header("REQUEST_METHOD"); }
		// GET
		auto getData () { return ws.getData; }
		auto get (string key) { return ws.get(key); }
		// POST
		auto postData () { return ws.postData; }
		auto post (string key) { return ws.post(key); }
		// Cookies
		auto cookies () { return ws.cookies; }
		auto cookie (string key) { return ws.cookie(key); }
}

class HttpResponse
{
	public:
		WsApi ws;
		auto header (string key) { return ws.responseHeader(key); }
		auto header (string key, string value)
		{
			ws.responseHeader(key, value);
			return this;
		}
		@property
		{
			auto code () { return ws.responseCode; }
			auto code (ushort code)
			{
				ws.responseCode = code;
				return this;
			}
			auto contentType () { return header("Content-Type"); }
			auto contentType (string type) { return header("Content-Type", type); }
		}
		auto sendHeaders ()
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
		this (Regex!(char) regex, Variant handler)
		{
			this.regex = regex;
			this.handler = handler;
		}
}

class UrlConf
{
	public:
		HttpRequest request;
		string urlPrefix, uri, tailUri, baseUri;
		string[] captures;
		Variant[string] environment;
		this (HttpRequest request, string urlPrefix)
		{
			this.request = request;
			this.urlPrefix = urlPrefix;
			auto reqUri = request.header("REQUEST_URI");
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
		this (HttpRequest request)
		{
			this(request, "");
		}
		auto dispatch (Route[] routes)
		{
			foreach (route; routes)
			{
				auto match = match(tailUri, route.regex);
				if (!match.empty)
				{
					foreach(capture; match.captures)
					{
						captures.length += 1;
						captures[$-1] = capture;
					}
					baseUri ~= uri[0..match.pre.length];
					tailUri = tailUri[match.pre.length..$];
					//if (route.handler(this, environment))
						return true;
				}
			}
			return false;
		}
}
