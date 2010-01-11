module templater;

import std.variant;

abstract class Templater
{
	public:
		string[] tplsDirs;
		string urlPrefix, mediaPrefix;
		this (string[] tplsDirs, string urlPrefix, string mediaPrefix)
		{
			this.tplsDirs = tplsDirs;
			this.urlPrefix = urlPrefix;
			this.mediaPrefix = mediaPrefix;
		}
		abstract:
			bool display (string);
			string fetch (string);
			bool displayString (string);
			string fetchString (string);
			bool assign (string, Variant);
} 
