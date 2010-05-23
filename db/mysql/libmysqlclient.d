/**
 * Libmysqlclient wrapper
 *
 * Copyright: $(WEB aisys.ru, Aisys) 2010.
 * License: see LICENSE file.
 * Authors: Artyom Shein.
 */
module db.mysql.libmysqlclient;

import config;

pragma(lib, LIB_PATH ~ "/libmysqlclient.a");

alias mysql_server_init mysql_library_init;
alias mysql_server_end mysql_library_end;

alias char my_bool;
alias int my_socket;
alias ulong my_ulonglong;

// my_sys.h

struct st_dynamic_array
{
  ubyte *buffer;
  uint elements,max_element;
  uint alloc_increment;
  uint size_of_element;
}

alias st_dynamic_array DYNAMIC_ARRAY;

// mysql_com.h

enum SCRAMBLE_LENGTH = 20;

// my_list.h

struct st_list
{
	st_list* prev, next;
	void *data;
}

alias st_list LIST;

// mysql.h

struct st_vio;
alias st_vio Vio;

enum MYSQL_ERRMSG_SIZE	= 512;

enum SQLSTATE_LENGTH = 5;

enum mysql_option 
{
  MYSQL_OPT_CONNECT_TIMEOUT, MYSQL_OPT_COMPRESS, MYSQL_OPT_NAMED_PIPE,
  MYSQL_INIT_COMMAND, MYSQL_READ_DEFAULT_FILE, MYSQL_READ_DEFAULT_GROUP,
  MYSQL_SET_CHARSET_DIR, MYSQL_SET_CHARSET_NAME, MYSQL_OPT_LOCAL_INFILE,
  MYSQL_OPT_PROTOCOL, MYSQL_SHARED_MEMORY_BASE_NAME, MYSQL_OPT_READ_TIMEOUT,
  MYSQL_OPT_WRITE_TIMEOUT, MYSQL_OPT_USE_RESULT,
  MYSQL_OPT_USE_REMOTE_CONNECTION, MYSQL_OPT_USE_EMBEDDED_CONNECTION,
  MYSQL_OPT_GUESS_CONNECTION, MYSQL_SET_CLIENT_IP, MYSQL_SECURE_AUTH,
  MYSQL_REPORT_DATA_TRUNCATION, MYSQL_OPT_RECONNECT,
  MYSQL_OPT_SSL_VERIFY_SERVER_CERT
}

enum mysql_status 
{
  MYSQL_STATUS_READY,MYSQL_STATUS_GET_RESULT,MYSQL_STATUS_USE_RESULT
}

struct st_mysql_methods;
struct charset_info_st;

struct st_net
{
  Vio *vio;
  ubyte* buff, buff_end, write_pos, read_pos;
  my_socket fd;					/* For Perl DBI/dbd */
  /*
    The following variable is set if we are doing several queries in one
    command ( as in LOAD TABLE ... FROM MASTER ),
    and do not want to confuse the client with OK at the wrong time
  */
  uint remain_in_buf,length, buf_length, where_b;
  uint max_packet,max_packet_size;
  uint pkt_nr,compress_pkt_nr;
  uint write_timeout, read_timeout, retry_count;
  int fcntl;
  uint *return_status;
  ubyte reading_or_writing;
  char save_char;
  my_bool unused0; /* Please remove with the next incompatible ABI change. */
  my_bool unused; /* Please remove with the next incompatible ABI change */
  my_bool compress;
  my_bool unused1; /* Please remove with the next incompatible ABI change. */
  /*
    Pointer to query object in query cache, do not equal NULL (0) for
    queries in cache that have not stored its results yet
  */

  /*
    'query_cache_query' should be accessed only via query cache
    functions and methods to maintain proper locking.
  */
  ubyte *query_cache_query;
  uint last_errno;
  ubyte error; 
  my_bool unused2; /* Please remove with the next incompatible ABI change. */
  my_bool return_errno;
  /** Client library error message buffer. Actually belongs to struct MYSQL. */
  char last_error[MYSQL_ERRMSG_SIZE];
  /** Client library sqlstate buffer. Set along with the error message. */
  char sqlstate[SQLSTATE_LENGTH+1];
  void *extension;
}

alias st_net NET;

enum enum_field_types
{
	MYSQL_TYPE_DECIMAL, MYSQL_TYPE_TINY,
	MYSQL_TYPE_SHORT,  MYSQL_TYPE_LONG,
	MYSQL_TYPE_FLOAT,  MYSQL_TYPE_DOUBLE,
	MYSQL_TYPE_NULL,   MYSQL_TYPE_TIMESTAMP,
	MYSQL_TYPE_LONGLONG,MYSQL_TYPE_INT24,
	MYSQL_TYPE_DATE,   MYSQL_TYPE_TIME,
	MYSQL_TYPE_DATETIME, MYSQL_TYPE_YEAR,
	MYSQL_TYPE_NEWDATE, MYSQL_TYPE_VARCHAR,
	MYSQL_TYPE_BIT,
	MYSQL_TYPE_NEWDECIMAL=246,
	MYSQL_TYPE_ENUM=247,
	MYSQL_TYPE_SET=248,
	MYSQL_TYPE_TINY_BLOB=249,
	MYSQL_TYPE_MEDIUM_BLOB=250,
	MYSQL_TYPE_LONG_BLOB=251,
	MYSQL_TYPE_BLOB=252,
	MYSQL_TYPE_VAR_STRING=253,
	MYSQL_TYPE_STRING=254,
	MYSQL_TYPE_GEOMETRY=255
}

struct st_mysql_options
{
  uint connect_timeout, read_timeout, write_timeout;
  uint port, protocol;
  uint client_flag;
  char* host, user, password, unix_socket, db;
  st_dynamic_array *init_commands;
  char *my_cnf_file, my_cnf_group, charset_dir, charset_name;
  char *ssl_key;				/* PEM key file */
  char *ssl_cert;				/* PEM cert file */
  char *ssl_ca;					/* PEM CA file */
  char *ssl_capath;				/* PEM directory of CA-s? */
  char *ssl_cipher;				/* cipher to use */
  char *shared_memory_base_name;
  uint max_allowed_packet;
  my_bool use_ssl;				/* if to use SSL or not */
  my_bool compress,named_pipe;
 /*
   On connect, find out the replication role of the server, and
   establish connections to all the peers
 */
  my_bool rpl_probe;
 /*
   Each call to mysql_real_query() will parse it to tell if it is a read
   or a write, and direct it to the slave or the master
 */
  my_bool rpl_parse;
 /*
   If set, never read from a master, only from slave, when doing
   a read that is replication-aware
 */
  my_bool no_master_reads;
  mysql_option methods_to_use;
  char *client_ip;
  /* Refuse client connecting to server if it uses old (pre-4.1.1) protocol */
  my_bool secure_auth;
  /* 0 - never report, 1 - always report (default) */
  my_bool report_data_truncation;

  /* function pointers for local infile support */
  int function (void **, char *, void *) local_infile_init;
  int function (void *, char *, uint) local_infile_read;
  void function (void *) local_infile_end;
  int function (void *, char *, uint) local_infile_error;
  void *local_infile_userdata;
  void *extension;
}

struct st_used_mem
{				   /* struct for once_alloc (block) */
  st_used_mem *next;	   /* Next block in use */
  uint	left;		   /* memory left in block  */
  uint	size;		   /* size of block */
}

alias st_used_mem USED_MEM;

struct st_mem_root
{
  USED_MEM *free;                  /* blocks with free memory in it */
  USED_MEM *used;                  /* blocks almost without free memory */
  USED_MEM *pre_alloc;             /* preallocated block */
  /* if block have less memory it will be put in 'used' list */
  size_t min_malloc;
  size_t block_size;               /* initial block size */
  uint block_num;          /* allocated blocks counter */
  /* 
     first free block in queue test counter (if it exceed 
     MAX_BLOCK_USAGE_BEFORE_DROP block will be dropped in 'used' list)
  */
  uint first_block_usage;

  void function () error_handler;
}

alias st_mem_root MEM_ROOT;

struct st_mysql_field
{
	char *name;                 /* Name of column */
	char *org_name;             /* Original column name, if an alias */
	char *table;                /* Table of column if column was a field */
	char *org_table;            /* Org table name, if table was an alias */
	char *db;                   /* Database for table */
	char *catalog;	      /* Catalog for table */
	char *def;                  /* Default value (set by mysql_list_fields) */
	uint length;       /* Width of column (create length) */
	uint max_length;   /* Max width for selected set */
	uint name_length;
	uint org_name_length;
	uint table_length;
	uint org_table_length;
	uint db_length;
	uint catalog_length;
	uint def_length;
	uint flags;         /* Div flags */
	uint decimals;      /* Number of decimals in field */
	uint charsetnr;     /* Character set */
	enum_field_types type; /* Type of field. See mysql_com.h for types */
	void *extension;
}

alias st_mysql_field MYSQL_FIELD;

struct st_mysql
{
  NET		net;			/* Communication parameters */
  ubyte* connector_fd;		/* ConnectorFd for SSL */
  char* host, user, passwd, unix_socket, server_version, host_info;
  char* info, db;
  charset_info_st* charset;
  MYSQL_FIELD* fields;
  MEM_ROOT	field_alloc;
  my_ulonglong affected_rows;
  my_ulonglong insert_id;		/* id if insert on table with NEXTNR */
  my_ulonglong extra_info;		/* Not used */
  uint thread_id;		/* Id for connection in server */
  uint packet_length;
  uint	port;
  uint client_flag,server_capabilities;
  uint	protocol_version;
  uint	field_count;
  uint 	server_status;
  uint  server_language;
  uint	warning_count;
  st_mysql_options options;
  mysql_status status;
  my_bool	free_me;		/* If free in mysql_close */
  my_bool	reconnect;		/* set to 1 if automatic reconnect */

  /* session-wide random string */
  char	        scramble[SCRAMBLE_LENGTH + 1];

 /*
   Set if this is the original connection, not a master or a slave we have
   added though mysql_rpl_probe() or mysql_set_master()/ mysql_add_slave()
 */
  char rpl_pivot;
  /*
    Pointers to the master, and the next slave connections, points to
    itself if lone connection.
  */
  st_mysql* master, next_slave;

  st_mysql* last_used_slave; /* needed for round-robin slave pick */
 /* needed for send/read/store/use result to work correctly with replication */
  st_mysql* last_used_con;

  LIST  *stmts;                     /* list of all statements */
  st_mysql_methods *methods;
  void* thd;
  /*
    Points to boolean flag in MYSQL_RES  or MYSQL_STMT. We set this flag 
    from mysql_stmt_close if close had to cancel result set of this object.
  */
  char* unbuffered_fetch_owner;
  /* needed for embedded server - no net buffer to store the 'info' */
  char* info_buffer;
  void* extension;
}

alias st_mysql MYSQL;

typedef char** MYSQL_ROW;

struct st_mysql_rows
{
	st_mysql_rows *next;		/* list of rows */
	MYSQL_ROW data;
	uint length;
}

alias st_mysql_rows MYSQL_ROWS;

struct embedded_query_result;
alias embedded_query_result EMBEDDED_QUERY_RESULT;

struct st_mysql_data
{
  MYSQL_ROWS *data;
  embedded_query_result *embedded_info;
  MEM_ROOT alloc;
  my_ulonglong rows;
  uint fields;
  /* extra info for embedded library */
  void *extension;
}

alias st_mysql_data MYSQL_DATA;

struct st_mysql_res
{
  my_ulonglong  row_count;
  MYSQL_FIELD	*fields;
  MYSQL_DATA	*data;
  MYSQL_ROWS	*data_cursor;
  uint *lengths;		/* column lengths of current row */
  MYSQL		*handle;		/* for unbuffered reads */
  st_mysql_methods *methods;
  MYSQL_ROW	row;			/* If unbuffered read */
  MYSQL_ROW	current_row;		/* buffer to current row */
  MEM_ROOT	field_alloc;
  uint	field_count, current_field;
  my_bool	eof;			/* Used by mysql_fetch_row */
  /* mysql_stmt_close() had to cancel this result */
  my_bool       unbuffered_fetch_cancelled;  
  void *extension;
}

alias st_mysql_res MYSQL_RES;

extern(C):
	int mysql_server_init(int argc, char **argv, char **groups) @trusted;
	void mysql_server_end() @trusted;
	MYSQL* mysql_init(MYSQL*) @trusted;
	void mysql_close(MYSQL*) @trusted;
	MYSQL* mysql_real_connect(MYSQL *mysql, const(char) *host,
		const(char) *user, const(char) *passwd, const(char) *db, uint port,
		const(char) *unix_socket, uint clientflag) @trusted;
	int mysql_query(MYSQL *mysql, const(char) *q) @trusted;
	uint mysql_errno(const(MYSQL) *mysql) @trusted;
	const(char)* mysql_error(const(MYSQL) *mysql) @trusted;
	int mysql_select_db(MYSQL *mysql, const(char) *db) @trusted;
	MYSQL_RES* mysql_store_result(MYSQL *mysql) @trusted;
	MYSQL_ROW mysql_fetch_row(MYSQL_RES *result) @trusted;
	void mysql_free_result(MYSQL_RES *result) @trusted;
	my_ulonglong mysql_affected_rows(const(MYSQL) *mysql) @trusted;
	uint mysql_num_fields(MYSQL_RES *res) @trusted;
	uint* mysql_fetch_lengths(MYSQL_RES *result) @trusted;
	MYSQL_FIELD* mysql_fetch_field(MYSQL_RES *result) @trusted;
	my_ulonglong mysql_num_rows(MYSQL_RES *res) @trusted;
	uint mysql_real_escape_string(const(MYSQL) *mysql,
		char *to, const(char) *from, uint length) @trusted;
	my_ulonglong mysql_insert_id(const(MYSQL) *mysql) @trusted;

