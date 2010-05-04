module ver;

abstract class Version
{
}

class StatusVersion
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
		
		this (string ver)
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
				c = mi[$ - 1];
				if ('d' == c || 'b' == c || 'a' == c || 'r' == c)
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
}
