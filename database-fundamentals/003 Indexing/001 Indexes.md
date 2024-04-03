# Indexes

Index - data structure on top of existing table that looks through table and tries to summarize and create shortcuts to some data.

Every primary key has btree index by default.

```sql
create table names(
  id serial primary key not null,
  name varchar(10) not null
);

-- 11 millions of employees
with variances as (
  select
    array [
       'John', 
       'John',
       'Stan',
       'Lena',
       'Lena', 
       'Matthew',
       'Clair', 
       'Leon', 
       'Richard',
       'Nikita',
       'Samuel',
       'Jacob',
       'Ivan',
       'Nikolai',
       'Timothy',
       'Sam'] as a
)
insert into
  names(name)
select
  a [floor(random() * cardinality(a) + 1)]
from
  variances v
  left join (
    select
      *
    from
      generate_series(0, 11000000)
  ) r ON 1 = 1;
```

```sql
postgres=# select count(*) from names;
  count   
----------
 11000001

postgres=# \d names
                                   Table "public.names"
 Column |         Type          | Collation | Nullable |              Default              
--------+-----------------------+-----------+----------+-----------------------------------
 id     | integer               |           | not null | nextval('names_id_seq'::regclass)
 name   | character varying(12) |           |          | 
Indexes:
    "names_pkey" PRIMARY KEY, btree (id)
```

## Explain: 

### Select indexed value

```sql
explain analyze select id from names where id = 1000;

 Index Only Scan using names_pkey on names  (cost=0.43..4.45 rows=1 width=4) (actual time=0.074..0.075 rows=1 loops=1)
   Index Cond: (id = 1000)
   Heap Fetches: 0
 Planning Time: 0.089 ms
 Execution Time: 0.118 ms
(5 rows)

```

- `Index Only Scan` - we search only for value within index so no other scans;
- `Heap Fetches: 0` - we don't even get into heap since we only asked id and it was in index;


### Select with indexed value in WHERE

```sql
explain analyze select name from names where id = 3000;

 Index Scan using names_pkey on names  (cost=0.43..8.45 rows=1 width=6) (actual time=0.422..0.427 rows=1 loops=1)
   Index Cond: (id = 3000)
 Planning Time: 0.487 ms
 Execution Time: 0.655 ms
(4 rows)
```

We found id in index and get name from table without scanning the heap.
Query is longer because we had to go to actual table to get name. 

Multiple execution will give faster result because of caches.

### Select with non-indexed value in WHERE

```sql
explain analyze select id from names where name = 'Clair';

 Gather  (cost=1000.00..184830.39 rows=678330 width=4) (actual time=8.642..300.514 rows=686556 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on names  (cost=0.00..115997.39 rows=282638 width=4) (actual time=6.270..249.222 rows=228852 loops=3)
         Filter: ((name)::text = 'Clair'::text)
         Rows Removed by Filter: 3437815
 Planning Time: 0.096 ms
 JIT:
   Functions: 12
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.087 ms, Inlining 0.000 ms, Optimization 1.341 ms, Emission 17.219 ms, Total 19.647 ms
 Execution Time: 318.008 ms
(12 rows)
```

We don't have index on name so we perform full table scan.

`Parallel Seq Scan` - means full table scan, slow going through whole table and comparing filter and column.

Postgres optimizes such searches with multiple threads.

### Select with non-indexed value in WHERE LIKE

```sql
-- Leon and Lena could be here
explain analyze select id from names where name like '%Le%';

 Seq Scan on names  (cost=0.00..196205.34 rows=2050757 width=4) (actual time=13.160..1031.478 rows=2062609 loops=1)
   Filter: ((name)::text ~~ '%Le%'::text)
   Rows Removed by Filter: 8937392
 Planning Time: 0.293 ms
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.786 ms, Inlining 0.000 ms, Optimization 1.805 ms, Emission 11.159 ms, Total 14.751 ms
 Execution Time: 1082.676 ms
(9 rows)
```

Its even harder because it is matching instead of equality check.

## Creating an index

```sql
create index idx_names_name on names(name);
```

It is slow because our table already has data.

Search with index using:

```sql
explain analyze select id from names where name = 'Clair';

 Bitmap Heap Scan on names  (cost=7557.52..74742.68 rows=678333 width=4) (actual time=67.552..465.844 rows=686556 loops=1)
   Recheck Cond: ((name)::text = 'Clair'::text)
   Heap Blocks: exact=58705
   ->  Bitmap Index Scan on idx_names_name  (cost=0.00..7387.93 rows=678333 width=0) (actual time=57.898..57.898 rows=686556 loops=1)
         Index Cond: ((name)::text = 'Clair'::text)
 Planning Time: 1.591 ms
 Execution Time: 483.422 ms
```

Bitmap heap scan instead of full scan - faster (not in those numbers but i might trigger some caches on previous Clair request).

Using like:

```sql
explain analyze select id from names where name like '%Le%';


 Seq Scan on names  (cost=0.00..196206.01 rows=2050767 width=4) (actual time=8.722..828.282 rows=2062609 loops=1)
   Filter: ((name)::text ~~ '%Le%'::text)
   Rows Removed by Filter: 8937392
 Planning Time: 0.192 ms
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 3.955 ms, Inlining 0.000 ms, Optimization 0.360 ms, Emission 7.060 ms, Total 11.375 ms
 Execution Time: 879.650 ms
(9 rows)

```

It is slow again and does Seq Scan again. Database doesn't go into index for expressions. Expression is many values and indices only contain specific values for 1:1 equality check.
