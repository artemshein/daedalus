/**
 * Versions
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module ver;

import std.conv, std.string;

abstract class Version
{
	abstract string toString () @safe pure const;
}

class StatusVersion: Version
{
	public:
		uint major, minor;
		string majorStatus, minorStatus, dateRevOrBuild;
		
		invariant ()
		{
			assert(major > 0);
			assert(majorStatus.length <= 1);
			assert(minorStatus.length <= 1);
			assert((majorStatus.length && !minorStatus.length) || (!majorStatus.length && minorStatus.length));
			if (majorStatus.length)
				assert(majorStatus == "d" || majorStatus == "a" || majorStatus == "b" || majorStatus == "r");
			if (minorStatus.length)
				assert(minorStatus == "d" || minorStatus == "a" || minorStatus == "b" || minorStatus == "r");
			assert(dateRevOrBuild.length <= 6);
		}
		
		this (string ver) @safe
		in
		{
			assert(ver.length);
		}
		body
		{
			auto arr = split(ver, ".");
			auto mj = arr[0];
			auto c = mj[$ - 1];
			if ('d' == c || 'b' == c || 'a' == c || 'r' == c)
			{
				majorStatus = mj[$ - 1 .. $];
				major = to!uint(mj[0 .. $ - 1]);
			}
			else
				major = to!uint(mj);
			if (arr.length < 2)
				// Major version only
				return;
			auto mi = arr[1];
			if (mi.length)
			{
				auto c2 = mi[$ - 1];
				if ('d' == c2 || 'b' == c2 || 'a' == c2 || 'r' == c2)
				{
					minorStatus = mi[$ - 1 .. $];
					minor = to!uint(mi[0 .. $ - 1]);
				}
				else
					minor = to!uint(mi);
			}
			if (arr.length < 3)
				// Minor & major parts only
				return;
			dateRevOrBuild = arr[2];
		}
		
		string toString () @safe pure const
		{
			return to!string(major) ~ majorStatus ~ "."
				~ to!string(minor) ~ minorStatus ~ "."
				~ to!string(dateRevOrBuild);
		}
}
