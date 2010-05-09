module fixes;

import std.variant;

// Bug in std.variant

struct VariantProxy
{
	Variant v;
	this (Variant v)
	{
		this.v = v;
	}
}
