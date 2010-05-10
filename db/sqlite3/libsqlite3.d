module db.sqlite3.libsqlite3;

import config;

pragma(lib, LIB_PATH ~ "/libsqlite3.a");
pragma(lib, LIB_PATH ~ "/libdl.a");
//pragma(lib, LIB_PATH ~ "/libc.a");

enum SQLITE_OK = 0;   /* Successful result */
/* beginning-of-error-codes */
enum SQLITE_ERROR = 1;   /* SQL error or missing database */
enum SQLITE_INTERNAL = 2;   /* Internal logic error in SQLite */
enum SQLITE_PERM = 3;   /* Access permission denied */
enum SQLITE_ABORT = 4;   /* Callback routine requested an abort */
enum SQLITE_BUSY = 5;   /* The database file is locked */
enum SQLITE_LOCKED = 6;   /* A table in the database is locked */
enum SQLITE_NOMEM = 7;   /* A malloc() failed */
enum SQLITE_READONLY = 8;   /* Attempt to write a readonly database */
enum SQLITE_INTERRUPT = 9;   /* Operation terminated by sqlite3_interrupt()*/
enum SQLITE_IOERR = 10;   /* Some kind of disk I/O error occurred */
enum SQLITE_CORRUPT = 11;   /* The database disk image is malformed */
enum SQLITE_NOTFOUND = 12;   /* NOT USED. Table or record not found */
enum SQLITE_FULL = 13;   /* Insertion failed because database is full */
enum SQLITE_CANTOPEN = 14;   /* Unable to open the database file */
enum SQLITE_PROTOCOL = 15;   /* NOT USED. Database lock protocol error */
enum SQLITE_EMPTY = 16;   /* Database is empty */
enum SQLITE_SCHEMA = 17;   /* The database schema changed */
enum SQLITE_TOOBIG = 18;   /* String or BLOB exceeds size limit */
enum SQLITE_CONSTRAINT = 19;   /* Abort due to constraint violation */
enum SQLITE_MISMATCH = 20;   /* Data type mismatch */
enum SQLITE_MISUSE = 21;   /* Library used incorrectly */
enum SQLITE_NOLFS = 22;   /* Uses OS features not supported on host */
enum SQLITE_AUTH = 23;   /* Authorization denied */
enum SQLITE_FORMAT = 24;   /* Auxiliary database format error */
enum SQLITE_RANGE = 25;   /* 2nd parameter to sqlite3_bind out of range */
enum SQLITE_NOTADB = 26;   /* File opened that is not a database file */
enum SQLITE_ROW = 100;  /* sqlite3_step() has another row ready */
enum SQLITE_DONE = 101;  /* sqlite3_step() has finished executing */

enum SQLITE_INTEGER = 1;
enum SQLITE_FLOAT = 2;
enum SQLITE_BLOB = 4;
enum SQLITE_NULL = 5;
enum SQLITE_TEXT = 3;
enum SQLITE3_TEXT = 3;

alias long sqlite3_int64;

struct sqlite3;
struct sqlite3_stmt;

extern(C):
	int sqlite3_open (
		const(char)* filename,   /* Database filename (UTF-8) */
		sqlite3** ppDb          /* OUT: SQLite db handle */
	);
	int sqlite3_open_v2 (
		const(char)* filename,   /* Database filename (UTF-8) */
		sqlite3** ppDb,         /* OUT: SQLite db handle */
		int flags,              /* Flags */
		const(char)* zVfs        /* Name of VFS module to use */
	);
	int sqlite3_close (sqlite3 *);
	int sqlite3_errcode (sqlite3 *db);
	int sqlite3_extended_errcode (sqlite3 *db);
	const(char)* sqlite3_errmsg (sqlite3*);
	int sqlite3_exec (
		sqlite3*,                                  /* An open database */
		const(char)* sql,                           /* SQL to be evaluated */
		int function (void*,int,char**,char**) callback,  /* Callback function */
		void*,                                    /* 1st argument to callback */
		char** errmsg                              /* Error msg written here */
	);
	int sqlite3_prepare_v2 (
		sqlite3 *db,            /* Database handle */
		const(char)* zSql,       /* SQL statement, UTF-8 encoded */
		int nByte,              /* Maximum length of zSql in bytes. */
		sqlite3_stmt **ppStmt,  /* OUT: Statement handle */
		const(char)** pzTail     /* OUT: Pointer to unused portion of zSql */
	);
	int sqlite3_finalize (sqlite3_stmt *pStmt);
	int sqlite3_step(sqlite3_stmt*);
	int sqlite3_column_type(sqlite3_stmt*, int iCol);
	sqlite3_int64 sqlite3_column_int64(sqlite3_stmt*, int iCol);
	int sqlite3_column_int(sqlite3_stmt*, int iCol);
	double sqlite3_column_double(sqlite3_stmt*, int iCol);
	const(char)* sqlite3_column_text(sqlite3_stmt*, int iCol);
	void* sqlite3_column_blob(sqlite3_stmt*, int iCol);
	int sqlite3_column_bytes(sqlite3_stmt*, int iCol);
