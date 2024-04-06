# Key vs non-key column indexes

Non-key indexes might not be in every database, but they are in Postgres.

Allows to include some columns inside the index. Not to search for but to retrieve them faster. E.g. grade index with included id. `Select id where grade > 10` won't need to go to the table this way.

How to see indices hits:

```sql
explain (analyze,buffers) select name, grade from grades where grade > 10 and grade < 20 order by grade desc limit 1000;

 Limit  (cost=0.43..263.72 rows=1000 width=7) (actual time=0.369..3.095 rows=1000 loops=1)
   Buffers: shared hit=454 read=4
   ->  Index Scan Backward using idx_grades_grade on grades  (cost=0.43..237040.91 rows=900321 width=7) (actual time=0.365..2.991 rows=1000 loops=1)
         Index Cond: ((grade > 10) AND (grade < 20))
         Buffers: shared hit=454 read=4
 Planning Time: 0.411 ms
 Execution Time: 3.296 ms

```

shared hit = index hit
read = raw reads


```sql
explain (analyze,buffers) select name, grade from grades where grade > 10 and grade < 20 order by grade desc;

 Sort  (cost=180996.15..183246.95 rows=900321 width=7) (actual time=592.735..649.861 rows=899953 loops=1)
   Sort Key: grade DESC
   Sort Method: external merge  Disk: 16240kB
   Buffers: shared hit=3 read=54765 written=9455, temp read=2030 written=2043
   ->  Bitmap Heap Scan on grades  (cost=12084.73..79644.54 rows=900321 width=7) (actual time=94.825..460.044 rows=899953 loops=1)
         Recheck Cond: ((grade > 10) AND (grade < 20))
         Heap Blocks: exact=54055
         Buffers: shared hit=3 read=54765 written=9455
         ->  Bitmap Index Scan on idx_grades_grade  (cost=0.00..11859.65 rows=900321 width=0) (actual time=79.348..79.348 rows=899953 loops=1)
               Index Cond: ((grade > 10) AND (grade < 20))
               Buffers: shared hit=3 read=710
 Planning Time: 0.353 ms
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.892 ms, Inlining 0.000 ms, Optimization 0.595 ms, Emission 7.514 ms, Total 9.002 ms
 Execution Time: 680.736 ms
```

54k IO to disk.

Now we create non-key index:

```sql
postgres=# drop index idx_grades_grade;
DROP INDEX
postgres=# create index idx_grades_grade on grades(grade) include (name);
vacuum;
```


Now the same query is much faster and takes less reads and 0 heap fetches:

```sql
explain (analyze,buffers) select name, grade from grades where grade > 10 and grade < 20 order by grade desc;

 Index Only Scan Backward using idx_grades_grade on grades  (cost=0.43..27123.40 rows=859348 width=7) (actual time=0.787..135.554 rows=899451 loops=1)
   Index Cond: ((grade > 10) AND (grade < 20))
   Heap Fetches: 0
   Buffers: shared hit=25 read=2585 written=976
 Planning Time: 0.482 ms
 Execution Time: 167.452 ms
(6 rows)
```

reads are always happen - index is also on the disk.

```sql
vacuum (verbose) grades;

INFO:  vacuuming "postgres.public.grades"
INFO:  launched 1 parallel vacuum worker for index cleanup (planned: 1)
INFO:  finished vacuuming "postgres.public.grades": index scans: 0
pages: 0 removed, 54055 remain, 1 scanned (0.00% of total)
tuples: 0 removed, 10000175 remain, 0 are dead but not yet removable
removable cutoff: 746, which was 0 XIDs old when operation ended
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
index scan not needed: 0 pages from table (0.00% of total) had 0 dead item identifiers removed
avg read rate: 2.097 MB/s, avg write rate: 0.000 MB/s
buffer usage: 41 hits, 25 misses, 0 dirtied
WAL usage: 0 records, 0 full page images, 0 bytes
system usage: CPU: user: 0.00 s, system: 0.08 s, elapsed: 0.09 s

VACUUM
```
To see if anything is wrong while vacuum.



