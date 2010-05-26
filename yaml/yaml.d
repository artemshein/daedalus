module yaml.yaml;

import core.stdc.string, std.string, std.stdio, std.conv, std.variant, std.regex;
import yaml.libyaml, type, fixes;

abstract class YamlElement
{
	public:
		bool flowStyle;
		string anchor;
		
		this (yaml_event_t* event) @trusted
		{
			if (event is null)
				return;
			switch (event.type)
			{
				case yaml_event_type_t.YAML_SCALAR_EVENT:
					anchor = to!string(cast(char*) event.data.scalar.anchor);
					break;
				case yaml_event_type_t.YAML_SEQUENCE_START_EVENT:
					anchor = to!string(cast(char*) event.data.sequence_start.anchor);
					break;
				case yaml_event_type_t.YAML_MAPPING_START_EVENT:
					anchor = to!string(cast(char*) event.data.mapping_start.anchor);
					break;
				default:
					throw new Error("not implemented", __FILE__, __LINE__);
			}
		}
}

class YamlScalar: YamlElement
{		
	public:
		string value;
		
		this (string value) @trusted
		{
			super(null);
			if (value.endsWith("\n"))
				value = value[0 .. $ - 1];
			this.value = value;
		}
		this (yaml_event_t* event) @trusted
		in
		{
			assert(event.type == yaml_event_type_t.YAML_SCALAR_EVENT);
		}
		body
		{
			super(event);
			value = to!string(cast(char*)event.data.scalar.value);
			if (value.endsWith("\n"))
				value = value[0 .. $ - 1];
		}
		hash_t toHash () /*@safe const*/
		{
			return typeid(value).getHash(&value);
		}
		int opCmp (Object o) /* @safe const */
		{
			if (this is o)
				return 0;
			if (isA!YamlScalar(o))
				return value > (cast(YamlScalar) o).value;
			throw new Error("not implemented");
		}
}

class YamlSequence: YamlElement
{
	public:
		YamlElement[] elements;
		
		this (YamlElement[] elements) @safe
		{
			super(null);
			this.elements = elements;
		}
		this (yaml_event_t* event) @safe
		in
		{
			assert(event.type == yaml_event_type_t.YAML_SEQUENCE_START_EVENT);
		}
		body
		{
			super(event);
			if (event.data.sequence_start.style == yaml_sequence_style_t.YAML_FLOW_SEQUENCE_STYLE)
				flowStyle = true;
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
	public:
		YamlElement[YamlScalar] elements;
		YamlScalar[] keysOrder;
		bool flowStyle;
		
		this (YamlElement[YamlScalar] elements) @trusted
		{
			super(null);
			this.elements = elements;
			this.keysOrder = elements.keys;
		}
		this (yaml_event_t* event) @safe
		in
		{
			assert(event.type == yaml_event_type_t.YAML_MAPPING_START_EVENT);
		}
		body
		{
			super(event);
			if (event.data.mapping_start.style == yaml_mapping_style_t.YAML_FLOW_MAPPING_STYLE)
				flowStyle = true;
		}
		YamlElement opIndex (YamlScalar idx) @safe
		{
			return elements[idx];
		}
		YamlElement opIndexAssign (YamlElement el, YamlScalar idx)
		{
			if ((idx in elements) is null)
				keysOrder ~= idx;
			elements[idx] = el;
			return el;
		}
}

class YamlDocument
{
	protected:
		uint level;
		
	public:
		uint indent = 3;
		YamlMapping root;
		
		this (YamlMapping mapping) @safe
		{
			root = mapping;
		}
		string scalarAsYaml (in YamlScalar scalar, bool forceFlow = false) @trusted
		{
			/+auto rx = regex("[\"\n:,]");
			if (!scalar.value.match(rx).empty)
				return "\"" ~ replace(scalar.value, "\"", "\\\"") ~ "\"";
			else+/
			if (-1 != scalar.value.indexOf("\n"))
				return "\"" ~ replace(scalar.value, "\"", "\\\"") ~ "\"";
			return scalar.value;
		}
		string sequenceAsYaml (in YamlSequence sequence, bool forceFlow = false) @trusted
		{
			auto flowStyle = forceFlow || sequence.flowStyle;
			string res = flowStyle? "[" : "";
			foreach (i, el; sequence.elements)
			{
				if (flowStyle)
				{
					if (i)
						res ~= ", ";
				}
				else
					if (i)
						res ~= ("\n" ~ repeat(" ", indent * level) ~ "- ");
				auto type = typeid(el);
				if (isA!YamlMapping(el))
					res ~= mappingAsYaml(cast(YamlMapping) el, flowStyle);
				else if (isA!YamlSequence(el))
					res ~= sequenceAsYaml(cast(YamlSequence) el, flowStyle);
				else if (isA!YamlScalar(el))
					res ~= scalarAsYaml(cast(YamlScalar) el, flowStyle);
				else
					throw new Error("invalid element type " ~ to!string(type), __FILE__, __LINE__);
			}
			return flowStyle? (res ~ "]") : res;
		}
		string mappingAsYaml (YamlMapping mapping, bool forceFlow = false) @trusted
		{
			auto flowStyle = forceFlow || mapping.flowStyle;
			string res = flowStyle? "{" : repeat(" ", indent-1);
			bool first = true;
			auto indentStr = repeat(" ", indent * ++level);
			foreach (key; mapping.keysOrder)
			{
				auto el = mapping[key];
				if (!flowStyle)
					res ~= "\n" ~ indentStr;
				if (first)
					first = false;
				else
					if (flowStyle)
						res ~= ", ";
				res ~= scalarAsYaml(key, flowStyle) ~ ": ";
				auto type = typeid(el);
				if (isA!YamlMapping(el))
					res ~= mappingAsYaml(cast(YamlMapping) el, flowStyle);
				else if (isA!YamlSequence(el))
					res ~= sequenceAsYaml(cast(YamlSequence) el, flowStyle);
				else if (isA!YamlScalar(el))
					res ~= scalarAsYaml(cast(YamlScalar) el, flowStyle);
				else
					throw new Error("invalid element type " ~ to!string(type), __FILE__, __LINE__);
			}
			--level;
			return flowStyle? (res ~ "}") : res;
		}
		string asYaml () @safe
		{
			return mappingAsYaml(root);
		}
}

class YamlParser
{
	protected:
		yaml_parser_t parser;
		YamlElement[string] aliases;
		
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
			throw new Error("invalid error code " ~ to!string(errorCode), __FILE__, __LINE__);
		}
		YamlScalar parseScalar (yaml_event_t* scalarEvent)
		{
			auto res = new YamlScalar(scalarEvent);
			if (res.anchor.length)
				aliases[res.anchor] = res;
			return res;
		}
		YamlSequence parseSequence (yaml_event_t* seqEvent)
		{
			auto res = new YamlSequence(seqEvent);
			if (res.anchor.length)
				aliases[res.anchor] = res;
			yaml_event_t event;
			int parseRes;
			end_parsing: while (0 != (parseRes = yaml_parser_parse(&parser, &event)))
			{
				switch (event.type)
				{
					case yaml_event_type_t.YAML_ALIAS_EVENT:
						res ~= aliases[to!string(cast(char*) event.data.alias_.anchor)];
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
						throw new Error("invalid event type " ~ to!string(event.type), __FILE__, __LINE__);
				}
			}
			if (!parseRes)
				throw new Error("parse error: " ~ errorMsg, __FILE__, __LINE__);
			return res;
		}
		YamlMapping parseMapping (yaml_event_t* mapEvent)
		{
			auto res = new YamlMapping(mapEvent);
			if (res.anchor.length)
				aliases[res.anchor] = res;
			yaml_event_t event;
			YamlScalar key;
			int parseRes;
			end_parsing: while (0 != (parseRes = yaml_parser_parse(&parser, &event)))
			{
				switch (event.type)
				{
					case yaml_event_type_t.YAML_ALIAS_EVENT:
						if (key is null)
							throw new Error("parse error", __FILE__, __LINE__);
						else
						{
							res[key] = aliases[to!string(cast(char*) event.data.alias_.anchor)];
							key = null;
						}
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
						if (key is null)
							throw new Error("parse error", __FILE__, __LINE__);
						else
						{
							res[key] = parseSequence(&event);
							key = null;
						}
						break;
					case yaml_event_type_t.YAML_MAPPING_START_EVENT:
						if (key is null)
							throw new Error("parse error", __FILE__, __LINE__);
						else
						{
							res[key] = parseMapping(&event);
							key = null;
						}
						break;
					case yaml_event_type_t.YAML_MAPPING_END_EVENT:
						if (key !is null)
						{
							res[key] = new YamlScalar("");
							key = null;
						}
						break end_parsing;
					default:
						throw new Error("parse error", __FILE__, __LINE__);
				}
			}
			if (!parseRes)
				throw new Error("parse error: " ~ errorMsg, __FILE__, __LINE__);
			return res;
		}
		YamlDocument parse (string s)
		{
			auto sz = toStringz(s);
			auto len = strlen(sz);
			yaml_parser_set_input_string(&parser, cast(ubyte*)sz, len);
			yaml_event_t checkEvent (yaml_event_type_t type)
			{
				yaml_event_t event;
				if (!yaml_parser_parse(&parser, &event))
					throw new Error("parse error", __FILE__, __LINE__);
				if (event.type != type)
					throw new Error("expected event " ~ to!string(event.type) ~ " given " ~ to!string(type), __FILE__, __LINE__);
				return event;
			}
			checkEvent(yaml_event_type_t.YAML_STREAM_START_EVENT);
			checkEvent(yaml_event_type_t.YAML_DOCUMENT_START_EVENT);
			auto mapEvent = checkEvent(yaml_event_type_t.YAML_MAPPING_START_EVENT);
			auto doc = new YamlDocument(parseMapping(&mapEvent));
			checkEvent(yaml_event_type_t.YAML_DOCUMENT_END_EVENT);
			checkEvent(yaml_event_type_t.YAML_STREAM_END_EVENT);
			return doc;
		}
}
