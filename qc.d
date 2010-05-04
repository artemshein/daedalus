/**
 * Quality control module
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module qc;

import std.stdio;

scope class Test (alias A, string B = "")
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

void assertThrows (ExceptionClass) (void delegate () act)
{
	try
	{
		act();
	}
	catch (ExceptionClass e)
	{
		return;
	}
	catch
	{
		assert(0);
	}
}
