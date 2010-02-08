module qc;

import std.stdio;

class Test (alias A)
{
	this ()
	{
		write(A.stringof ~ "...");
	}
	~this ()
	{
		writeln("OK");
	}
}
