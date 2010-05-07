module db.my_alloc;

enum ALLOC_MAX_BLOCK_TO_DROP = 4096;
enum ALLOC_MAX_BLOCK_USAGE_BEFORE_DROP = 10;

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
#endif
