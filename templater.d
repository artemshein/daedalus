module templater;

import std.variant;

abstract class Templater
{
	public:
		string[] tplsDirs;
		this (string[] tplsDirs)
		{
			this.tplsDirs = tplsDirs;
		}
		abstract:
			bool display (string);
			string fetch (string);
			bool displayString (string);
			string fetchString (string);
			bool assign (string, Variant);
}

class Tornado: Templater
{
	public:
		this (string[] tplsDirs)
		{
			super(tplsDirs);
			
		}
		
}
