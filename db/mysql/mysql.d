module db.mysql.mysql;

alias mysql_server_init mysql_library_init;
alias mysql_server_end mysql_library_end;

alias char my_bool;
alias int my_socket;

struct st_vio;
alias st_vio Vio;

enum MYSQL_ERRMSG_SIZE	= 512;

enum SQLSTATE_LENGTH = 5;

struct charset_info_st;

struct st_net {
  Vio *vio;
  ubyte* buff, buff_end, write_pos, read_pos;
  my_socket fd;					/* For Perl DBI/dbd */
  /*
    The following variable is set if we are doing several queries in one
    command ( as in LOAD TABLE ... FROM MASTER ),
    and do not want to confuse the client with OK at the wrong time
  */
  ulong remain_in_buf,length, buf_length, where_b;
  ulong max_packet,max_packet_size;
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

enum enum_field_types { MYSQL_TYPE_DECIMAL, MYSQL_TYPE_TINY,
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

struct st_mysql
{
  NET		net;			/* Communication parameters */
  ubyte* connector_fd;		/* ConnectorFd for SSL */
  char* host, user, passwd, unix_socket, server_version, host_info;
  char* info, db;
  charset_info_st* charset;
  MYSQL_FIELD* fields;
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

extern(C):
	int mysql_server_init(int argc, char **argv, char **groups);
	void mysql_server_end();
	MYSQL* mysql_init(MYSQL *mysql);

