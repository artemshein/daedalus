/**
 * Daedalus main module
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module daedalus;

import std.variant;
import http.wsapi, http.cgi, templater, ver;

class Daedalus
{
	public:
		WsApi wsApi;
		Templater tpl;
		Version ver;
		
		this (Variant[string] params)
		{
			ver = new StatusVersion("1d.2.0");
			wsApi = new Cgi(params["tmpDir"].get!string);
			if ("tplsDirs" in params)
			{
				tpl = new Tornado(params["tplsDirs"].get!(string[]), wsApi);
				// Variables
				if ("mediaPrefix" in params)
					tpl.var("mediaPrefix", params["mediaPrefix"]);
				if ("urlPrefix" in params)
					tpl.var("urlPrefix", params["urlPrefix"]);
				tpl.var("version", Variant(ver.toString));
			}
		}
}
