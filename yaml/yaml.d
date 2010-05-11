module yaml.yaml;

import core.stdc.string, std.string, std.stdio, std.conv, std.variant, std.regex;
import yaml.libyaml, fixes;

class YamlParser
{
	protected:
		yaml_parser_t parser;
		
	public:
		this ()
		{	
			yaml_parser_initialize(&parser);
		}
		~this ()
		{
			yaml_parser_delete(&parser);
		}
		uint errorCode ()
		{
			return cast(uint)parser.error;
		}
		string errorMsg ()
		{
			switch (errorCode)
			{
				case yaml_error_type_t.YAML_NO_ERROR:
					return "No error is produced.";
				case yaml_error_type_t.YAML_MEMORY_ERROR:
					return "Cannot allocate or reallocate a block of memory.";
				case yaml_error_type_t.YAML_READER_ERROR:
					return "Cannot read or decode the input stream.";
				case yaml_error_type_t.YAML_SCANNER_ERROR:
					return "Cannot scan the input stream.";
				case yaml_error_type_t.YAML_PARSER_ERROR:
					return "Cannot parse the input stream.";
				case yaml_error_type_t.YAML_COMPOSER_ERROR:
					return "Cannot compose a YAML document.";
				case yaml_error_type_t.YAML_WRITER_ERROR:
					return "Cannot write to the output stream.";
				case yaml_error_type_t.YAML_EMITTER_ERROR:
					return "Cannot emit a YAML stream.";
			}
			assert(false, "not implemented");
		}
		VariantProxy[string] parse (string s)
		{
			yaml_event_t event;
			VariantProxy[string] parseMap ()
			{
				VariantProxy[string] res;
				Variant[] seq;
				string mapKey;
				bool valFlag;
				bool seqFlag;
				end_parsing: while (yaml_parser_parse(&parser, &event))
				{
					switch (event.type)
					{
						case yaml_event_type_t.YAML_NO_EVENT:
							return res;
						case yaml_event_type_t.YAML_STREAM_START_EVENT,
							yaml_event_type_t.YAML_DOCUMENT_START_EVENT,
							yaml_event_type_t.YAML_STREAM_END_EVENT,
							yaml_event_type_t.YAML_DOCUMENT_END_EVENT:
							//assert(false, "parse error");
							break;
						case yaml_event_type_t.YAML_ALIAS_EVENT:
							assert(false, "not implemented");
							break;
						case yaml_event_type_t.YAML_SCALAR_EVENT:
							writeln("SCALAR " ~ to!string(cast(char*)event.data.scalar.value));
							if (!valFlag)
								mapKey = to!string(cast(char*)event.data.scalar.value);
							else
								res[mapKey] = new VariantProxy(Variant(to!string(cast(char*)event.data.scalar.value)));
							valFlag = !valFlag;
							break;
						case yaml_event_type_t.YAML_SEQUENCE_START_EVENT:
							assert(valFlag, "parse error");
							seqFlag = true;
							break;
						case yaml_event_type_t.YAML_SEQUENCE_END_EVENT:
							writeln("/SEQUENCE");
							assert(seqFlag, "parse error");
							seqFlag = false;
							break;
						case yaml_event_type_t.YAML_MAPPING_START_EVENT:
							writeln("MAPPING");
							res[mapKey] = new VariantProxy(Variant(parseMap()));
							break;
						case yaml_event_type_t.YAML_MAPPING_END_EVENT:
							writeln("/MAPPING");
							return res;
						default:
							assert(false, "not implemented " ~ to!string(cast(uint)event.type));
					}
				}
				throw new Error(errorMsg);
			}
			auto sz = toStringz(s);
			auto len = strlen(sz);
			yaml_parser_set_input_string(&parser, cast(ubyte*)sz, len);
			do
			{
				if (!yaml_parser_parse(&parser, &event))
					assert(false, "parse error");
			}
			while (event.type != yaml_event_type_t.YAML_MAPPING_START_EVENT);
			return parseMap();
		}
}

string generateYaml (Variant v)
{
	if (typeid(string) == v.type)
		return generateYaml(v.get!string);
	else if (typeid(VariantProxy[string]) == v.type)
		return generateYaml(v.get!(VariantProxy[string]));
	else if (typeid(Variant[]) == v.type)
	{
		string res = "[";
		foreach (val; v.get!(Variant[]))
			res ~= generateYaml(val) ~ ",";
		return res ~ "]";
	}
	assert(false);
}

string generateYaml (string v)
{
	return "\"" ~ replace(v, regex("\"", "g"), "\\\"") ~ "\"";
}

string generateYaml (VariantProxy[string] v)
{
	string res = "{";
	foreach (key, val; v)
	{
		res ~= generateYaml(key) ~ ":";
		if (typeid(Variant[]) == val.v.type)
		{
			res ~= "[";
			foreach (v2; val.v.get!(Variant[]))
				res ~= generateYaml(v2) ~ ",";
			res ~= "]";
		}
		else if (typeid(string) == val.v.type)
			res ~= generateYaml(val.v.get!string) ~ ",";
		else if (typeid(VariantProxy[string]) == val.v.type)
			res ~= generateYaml(val.v.get!(VariantProxy[string])) ~ ",";
		else
			assert(false);
	}
	return res ~ "}";
}
