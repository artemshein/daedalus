module type;

auto constCast (string var)
{
	return "cast(const(typeof(" ~ var ~ ")))(" ~ var ~ ")";
}
