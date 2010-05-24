module yaml.yaml;

import core.stdc.string, std.string, std.stdio, std.conv, std.variant, std.regex;
import yaml.libyaml, fixes;

abstract class YamlElement
{
	public:
}

class YamlScalar: YamlElement
{
	public:
		string value;
		
		this (string value) @safe
		{
			this.value = value;
		}
		hash_t toHash () @trusted const
		{
			return typeid(value).toHash;
		}
}

class YamlSequence: YamlElement
{
	public:
		bool flowMode;
		YamlElement[] elements;
		
		this () @safe
		{}
		this (YamlElement[] elements) @safe
		{
			this.elements = elements;
		}
		typeof(this) opOpAssign (string s) (YamlElement e) @safe if ("~=" == s)
		{
			this.elements ~= e;
			return this;
		}
		YamlElement opIndex (size_t idx) @safe
		{
			return elements[idx];
		}
		size_t length () @safe @property const
		{
			return elements.length;
		}
}

class YamlMapping: YamlElement
{
	protected:
		YamlElement[YamlScalar] elements;
		
	public:
		bool flowStyle;
		
		this (YamlElement[YamlScalar] elements) @safe
		{
			this.elements = elements;
		}
}

class YamlDocument
{
	protected:
		uint level;
		
	public:
		uint indent = 3;
		YamlMapping root;
		
		string scalarAsYaml (YamlScalar scalar)
		{
			
		}
		string mappingAsYaml (YamlMapping mapping, bool forceFlow = false)
		{
			auto flowStyle = forceFlow || mapping.flowStyle;
			string res = flowStyle? "{" : repeat(" ", indent * level);
			foreach (key, el; mapping.elements)
			{
				res ~= scalarAsYaml(key) ~ ":";
				auto type = typeid(el);
				if (isA!YamlMapping(el))
					res ~= mappingAsYaml(cast(YamlMapping) el);
				else if (isA!YamlSequence(el))
					res ~= sequenceAsYaml(cast(YamlSequence) el);
				else if (isA!YamlScalar(el))
					res ~= scalarAsYaml(cast(YamlScalar) el);
				else
					assert(false, "not implemented");
			}
		}
		string asYaml () @safe const
		{
			return mappingAsYaml(root);
		}
}

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
			return cast(uint) parser.error;
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
		YamlScalar parseScalar (yaml_event_t* scalarEvent)
		{
			return new YamlScalar(scalarEvent);
		}
		YamlSequence parseSequence (yaml_event_t* seqEvent)
		{
			auto res = new YamlSequence(seqEvent);
			yaml_event_t event;
			end_parsing: while (yaml_parser_parse(&parser, &event))
			{
				switch (event.type)
				{
					case yaml_event_type_t.YAML_ALIAS_EVENT:
						assert(false, "not implemented");
						break;
					case yaml_event_type_t.YAML_SCALAR_EVENT:
						res ~= parseScalar(&event);
						break;
					case yaml_event_type_t.YAML_SEQUENCE_START_EVENT:
						res ~= parseSequence(&event);
						break;
					case yaml_event_type_t.YAML_MAPPING_START_EVENT:
						res ~= parseMapping(&event);
						break;
					case yaml_event_type_t.YAML_SEQUENCE_END_EVENT:
						break end_parsing;
					default:
						throw new Error("parse error");
				}
			}
			return res;
		}
		YamlMapping parseMapping (yaml_event_t* mapEvent)
		{
			auto res = new YamlMapping(mapEvent);
			yaml_event_t event;
			YamlScalar key;
			end_parsing: while (yaml_parser_parse(&parser, &event))
			{
				switch (event.type)
				{
					case yaml_event_type_t.YAML_ALIAS_EVENT:
						assert(false, "not implemented");
						break;
					case yaml_event_type_t.YAML_SCALAR_EVENT:
						if (key is null)
							key = parseScalar(&event);
						else
						{
							res[key] = parseScalar(&event);
							key = null;
						}
						break;
					case yaml_event_type_t.YAML_SEQUENCE_START_EVENT:
						res ~= parseSequence(&event);
						break;
					case yaml_event_type_t.YAML_MAPPING_START_EVENT:
						res ~= parseMapping(&event);
						break;
					case yaml_event_type_t.YAML_MAPPING_END_EVENT:
						break end_parsing;
					default:
						throw new Error("parse error");
				}
			}
			return res;
		}
		YamlDocument parse (string s)
		{
			auto sz = toStringz(s);
			auto len = strlen(sz);
			yaml_parser_set_input_string(&parser, cast(ubyte*)sz, len);
			yaml_event_t event;
			if (!yaml_parser_parse(&parser, &event))
				throw new Error("parse error");
			if (event.type != yaml_event_type_t.YAML_STREAM_START_EVENT
				&& event.type != yaml_event_type_t.YAML_DOCUMENT_START_EVENT)
				throw new Error("parse error");
			yaml_event_t mapEvent;
			if (mapEvent.type != yaml_event_type_t.YAML_MAPPING_START_EVENT)
				throw new Error("parse error");
			return parseMap(&mapEvent);
		}
}
