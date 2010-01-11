module type;

string constCast (string var)
{
	return "cast(const(typeof(" ~ var ~ ")))(" ~ var ~ ")";
}
