/**
 * Quality control module
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module qc;

import std.stdio;

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
