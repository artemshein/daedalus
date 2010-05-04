/**
 * Daedalus main module
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module daedalus;

import std.variant;
import http.wsapi, http.cgi, templater;

class Daedalus
{
	public:
		WsApi wsApi;
		Templater tpl;
		
		this (Variant[string] params)
		{
			wsApi = new Cgi(params["tmpDir"].get!string);
			if ("tplsDirs" in params)
			{
				tpl = new Tornado(params["tplsDirs"].get!(string[]), wsApi);
				if ("mediaPrefix" in params)
					tpl.var("mediaPrefix", params["mediaPrefix"]);
				if ("urlPrefix" in params)
					tpl.var("urlPrefix", params["urlPrefix"]);
			}
		}
}
