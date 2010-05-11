module fixes;

import std.variant;

// Bug in dmd or std.variant

class VariantProxy
{
	Variant v;
	this (Variant v)
	{
		this.v = v;
	}
}
