module http.wsapi; 

import std.regex, std.variant;
import type : constCast;

abstract class WsApi
{
	alias string[string] map;
	public:
		map _getData, _postData, _requestHeaders, _responseHeaders, _cookies;
		@property
		{
			auto getData (map getData)
			{
				this._getData = getData;
				return this;
			}
			auto postData (map postData)
			{
				this._postData = postData;
				return this;
			}
			auto requestHeaders (map requestHeaders)
			{
				this._requestHeaders = requestHeaders;
				return this;
			}
			auto responseHeaders (map responseHeaders)
			{
				this._responseHeaders = responseHeaders;
				return this;
			}
			auto cookies (map cookies)
			{
				this._cookies = cookies;
				return this;
			}
		}
		auto get (string key, string value)
		{
			this._getData[key] = value;
			return this;
		}
		auto post (string key, string value)
		{
			this._postData[key] = value;
			return this;
		}
	public:
		ushort responseCode;
		@property
		{
			const auto requestHeaders () { return mixin(constCast((this._requestHeaders).stringof)); }
			auto getData () { return mixin(constCast(this._getData.stringof)); }
			auto postData () { return mixin(constCast(this._postData.stringof)); }
			auto responseHeaders () { return mixin(constCast(this._responseHeaders.stringof)); }
			auto cookies () { return mixin(constCast(this._cookies.stringof)); }
		}
		auto post (string key) { return this.postData[key]; }
		auto get (string key) { return this.getData[key]; }
		auto requestHeader (string key) { return this.requestHeaders[key]; }
		auto cookie (string key) { return this.cookies[key]; }
		auto cookie (string key, string value)
		{
			this._cookies[key] = value;
			return this;
		}
		auto responseHeader (string key) { return this.responseHeaders[key]; }
		auto responseHeader (string key, string value)
		{
			this._responseHeaders[key] = value;
			return this;
		}
		abstract this (string tmpDir);
		abstract WsApi sendHeaders();
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
		auto method () { return header("REQUEST_METHOD"); }
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
		auto code () { return ws.responseCode; }
		auto code (ushort code)
		{
			ws.responseCode = code;
			return this;
		}
		auto contentType () { return header("Content-Type"); }
		auto contentType (string type) { return header("Content-Type", type); }
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
		string urlPrefix, uri, tailUri;
		string[] captures;
		Variant[] environment;
		this (HttpRequest request, string urlPrefix)
		{
			this.request = request;
			this.urlPrefix = urlPrefix;
			this.uri = request.header("REQUEST_URI");
		}
		auto dispatch (Route[] routes)
		{
			foreach (route; routes)
			{
				auto match = match(tailUri, route.regex);
				if (!match.empty)
				{
					captures = match.captures;
					baseUri ~= uri[0..match.pre.length];
					tailUri = tailUri[match.pre.length..$];
					if (route.handler(this, environment))
						return true;
				}
			}
		}
}
