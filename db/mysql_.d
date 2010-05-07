module mysql;

import db.mysql_com;

alias char my_bool;

extern(C):

alias int my_socket;

export uint mysql_port;
export char* mysql_unix_port;

enum CLIENT_NET_READ_TIMEOUT = 365*24*3600;	/* Timeout on read */
enum CLIENT_NET_WRITE_TIMEOUT = 365*24*3600;	/* Timeout on write */

struct st_mysql_field {
  char *name;                 /* Name of column */
  char *org_name;             /* Original column name, if an alias */
  char *table;                /* Table of column if column was a field */
  char *org_table;            /* Org table name, if table was an alias */
  char *db;                   /* Database for table */
  char *catalog;	      /* Catalog for table */
  char *def;                  /* Default value (set by mysql_list_fields) */
  ulong length;       /* Width of column (create length) */
  ulong max_length;   /* Max width for selected set */
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

alias char** MYSQL_ROW;		/* return data as array of strings */
alias uint MYSQL_FIELD_OFFSET; /* offset to current field */

enum MYSQL_COUNT_ERROR = ~ 0uL;

struct st_mysql_rows {
  st_mysql_rows *next;		/* list of rows */
  MYSQL_ROW data;
  ulong length;
}
alias st_mysql_rows MYSQL_ROWS;

alias MYSQL_ROWS *MYSQL_ROW_OFFSET;	/* offset to current row */

struct embedded_query_result;
alias embedded_query_result EMBEDDED_QUERY_RESULT;
struct st_mysql_data {
  MYSQL_ROWS *data;
  embedded_query_result *embedded_info;
  MEM_ROOT alloc;
  ulong rows;
  uint fields;
  /* extra info for embedded library */
  void *extension;
}
alias st_mysql_data MYSQL_DATA;

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
};

struct st_mysql_options {
  uint connect_timeout, read_timeout, write_timeout;
  uint port, protocol;
  ulong client_flag;
  char* host, user, password, unix_socket, db;
  st_dynamic_array *init_commands;
  char *my_cnf_file, my_cnf_group, charset_dir, charset_name;
  char *ssl_key;				/* PEM key file */
  char *ssl_cert;				/* PEM cert file */
  char *ssl_ca;					/* PEM CA file */
  char *ssl_capath;				/* PEM directory of CA-s? */
  char *ssl_cipher;				/* cipher to use */
  char *shared_memory_base_name;
  ulong max_allowed_packet;
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
  enum mysql_option methods_to_use;
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
};

enum mysql_status 
{
  MYSQL_STATUS_READY,MYSQL_STATUS_GET_RESULT,MYSQL_STATUS_USE_RESULT
};

enum mysql_protocol_type 
{
  MYSQL_PROTOCOL_DEFAULT, MYSQL_PROTOCOL_TCP, MYSQL_PROTOCOL_SOCKET,
  MYSQL_PROTOCOL_PIPE, MYSQL_PROTOCOL_MEMORY
};
/*
  There are three types of queries - the ones that have to go to
  the master, the ones that go to a slave, and the adminstrative
  type which must happen on the pivot connectioin
*/
enum mysql_rpl_type 
{
  MYSQL_RPL_MASTER, MYSQL_RPL_SLAVE, MYSQL_RPL_ADMIN
};

struct character_set
{
  uint      number;     /* character set number              */
  uint      state;      /* character set state               */
  char      *csname;    /* collation name                    */
  char      *name;      /* character set name                */
  char      *comment;   /* comment                           */
  char      *dir;       /* character set directory           */
  uint      mbminlen;   /* min. length for multibyte strings */
  uint      mbmaxlen;   /* max. length for multibyte strings */
}

alias character_set MY_CHARSET_INFO;

struct st_mysql
{
  NET		net;			/* Communication parameters */
  ubyte	*connector_fd;		/* ConnectorFd for SSL */
  char* host, user, passwd, unix_socket, server_version, host_info;
  char* info, db;
  charset_info_st *charset;
  MYSQL_FIELD	*fields;
  MEM_ROOT	field_alloc;
  ulong affected_rows;
  ulong insert_id;		/* id if insert on table with NEXTNR */
  ulong extra_info;		/* Not used */
  ulong thread_id;		/* Id for connection in server */
  ulong packet_length;
  uint	port;
  ulong client_flag,server_capabilities;
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
  char	        scramble[SCRAMBLE_LENGTH+1];

 /*
   Set if this is the original connection, not a master or a slave we have
   added though mysql_rpl_probe() or mysql_set_master()/ mysql_add_slave()
 */
  my_bool rpl_pivot;
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
  void *thd;
  /*
    Points to boolean flag in MYSQL_RES  or MYSQL_STMT. We set this flag 
    from mysql_stmt_close if close had to cancel result set of this object.
  */
  my_bool *unbuffered_fetch_owner;
  /* needed for embedded server - no net buffer to store the 'info' */
  char *info_buffer;
  void *extension;
}
alias st_mysql MYSQL;


struct st_mysql_res {
  ulong  row_count;
  MYSQL_FIELD	*fields;
  MYSQL_DATA	*data;
  MYSQL_ROWS	*data_cursor;
  ulong *lengths;		/* column lengths of current row */
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

enum MAX_MYSQL_MANAGER_ERR = 256;
enum MAX_MYSQL_MANAGER_MSG = 256;

enum MANAGER_OK = 200;
enum MANAGER_INFO = 250;
enum MANAGER_ACCESS = 401;
enum MANAGER_CLIENT_ERR = 450;
enum MANAGER_INTERNAL_ERR = 500;

struct st_mysql_manager
{
  NET net;
  char* host, user, passwd;
  char* net_buf, net_buf_pos, net_data_end;
  uint port;
  int cmd_status;
  int last_errno;
  int net_buf_size;
  my_bool free_me;
  my_bool eof;
  char last_error[MAX_MYSQL_MANAGER_ERR];
  void *extension;
}
alias st_mysql_manager MYSQL_MANAGER;

struct st_mysql_parameters
{
  ulong *p_max_allowed_packet;
  ulong *p_net_buffer_length;
  void *extension;
}
alias st_mysql_parameters MYSQL_PARAMETERS;

/*
  Set up and bring down the server; to ensure that applications will
  work when linked against either the standard client library or the
  embedded server library, these functions should be called.
*/
extern(Windows):

int mysql_server_init(int argc, char **argv, char **groups);
void mysql_server_end();

/*
  mysql_server_init/end need to be called when using libmysqld or
  libmysqlclient (exactly, mysql_server_init() is called by mysql_init() so
  you don't need to call it explicitely; but you need to call
  mysql_server_end() to free memory). The names are a bit misleading
  (mysql_SERVER* to be used when using libmysqlCLIENT). So we add more general
  names which suit well whether you're using libmysqld or libmysqlclient. We
  intend to promote these aliases over the mysql_server* ones.
*/
alias mysql_library_init mysql_server_init;
alias mysql_library_end mysql_server_end;

MYSQL_PARAMETERS* mysql_get_parameters();

/*
  Set up and bring down a thread; these function should be called
  for each thread in an application which opens at least one MySQL
  connection.  All uses of the connection(s) should be between these
  function calls.
*/
my_bool mysql_thread_init();
void mysql_thread_end();

/*
  Functions to get information from the MYSQL and MYSQL_RES structures
  Should definitely be used if one uses shared libraries.
*/

ulong mysql_num_rows(MYSQL_RES *res);
uint mysql_num_fields(MYSQL_RES *res);
my_bool mysql_eof(MYSQL_RES *res);
MYSQL_FIELD* mysql_fetch_field_direct(MYSQL_RES *res, uint fieldnr);
MYSQL_FIELD* mysql_fetch_fields(MYSQL_RES *res);
MYSQL_ROW_OFFSET mysql_row_tell(MYSQL_RES *res);
MYSQL_FIELD_OFFSET mysql_field_tell(MYSQL_RES *res);

uint mysql_field_count(MYSQL *mysql);
ulong mysql_affected_rows(MYSQL *mysql);
ulong mysql_insert_id(MYSQL *mysql);
uint mysql_errno(MYSQL *mysql);
char* mysql_error(MYSQL *mysql);
char* mysql_sqlstate(MYSQL *mysql);
uint mysql_warning_count(MYSQL *mysql);
char* mysql_info(MYSQL *mysql);
ulong mysql_thread_id(MYSQL *mysql);
char* mysql_character_set_name(MYSQL *mysql);
int mysql_set_character_set(MYSQL *mysql, char *csname);

MYSQL* mysql_init(MYSQL *mysql);
my_bool mysql_ssl_set(MYSQL *mysql, char *key,
				      char *cert, char *ca,
				      char *capath, char *cipher);
char* mysql_get_ssl_cipher(MYSQL *mysql);
my_bool mysql_change_user(MYSQL *mysql, char *user, 
					  char *passwd, char *db);
MYSQL* mysql_real_connect(MYSQL *mysql, char *host,
					   char *user,
					   char *passwd,
					   char *db,
					   uint port,
					   char *unix_socket,
					   ulong clientflag);
int mysql_select_db(MYSQL *mysql, char *db);
int mysql_query(MYSQL *mysql, char *q);
int mysql_send_query(MYSQL *mysql, char *q,
					 ulong length);
int mysql_real_query(MYSQL *mysql, char *q,
					ulong length);
MYSQL_RES* mysql_store_result(MYSQL *mysql);
MYSQL_RES* mysql_use_result(MYSQL *mysql);

/* perform query on master */
my_bool mysql_master_query(MYSQL *mysql, char *q,
					   ulong length);
my_bool mysql_master_send_query(MYSQL *mysql, char *q,
						ulong length);
/* perform query on slave */  
my_bool	mysql_slave_query(MYSQL *mysql, char *q,
					  ulong length);
my_bool	mysql_slave_send_query(MYSQL *mysql, char *q,
					       ulong length);
void mysql_get_character_set_info(MYSQL *mysql,
                           MY_CHARSET_INFO *charset);

/* local infile support */

enum LOCAL_INFILE_ERROR_LEN = 512;

/+
void
mysql_set_local_infile_handler(MYSQL *mysql,
                               int function (void **, char *,
                            void *) local_infile_init,
                               int function (void *, char *,
							uint) local_infile_read,
                               void function (void *) local_infile_end,
                               int function (void *, char*,
							 uint) local_infile_error,
                               void *);
+/
void
mysql_set_local_infile_default(MYSQL *mysql);


/*
  enable/disable parsing of all queries to decide if they go on master or
  slave
*/
void mysql_enable_rpl_parse(MYSQL* mysql);
void mysql_disable_rpl_parse(MYSQL* mysql);
/* get the value of the parse flag */  
int mysql_rpl_parse_enabled(MYSQL* mysql);

/*  enable/disable reads from master */
void mysql_enable_reads_from_master(MYSQL* mysql);
void mysql_disable_reads_from_master(MYSQL* mysql);
/* get the value of the master read flag */  
my_bool mysql_reads_from_master_enabled(MYSQL* mysql);

mysql_rpl_type mysql_rpl_query_type(char* q, int len);  

/* discover the master and its slaves */  
my_bool mysql_rpl_probe(MYSQL* mysql);

/* set the master, close/free the old one, if it is not a pivot */
int mysql_set_master(MYSQL* mysql, char* host,
					 uint port,
					 char* user,
					 char* passwd);
int mysql_add_slave(MYSQL* mysql, char* host,
					uint port,
					char* user,
					char* passwd);

int mysql_shutdown(MYSQL *mysql, mysql_enum_shutdown_level shutdown_level);
int mysql_dump_debug_info(MYSQL *mysql);
int mysql_refresh(MYSQL *mysql, uint refresh_options);
int mysql_kill(MYSQL *mysql,ulong pid);
int mysql_set_server_option(MYSQL *mysql, enum_mysql_set_option option);
int mysql_ping(MYSQL *mysql);
char* mysql_stat(MYSQL *mysql);
char* mysql_get_server_info(MYSQL *mysql);
char* mysql_get_client_info(void);
ulong mysql_get_client_version(void);
char* mysql_get_host_info(MYSQL *mysql);
ulong mysql_get_server_version(MYSQL *mysql);
uint mysql_get_proto_info(MYSQL *mysql);
MYSQL_RES* mysql_list_dbs(MYSQL *mysql, char* wild);
MYSQL_RES* mysql_list_tables(MYSQL *mysql, сhar* wild);
MYSQL_RES* mysql_list_processes(MYSQL *mysql);
int mysql_options(MYSQL *mysql, mysql_option option, void *arg);
void mysql_free_result(MYSQL_RES *result);
void mysql_data_seek(MYSQL_RES *result, ulong offset);
MYSQL_ROW_OFFSET mysql_row_seek(MYSQL_RES *result, MYSQL_ROW_OFFSET offset);
MYSQL_FIELD_OFFSET mysql_field_seek(MYSQL_RES *result, MYSQL_FIELD_OFFSET offset);
MYSQL_ROW mysql_fetch_row(MYSQL_RES *result);
ulong* mysql_fetch_lengths(MYSQL_RES *result);
MYSQL_FIELD* mysql_fetch_field(MYSQL_RES *result);
MYSQL_RES* mysql_list_fields(MYSQL *mysql, char *table, char *wild);
ulong mysql_escape_string(char *to, char *from, ulong from_length);
ulong mysql_hex_string(char *to, char *from, ulong from_length);
ulong mysql_real_escape_string(MYSQL *mysql, char* to, char* from, ulong length);
void mysql_debug(char* debug1);
char* mysql_odbc_escape_string(MYSQL *mysql, char* to, ulong to_length, char* from, ulong from_length, void *param, char * function
						 (void *, char *to,
						  ulong *length) extend_buffer);
void myodbc_remove_escape(MYSQL *mysql, char *name);
uint mysql_thread_safe();
my_bool mysql_embedded();
MYSQL_MANAGER*  mysql_manager_init(MYSQL_MANAGER* con);  
MYSQL_MANAGER*  mysql_manager_connect(MYSQL_MANAGER* con,
					      char* host,
					      char* user,
					      char* passwd,
					      uint port);
void mysql_manager_close(MYSQL_MANAGER* con);
int mysql_manager_command(MYSQL_MANAGER* con,
						char* cmd, int cmd_len);
int mysql_manager_fetch_line(MYSQL_MANAGER* con,
						  char* res_buf,
						 int res_buf_size);
my_bool mysql_read_query_result(MYSQL *mysql);


/*
  The following definitions are added for the enhanced 
  client-server protocol
*/

/* statement state */
enum enum_mysql_stmt_state
{
  MYSQL_STMT_INIT_DONE= 1, MYSQL_STMT_PREPARE_DONE, MYSQL_STMT_EXECUTE_DONE,
  MYSQL_STMT_FETCH_DONE
};


/*
  This structure is used to define bind information, and
  internally by the client library.
  Public members with their descriptions are listed below
  (conventionally `On input' refers to the binds given to
  mysql_stmt_bind_param, `On output' refers to the binds given
  to mysql_stmt_bind_result):

  buffer_type    - One of the MYSQL_* types, used to describe
                   the host language type of buffer.
                   On output: if column type is different from
                   buffer_type, column value is automatically converted
                   to buffer_type before it is stored in the buffer.
  buffer         - On input: points to the buffer with input data.
                   On output: points to the buffer capable to store
                   output data.
                   The type of memory pointed by buffer must correspond
                   to buffer_type. See the correspondence table in
                   the comment to mysql_stmt_bind_param.

  The two above members are mandatory for any kind of bind.

  buffer_length  - the length of the buffer. You don't have to set
                   it for any fixed length buffer: float, double,
                   int, etc. It must be set however for variable-length
                   types, such as BLOBs or STRINGs.

  length         - On input: in case when lengths of input values
                   are different for each execute, you can set this to
                   point at a variable containining value length. This
                   way the value length can be different in each execute.
                   If length is not NULL, buffer_length is not used.
                   Note, length can even point at buffer_length if
                   you keep bind structures around while fetching:
                   this way you can change buffer_length before
                   each execution, everything will work ok.
                   On output: if length is set, mysql_stmt_fetch will
                   write column length into it.

  is_null        - On input: points to a boolean variable that should
                   be set to TRUE for NULL values.
                   This member is useful only if your data may be
                   NULL in some but not all cases.
                   If your data is never NULL, is_null should be set to 0.
                   If your data is always NULL, set buffer_type
                   to MYSQL_TYPE_NULL, and is_null will not be used.

  is_unsigned    - On input: used to signify that values provided for one
                   of numeric types are unsigned.
                   On output describes signedness of the output buffer.
                   If, taking into account is_unsigned flag, column data
                   is out of range of the output buffer, data for this column
                   is regarded truncated. Note that this has no correspondence
                   to the sign of result set column, if you need to find it out
                   use mysql_stmt_result_metadata.
  error          - where to write a truncation error if it is present.
                   possible error value is:
                   0  no truncation
                   1  value is out of range or buffer is too small

  Please note that MYSQL_BIND also has internals members.
*/

struct st_mysql_bind
{
  ulong	*length;          /* output length pointer */
  my_bool       *is_null;	  /* Pointer to null indicator */
  void		*buffer;	  /* buffer to get/put data */
  /* set this if you want to track data truncations happened during fetch */
  my_bool       *error;
  ubyte *row_ptr;         /* for the current data position */
  void function (NET *net, st_mysql_bind *param) store_param_func;
  void function (st_mysql_bind *, MYSQL_FIELD *,
                       ubyte **row) fetch_result;
  void function (st_mysql_bind *, MYSQL_FIELD *,
		      ubyte **row) skip_result;
  /* output buffer length, must be set when fetching str/binary */
  ulong buffer_length;
  ulong offset;           /* offset position for char/binary fetch */
  ulong	length_value;     /* Used if length is 0 */
  uint	param_number;	  /* For null count and error messages */
  uint  pack_length;	  /* Internal length for packed data */
  enum_field_types buffer_type;	/* buffer type */
  my_bool       error_value;      /* used if error is 0 */
  my_bool       is_unsigned;      /* set if integer type is unsigned */
  my_bool	long_data_used;	  /* If used with mysql_send_long_data */
  my_bool	is_null_value;    /* Used if is_null is 0 */
  void *extension;
}
alias st_mysql_bind MYSQL_BIND;


/* statement handler */
struct st_mysql_stmt
{
  MEM_ROOT       mem_root;             /* root allocations */
  LIST           list;                 /* list to keep track of all stmts */
  MYSQL          *mysql;               /* connection handle */
  MYSQL_BIND     *params;              /* input parameters */
  MYSQL_BIND     *bind;                /* output parameters */
  MYSQL_FIELD    *fields;              /* result set metadata */
  MYSQL_DATA     result;               /* cached result set */
  MYSQL_ROWS     *data_cursor;         /* current row in cached result */
  /*
    mysql_stmt_fetch() calls this function to fetch one row (it's different
    for buffered, unbuffered and cursor fetch).
  */
  int function (st_mysql_stmt *stmt, 
                                  ubyte **row) read_row_func;
  /* copy of mysql->affected_rows after statement execution */
  ulong   affected_rows;
  ulong   insert_id;            /* copy of mysql->insert_id */
  ulong	 stmt_id;	       /* Id for prepared statement */
  ulong  flags;                /* i.e. type of cursor to open */
  ulong  prefetch_rows;        /* number of rows per one COM_FETCH */
  /*
    Copied from mysql->server_status after execute/fetch to know
    server-side cursor status for this statement.
  */
  uint   server_status;
  uint	 last_errno;	       /* error code */
  uint   param_count;          /* input parameter count */
  uint   field_count;          /* number of columns in result set */
  enum_mysql_stmt_state state;    /* statement state */
  char		 last_error[MYSQL_ERRMSG_SIZE]; /* error message */
  char		 sqlstate[SQLSTATE_LENGTH+1];
  /* Types of input parameters should be sent to server */
  my_bool        send_types_to_server;
  my_bool        bind_param_done;      /* input buffers were supplied */
  ubyte  bind_result_done;     /* output buffers were supplied */
  /* mysql_stmt_close() had to cancel this result */
  my_bool       unbuffered_fetch_cancelled;  
  /*
    Is set to true if we need to calculate field->max_length for 
    metadata fields when doing mysql_stmt_store_result.
  */
  my_bool       update_max_length;     
  void *extension;
}
alias st_mysql_stmt MYSQL_STMT;

enum enum_stmt_attr_type
{
  /*
    When doing mysql_stmt_store_result calculate max_length attribute
    of statement metadata. This is to be consistent with the old API, 
    where this was done automatically.
    In the new API we do that only by request because it slows down
    mysql_stmt_store_result sufficiently.
  */
  STMT_ATTR_UPDATE_MAX_LENGTH,
  /*
    unsigned long with combination of cursor flags (read only, for update,
    etc)
  */
  STMT_ATTR_CURSOR_TYPE,
  /*
    Amount of rows to retrieve from server per one fetch if using cursors.
    Accepts unsigned long attribute in the range 1 - ulong_max
  */
  STMT_ATTR_PREFETCH_ROWS
};


struct st_mysql_methods
{
  my_bool function (MYSQL *mysql) read_query_result;
  my_bool function (MYSQL *mysql,
			      enum_server_command command,
			      ubyte *header,
			      ulong header_length,
			      ubyte *arg,
			      ulong arg_length,
			      my_bool skip_check,
                              MYSQL_STMT *stmt) advanced_command;
  MYSQL_DATA* function (MYSQL *mysql,MYSQL_FIELD *mysql_fields,
			   uint fields) read_rows;
  MYSQL_RES* function (MYSQL *mysql) use_result;
  void function (ulong *to, MYSQL_ROW column, uint field_count) fetch_lengths;
  void function (MYSQL *mysql) flush_use_result;
  MYSQL_FIELD * function (MYSQL *mysql) list_fields;
  my_bool function (MYSQL *mysql, MYSQL_STMT *stmt) read_prepare_result;
  int function (MYSQL_STMT *stmt) stmt_execute;
  int function (MYSQL_STMT *stmt) read_binary_rows;
  int function (MYSQL *mysql, char **row) unbuffered_fetch;
  void function (MYSQL *mysql) free_embedded_thd;
  char* function (MYSQL *mysql) read_statistics;
  my_bool function (MYSQL *mysql) next_result;
  int function (MYSQL *mysql, char *buff, char *passwd) read_change_user_result;
  int function (MYSQL_STMT *stmt) read_rows_from_cursor;
}
alias st_mysql_methods MYSQL_METHODS;


MYSQL_STMT* mysql_stmt_init(MYSQL *mysql);
int mysql_stmt_prepare(MYSQL_STMT *stmt, char *query,
                               ulong length);
int mysql_stmt_execute(MYSQL_STMT *stmt);
int mysql_stmt_fetch(MYSQL_STMT *stmt);
int mysql_stmt_fetch_column(MYSQL_STMT *stmt, MYSQL_BIND *bind_arg, 
                                    uint column,
                                    ulong offset);
int mysql_stmt_store_result(MYSQL_STMT *stmt);
ulong mysql_stmt_param_count(MYSQL_STMT * stmt);
my_bool mysql_stmt_attr_set(MYSQL_STMT *stmt,
                                    enum_stmt_attr_type attr_type,
                                    void *attr);
my_bool mysql_stmt_attr_get(MYSQL_STMT *stmt,
                                    enum_stmt_attr_type attr_type,
                                    void *attr);
my_bool mysql_stmt_bind_param(MYSQL_STMT * stmt, MYSQL_BIND * bnd);
my_bool mysql_stmt_bind_result(MYSQL_STMT * stmt, MYSQL_BIND * bnd);
my_bool mysql_stmt_close(MYSQL_STMT * stmt);
my_bool mysql_stmt_reset(MYSQL_STMT * stmt);
my_bool mysql_stmt_free_result(MYSQL_STMT *stmt);
my_bool mysql_stmt_send_long_data(MYSQL_STMT *stmt, 
                                          uint param_number,
                                          char *data, 
                                          ulong length);
MYSQL_RES* mysql_stmt_result_metadata(MYSQL_STMT *stmt);
MYSQL_RES* mysql_stmt_param_metadata(MYSQL_STMT *stmt);
uint mysql_stmt_errno(MYSQL_STMT * stmt);
char* mysql_stmt_error(MYSQL_STMT * stmt);
char* mysql_stmt_sqlstate(MYSQL_STMT * stmt);
MYSQL_ROW_OFFSET mysql_stmt_row_seek(MYSQL_STMT *stmt, 
                                             MYSQL_ROW_OFFSET offset);
MYSQL_ROW_OFFSET mysql_stmt_row_tell(MYSQL_STMT *stmt);
void mysql_stmt_data_seek(MYSQL_STMT *stmt, ulong offset);
ulong mysql_stmt_num_rows(MYSQL_STMT *stmt);
ulong mysql_stmt_affected_rows(MYSQL_STMT *stmt);
ulong mysql_stmt_insert_id(MYSQL_STMT *stmt);
uint mysql_stmt_field_count(MYSQL_STMT *stmt);

my_bool mysql_commit(MYSQL * mysql);
my_bool mysql_rollback(MYSQL * mysql);
my_bool mysql_autocommit(MYSQL * mysql, my_bool auto_mode);
my_bool mysql_more_results(MYSQL *mysql);
int mysql_next_result(MYSQL *mysql);
void mysql_close(MYSQL *sock);


/* status return codes */
enum MYSQL_NO_DATA = 100;
enum MYSQL_DATA_TRUNCATED = 101;
