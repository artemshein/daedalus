module type;

string constCast (string var) @safe pure
{
	return "cast(const(typeof(" ~ var ~ ")))(" ~ var ~ ")";
}

bool isA (Class) (in Object o) @trusted
{
	auto otid = typeid(o);
	auto tid = typeid(Class);
	if (otid == tid)
		return true;
	auto base = otid.base;
	return base !is null? isSameOrDerivedFrom(base, tid) : false;
}

bool isSameOrDerivedFrom (in ClassInfo info, in ClassInfo i) @trusted
{
	if (info == i)
		return true;
	auto base = info.base;
	return base !is null? isSameOrDerivedFrom(base, i) : false;		
}
