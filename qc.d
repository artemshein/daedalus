module qc;

import std.stdio;

class Test (alias A, string B = "")
{
	protected:
		bool finalized;
	public:	
		this ()
		{
			write(A.stringof ~ B ~ ".....");
		}
		this (void delegate () act)
		{
			this();
			act();
			finalize;
		}
		this (void function () act)
		{
			this();
			act();
			finalize;
		}
		void finalize ()
		{
			if (finalized)
				return;
			writeln("OK");
			finalized = true;
		}
		~this ()
		{
			finalize;
		}
}
