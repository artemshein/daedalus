module yaml.libyaml;

import core.stdc.stdio;

enum LIB_PATH = "/usr/lib";

pragma(lib, LIB_PATH ~ "/libyaml.a");

enum yaml_error_type_e
{
    /** No error is produced. */
    YAML_NO_ERROR,

    /** Cannot allocate or reallocate a block of memory. */
    YAML_MEMORY_ERROR,

    /** Cannot read or decode the input stream. */
    YAML_READER_ERROR,
    /** Cannot scan the input stream. */
    YAML_SCANNER_ERROR,
    /** Cannot parse the input stream. */
    YAML_PARSER_ERROR,
    /** Cannot compose a YAML document. */
    YAML_COMPOSER_ERROR,

    /** Cannot write to the output stream. */
    YAML_WRITER_ERROR,
    /** Cannot emit a YAML stream. */
    YAML_EMITTER_ERROR
}

alias yaml_error_type_e yaml_error_type_t;

/** Event types. */
enum yaml_event_type_e
{
    /** An empty event. */
    YAML_NO_EVENT,

    /** A STREAM-START event. */
    YAML_STREAM_START_EVENT,
    /** A STREAM-END event. */
    YAML_STREAM_END_EVENT,

    /** A DOCUMENT-START event. */
    YAML_DOCUMENT_START_EVENT,
    /** A DOCUMENT-END event. */
    YAML_DOCUMENT_END_EVENT,

    /** An ALIAS event. */
    YAML_ALIAS_EVENT,
    /** A SCALAR event. */
    YAML_SCALAR_EVENT,

    /** A SEQUENCE-START event. */
    YAML_SEQUENCE_START_EVENT,
    /** A SEQUENCE-END event. */
    YAML_SEQUENCE_END_EVENT,

    /** A MAPPING-START event. */
    YAML_MAPPING_START_EVENT,
    /** A MAPPING-END event. */
    YAML_MAPPING_END_EVENT
}

alias yaml_event_type_e yaml_event_type_t;

/** The character type (UTF-8 octet). */
alias ubyte yaml_char_t;

/** The stream encoding. */
enum yaml_encoding_e
{
    /** Let the parser choose the encoding. */
    YAML_ANY_ENCODING,
    /** The default UTF-8 encoding. */
    YAML_UTF8_ENCODING,
    /** The UTF-16-LE encoding with BOM. */
    YAML_UTF16LE_ENCODING,
    /** The UTF-16-BE encoding with BOM. */
    YAML_UTF16BE_ENCODING
}

alias yaml_encoding_e yaml_encoding_t;

/** Token types. */
enum yaml_token_type_e
{
    /** An empty token. */
    YAML_NO_TOKEN,

    /** A STREAM-START token. */
    YAML_STREAM_START_TOKEN,
    /** A STREAM-END token. */
    YAML_STREAM_END_TOKEN,

    /** A VERSION-DIRECTIVE token. */
    YAML_VERSION_DIRECTIVE_TOKEN,
    /** A TAG-DIRECTIVE token. */
    YAML_TAG_DIRECTIVE_TOKEN,
    /** A DOCUMENT-START token. */
    YAML_DOCUMENT_START_TOKEN,
    /** A DOCUMENT-END token. */
    YAML_DOCUMENT_END_TOKEN,

    /** A BLOCK-SEQUENCE-START token. */
    YAML_BLOCK_SEQUENCE_START_TOKEN,
    /** A BLOCK-SEQUENCE-END token. */
    YAML_BLOCK_MAPPING_START_TOKEN,
    /** A BLOCK-END token. */
    YAML_BLOCK_END_TOKEN,

    /** A FLOW-SEQUENCE-START token. */
    YAML_FLOW_SEQUENCE_START_TOKEN,
    /** A FLOW-SEQUENCE-END token. */
    YAML_FLOW_SEQUENCE_END_TOKEN,
    /** A FLOW-MAPPING-START token. */
    YAML_FLOW_MAPPING_START_TOKEN,
    /** A FLOW-MAPPING-END token. */
    YAML_FLOW_MAPPING_END_TOKEN,

    /** A BLOCK-ENTRY token. */
    YAML_BLOCK_ENTRY_TOKEN,
    /** A FLOW-ENTRY token. */
    YAML_FLOW_ENTRY_TOKEN,
    /** A KEY token. */
    YAML_KEY_TOKEN,
    /** A VALUE token. */
    YAML_VALUE_TOKEN,

    /** An ALIAS token. */
    YAML_ALIAS_TOKEN,
    /** An ANCHOR token. */
    YAML_ANCHOR_TOKEN,
    /** A TAG token. */
    YAML_TAG_TOKEN,
    /** A SCALAR token. */
    YAML_SCALAR_TOKEN
}

alias yaml_token_type_e yaml_token_type_t;

/** Mapping styles. */
enum yaml_mapping_style_e
{
    /** Let the emitter choose the style. */
    YAML_ANY_MAPPING_STYLE,

    /** The block mapping style. */
    YAML_BLOCK_MAPPING_STYLE,
    /** The flow mapping style. */
    YAML_FLOW_MAPPING_STYLE
/*    YAML_FLOW_SET_MAPPING_STYLE   */
}

alias yaml_mapping_style_e yaml_mapping_style_t;

/** Scalar styles. */
enum yaml_scalar_style_e
{
    /** Let the emitter choose the style. */
    YAML_ANY_SCALAR_STYLE,

    /** The plain scalar style. */
    YAML_PLAIN_SCALAR_STYLE,

    /** The single-quoted scalar style. */
    YAML_SINGLE_QUOTED_SCALAR_STYLE,
    /** The double-quoted scalar style. */
    YAML_DOUBLE_QUOTED_SCALAR_STYLE,

    /** The literal scalar style. */
    YAML_LITERAL_SCALAR_STYLE,
    /** The folded scalar style. */
    YAML_FOLDED_SCALAR_STYLE
}

alias yaml_scalar_style_e yaml_scalar_style_t;

/** Sequence styles. */
enum yaml_sequence_style_e
{
    /** Let the emitter choose the style. */
    YAML_ANY_SEQUENCE_STYLE,

    /** The block sequence style. */
    YAML_BLOCK_SEQUENCE_STYLE,
    /** The flow sequence style. */
    YAML_FLOW_SEQUENCE_STYLE
}

alias yaml_sequence_style_e yaml_sequence_style_t;

/** The pointer position. */
struct yaml_mark_s
{
    /** The position index. */
    size_t index;

    /** The position line. */
    size_t line;

    /** The position column. */
    size_t column;
}

alias yaml_mark_s yaml_mark_t;

/**
 * The prototype of a read handler.
 *
 * The read handler is called when the parser needs to read more bytes from the
 * source.  The handler should write not more than @a size bytes to the @a
 * buffer.  The number of written bytes should be set to the @a length variable.
 *
 * @param[in,out]   data        A pointer to an application data specified by
 *                              yaml_parser_set_input().
 * @param[out]      buffer      The buffer to write the data from the source.
 * @param[in]       size        The size of the buffer.
 * @param[out]      size_read   The actual number of bytes read from the source.
 *
 * @returns On success, the handler should return @c 1.  If the handler failed,
 * the returned value should be @c 0.  On EOF, the handler should set the
 * @a size_read to @c 0 and return @c 1.
 */

typedef int function (void* data, ubyte* buffer, size_t size,
        size_t* size_read) yaml_read_handler_t;

/**
 * This structure holds information about a potential simple key.
 */

struct yaml_simple_key_s
{
    /** Is a simple key possible? */
    int possible;

    /** Is a simple key required? */
    int required;

    /** The number of the token. */
    size_t token_number;

    /** The position mark. */
    yaml_mark_t mark;
}

alias yaml_simple_key_s yaml_simple_key_t;

/**
 * The states of the parser.
 */
enum yaml_parser_state_e
{
    /** Expect STREAM-START. */
    YAML_PARSE_STREAM_START_STATE,
    /** Expect the beginning of an implicit document. */
    YAML_PARSE_IMPLICIT_DOCUMENT_START_STATE,
    /** Expect DOCUMENT-START. */
    YAML_PARSE_DOCUMENT_START_STATE,
    /** Expect the content of a document. */
    YAML_PARSE_DOCUMENT_CONTENT_STATE,
    /** Expect DOCUMENT-END. */
    YAML_PARSE_DOCUMENT_END_STATE,
    /** Expect a block node. */
    YAML_PARSE_BLOCK_NODE_STATE,
    /** Expect a block node or indentless sequence. */
    YAML_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE,
    /** Expect a flow node. */
    YAML_PARSE_FLOW_NODE_STATE,
    /** Expect the first entry of a block sequence. */
    YAML_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE,
    /** Expect an entry of a block sequence. */
    YAML_PARSE_BLOCK_SEQUENCE_ENTRY_STATE,
    /** Expect an entry of an indentless sequence. */
    YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE,
    /** Expect the first key of a block mapping. */
    YAML_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE,
    /** Expect a block mapping key. */
    YAML_PARSE_BLOCK_MAPPING_KEY_STATE,
    /** Expect a block mapping value. */
    YAML_PARSE_BLOCK_MAPPING_VALUE_STATE,
    /** Expect the first entry of a flow sequence. */
    YAML_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE,
    /** Expect an entry of a flow sequence. */
    YAML_PARSE_FLOW_SEQUENCE_ENTRY_STATE,
    /** Expect a key of an ordered mapping. */
    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE,
    /** Expect a value of an ordered mapping. */
    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE,
    /** Expect the and of an ordered mapping entry. */
    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE,
    /** Expect the first key of a flow mapping. */
    YAML_PARSE_FLOW_MAPPING_FIRST_KEY_STATE,
    /** Expect a key of a flow mapping. */
    YAML_PARSE_FLOW_MAPPING_KEY_STATE,
    /** Expect a value of a flow mapping. */
    YAML_PARSE_FLOW_MAPPING_VALUE_STATE,
    /** Expect an empty value of a flow mapping. */
    YAML_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE,
    /** Expect nothing. */
    YAML_PARSE_END_STATE
}

alias yaml_parser_state_e yaml_parser_state_t;

/** The tag directive data. */
struct yaml_tag_directive_s
{
    /** The tag handle. */
    yaml_char_t *handle;
    /** The tag prefix. */
    yaml_char_t *prefix;
}

/** The version directive data. */
struct yaml_version_directive_s
{
    /** The major version number. */
    int major;
    /** The minor version number. */
    int minor;
}

alias yaml_version_directive_s yaml_version_directive_t;

alias yaml_tag_directive_s yaml_tag_directive_t;

/**
 * This structure holds aliases data.
 */

struct yaml_alias_data_s
{
    /** The anchor. */
    yaml_char_t *anchor;
    /** The node id. */
    int index;
    /** The anchor mark. */
    yaml_mark_t mark;
}

alias yaml_alias_data_s yaml_alias_data_t;

/** The document structure. */
struct yaml_document_s
{

    /** The document nodes. */
    struct nodes_t
    {
        /** The beginning of the stack. */
        yaml_node_t* start;
        /** The end of the stack. */
        yaml_node_t* end;
        /** The top of the stack. */
        yaml_node_t* top;
    }
    
    nodes_t nodes;

    /** The version directive. */
    yaml_version_directive_t* version_directive;

    /** The list of tag directives. */
    struct tag_directives_t
    {
        /** The beginning of the tag directives list. */
        yaml_tag_directive_t* start;
        /** The end of the tag directives list. */
        yaml_tag_directive_t* end;
    }
    
    alias tag_directives_t tag_directives;

    /** Is the document start indicator implicit? */
    int start_implicit;
    /** Is the document end indicator implicit? */
    int end_implicit;

    /** The beginning of the document. */
    yaml_mark_t start_mark;
    /** The end of the document. */
    yaml_mark_t end_mark;
}

alias yaml_document_s yaml_document_t;

/** The token structure. */
struct yaml_token_s
{

    /** The token type. */
    yaml_token_type_t type;

    /** The token data. */
    union data_t
    {

        /** The stream start (for @c YAML_STREAM_START_TOKEN). */
        struct stream_start_t
        {
            /** The stream encoding. */
            yaml_encoding_t encoding;
        }
        
        stream_start_t stream_start;

        /** The alias (for @c YAML_ALIAS_TOKEN). */
        struct alias_t
        {
            /** The alias value. */
            yaml_char_t *value;
        }
        
        alias_t alias_;

        /** The anchor (for @c YAML_ANCHOR_TOKEN). */
        struct anchor_t
        {
            /** The anchor value. */
            yaml_char_t *value;
        }
        
        anchor_t anchor;

        /** The tag (for @c YAML_TAG_TOKEN). */
        struct tag_t
        {
            /** The tag handle. */
            yaml_char_t *handle;
            /** The tag suffix. */
            yaml_char_t *suffix;
        }
        
        tag_t tag;

        /** The scalar value (for @c YAML_SCALAR_TOKEN). */
        struct scalar_t
        {
            /** The scalar value. */
            yaml_char_t *value;
            /** The length of the scalar value. */
            size_t length;
            /** The scalar style. */
            yaml_scalar_style_t style;
        }
        
        scalar_t scalar;

        /** The version directive (for @c YAML_VERSION_DIRECTIVE_TOKEN). */
        struct version_directive_t
        {
            /** The major version number. */
            int major;
            /** The minor version number. */
            int minor;
        }
        
        version_directive_t version_directive;

        /** The tag directive (for @c YAML_TAG_DIRECTIVE_TOKEN). */
        struct tag_directive_t
        {
            /** The tag handle. */
            yaml_char_t *handle;
            /** The tag prefix. */
            yaml_char_t *prefix;
        }
        
        tag_directive_t tag_directive;
    }
    
    data_t data;

    /** The beginning of the token. */
    yaml_mark_t start_mark;
    /** The end of the token. */
    yaml_mark_t end_mark;

}

alias yaml_token_s yaml_token_t;

struct yaml_parser_s
{

    /**
     * @name Error handling
     * @{
     */

    /** Error type. */
    yaml_error_type_t error;
    /** Error description. */
    const(char)* problem;
    /** The byte about which the problem occured. */
    size_t problem_offset;
    /** The problematic value (@c -1 is none). */
    int problem_value;
    /** The problem position. */
    yaml_mark_t problem_mark;
    /** The error context. */
    const(char)* context;
    /** The context position. */
    yaml_mark_t context_mark;

    /**
     * @}
     */

    /**
     * @name Reader stuff
     * @{
     */

    /** Read handler. */
    yaml_read_handler_t* read_handler;

    /** A pointer for passing to the read handler. */
    void* read_handler_data;

    /** Standard (string or file) input data. */
    union input_t
    {
        /** String input data. */
        struct string_t
        {
            /** The string start pointer. */
            const(ubyte)* start;
            /** The string end pointer. */
            const(ubyte)* end;
            /** The string current position. */
            const(ubyte)* current;
        }
        
        string_t string;

        /** File input data. */
        FILE* file;
    }
    
    input_t input;

    /** EOF flag */
    int eof;

    /** The working buffer. */
    struct buffer_t
    {
        /** The beginning of the buffer. */
        yaml_char_t *start;
        /** The end of the buffer. */
        yaml_char_t *end;
        /** The current position of the buffer. */
        yaml_char_t *pointer;
        /** The last filled position of the buffer. */
        yaml_char_t *last;
    }
    
    buffer_t buffer;

    /* The number of unread characters in the buffer. */
    size_t unread;

    /** The raw buffer. */
    struct raw_buffer_t
    {
        /** The beginning of the buffer. */
        ubyte* start;
        /** The end of the buffer. */
        ubyte* end;
        /** The current position of the buffer. */
        ubyte* pointer;
        /** The last filled position of the buffer. */
        ubyte* last;
    }
    
    raw_buffer_t raw_buffer;

    /** The input encoding. */
    yaml_encoding_t encoding;

    /** The offset of the current position (in bytes). */
    size_t offset;

    /** The mark of the current position. */
    yaml_mark_t mark;

    /**
     * @}
     */

    /**
     * @name Scanner stuff
     * @{
     */

    /** Have we started to scan the input stream? */
    int stream_start_produced;

    /** Have we reached the end of the input stream? */
    int stream_end_produced;

    /** The number of unclosed '[' and '{' indicators. */
    int flow_level;

    /** The tokens queue. */
    struct tokens_t
    {
        /** The beginning of the tokens queue. */
        yaml_token_t* start;
        /** The end of the tokens queue. */
        yaml_token_t* end;
        /** The head of the tokens queue. */
        yaml_token_t* head;
        /** The tail of the tokens queue. */
        yaml_token_t* tail;
    }
    
    tokens_t tokens;

    /** The number of tokens fetched from the queue. */
    size_t tokens_parsed;

    /* Does the tokens queue contain a token ready for dequeueing. */
    int token_available;

    /** The indentation levels stack. */
    struct indents_t
    {
        /** The beginning of the stack. */
        int* start;
        /** The end of the stack. */
        int* end;
        /** The top of the stack. */
        int* top;
    }
    
    indents_t indents;

    /** The current indentation level. */
    int indent;

    /** May a simple key occur at the current position? */
    int simple_key_allowed;

    /** The stack of simple keys. */
    struct simple_keys_t
    {
        /** The beginning of the stack. */
        yaml_simple_key_t *start;
        /** The end of the stack. */
        yaml_simple_key_t *end;
        /** The top of the stack. */
        yaml_simple_key_t *top;
    }
    
    simple_keys_t simple_keys;

    /**
     * @}
     */

    /**
     * @name Parser stuff
     * @{
     */

    /** The parser states stack. */
    struct states_t
    {
        /** The beginning of the stack. */
        yaml_parser_state_t *start;
        /** The end of the stack. */
        yaml_parser_state_t *end;
        /** The top of the stack. */
        yaml_parser_state_t *top;
    }
    
    states_t states;

    /** The current parser state. */
    yaml_parser_state_t state;

    /** The stack of marks. */
    struct marks_t
    {
        /** The beginning of the stack. */
        yaml_mark_t *start;
        /** The end of the stack. */
        yaml_mark_t *end;
        /** The top of the stack. */
        yaml_mark_t *top;
    }
    
    marks_t marks;

    /** The list of TAG directives. */
    struct tag_directives_t
    {
        /** The beginning of the list. */
        yaml_tag_directive_t* start;
        /** The end of the list. */
        yaml_tag_directive_t* end;
        /** The top of the list. */
        yaml_tag_directive_t* top;
    }
    
    tag_directives_t tag_directives;

    /**
     * @}
     */

    /**
     * @name Dumper stuff
     * @{
     */

    /** The alias data. */
    struct aliases_t
    {
        /** The beginning of the list. */
        yaml_alias_data_t* start;
        /** The end of the list. */
        yaml_alias_data_t* end;
        /** The top of the list. */
        yaml_alias_data_t* top;
    }
    
    aliases_t aliases;

    /** The currently parsed document. */
    yaml_document_t* document;

    /**
     * @}
     */

}

alias yaml_parser_s yaml_parser_t;

/** The forward definition of a document node structure. */
struct yaml_node_s;
alias yaml_node_s yaml_node_t;

/** The event structure. */
struct yaml_event_s
{

    /** The event type. */
    yaml_event_type_t type;

    /** The event data. */
    union data_t
    {
        
        /** The stream parameters (for @c YAML_STREAM_START_EVENT). */
        struct stream_start_t
        {
            /** The document encoding. */
            yaml_encoding_t encoding;
        }
        
        stream_start_t stream_start;

        /** The document parameters (for @c YAML_DOCUMENT_START_EVENT). */
        struct document_start_t
        {
            /** The version directive. */
            yaml_version_directive_t *version_directive;

            /** The list of tag directives. */
            struct tag_directives_t
            {
                /** The beginning of the tag directives list. */
                yaml_tag_directive_t *start;
                /** The end of the tag directives list. */
                yaml_tag_directive_t *end;
            }
            
            tag_directives_t tag_directives;

            /** Is the document indicator implicit? */
            int implicit;
        }
        
        document_start_t document_start;

        /** The document end parameters (for @c YAML_DOCUMENT_END_EVENT). */
        struct document_end_t
        {
            /** Is the document end indicator implicit? */
            int implicit;
        }
        
        document_end_t document_end;

        /** The alias parameters (for @c YAML_ALIAS_EVENT). */
        struct alias_t
        {
            /** The anchor. */
            yaml_char_t *anchor;
        }
        
        alias_t alias_;

        /** The scalar parameters (for @c YAML_SCALAR_EVENT). */
        struct scalar_t
        {
            /** The anchor. */
            yaml_char_t *anchor;
            /** The tag. */
            yaml_char_t *tag;
            /** The scalar value. */
            yaml_char_t *value;
            /** The length of the scalar value. */
            size_t length;
            /** Is the tag optional for the plain style? */
            int plain_implicit;
            /** Is the tag optional for any non-plain style? */
            int quoted_implicit;
            /** The scalar style. */
            yaml_scalar_style_t style;
        }
        
        scalar_t scalar;

        /** The sequence parameters (for @c YAML_SEQUENCE_START_EVENT). */
        struct sequence_start_t
        {
            /** The anchor. */
            yaml_char_t *anchor;
            /** The tag. */
            yaml_char_t *tag;
            /** Is the tag optional? */
            int implicit;
            /** The sequence style. */
            yaml_sequence_style_t style;
        }
        
        sequence_start_t sequence_start;

        /** The mapping parameters (for @c YAML_MAPPING_START_EVENT). */
        struct mapping_start_t
        {
            /** The anchor. */
            yaml_char_t *anchor;
            /** The tag. */
            yaml_char_t *tag;
            /** Is the tag optional? */
            int implicit;
            /** The mapping style. */
            yaml_mapping_style_t style;
        }
        
        mapping_start_t mapping_start;

    }
    
     data_t  data;

    /** The beginning of the event. */
    yaml_mark_t start_mark;
    /** The end of the event. */
    yaml_mark_t end_mark;

}

alias yaml_event_s yaml_event_t;

extern(C):

/**
 * Initialize a parser.
 *
 * This function creates a new parser object.  An application is responsible
 * for destroying the object using the yaml_parser_delete() function.
 *
 * @param[out]      parser  An empty parser object.
 *
 * @returns @c 1 if the function succeeded, @c 0 on error.
 */

int yaml_parser_initialize (yaml_parser_t *parser);

/**
 * Set a string input.
 *
 * Note that the @a input pointer must be valid while the @a parser object
 * exists.  The application is responsible for destroing @a input after
 * destroying the @a parser.
 *
 * @param[in,out]   parser  A parser object.
 * @param[in]       input   A source data.
 * @param[in]       size    The length of the source data in bytes.
 */

void yaml_parser_set_input_string (yaml_parser_t *parser,
        const(ubyte)* input, size_t size);

/**
 * Destroy a parser.
 *
 * @param[in,out]   parser  A parser object.
 */

void yaml_parser_delete (yaml_parser_t* parser);

/**
 * Parse the input stream and produce the next parsing event.
 *
 * Call the function subsequently to produce a sequence of events corresponding
 * to the input stream.  The initial event has the type
 * @c YAML_STREAM_START_EVENT while the ending event has the type
 * @c YAML_STREAM_END_EVENT.
 *
 * An application is responsible for freeing any buffers associated with the
 * produced event object using the yaml_event_delete() function.
 *
 * An application must not alternate the calls of yaml_parser_parse() with the
 * calls of yaml_parser_scan() or yaml_parser_load(). Doing this will break the
 * parser.
 *
 * @param[in,out]   parser      A parser object.
 * @param[out]      event       An empty event object.
 *
 * @returns @c 1 if the function succeeded, @c 0 on error.
 */

int yaml_parser_parse(yaml_parser_t *parser, yaml_event_t *event);

