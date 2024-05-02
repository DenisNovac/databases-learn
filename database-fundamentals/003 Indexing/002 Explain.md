# Explain

initial state:

```sql
\d names


 Column |         Type          || Nullable |              Default              
--------+-----------------------+-----------+----------+-------------
 id     | integer               || not null | nextval('names_id_seq'::regclass)
 name   | character varying(10) || not null | 

Indexes:
    "names_pkey" PRIMARY KEY, btree (id)
    "idx_names_name" btree (name)
```



Doesn't execute anything, only plans the query.

```sql
explain select * from names;

-- query plan: 
Seq Scan on names  (cost=0.00..168706.01 rows=11000001 width=10)
```

Simplest explain with one line.

`Seq Scan` - full table scan.

Cost = `units of work took to fetch first page - startup cost` .. `units of work took to fetch last page - estimated time to finish`.

Those units are not ms or something, it just relative number.

Startup cost might be increased if there are some planning before fetching such as  aggs, filtering, etc...

`168706` to read through all 11 millions rows.

`rows=11000001` approx. number of rows needed to fetch for query. One can use this thing instead of select count if precise count doesn't matter.

`width=10` - width of the row, amount of bytes taken with one row, sum of all columns.


## Explain with order

```sql
explain select * from names order by name;

 Index Scan using idx_names_name on names  (cost=0.43..436048.14 rows=11000001 width=10)
```

name is index in that table. 

`cost=0.43` - postgres did or attempted to do some work before fetching the row (it has used index so it is fast because indices are sorted).


Without index:

```sql
explain select * from names order by name;
                                      QUERY PLAN                                      
--------------------------------------------------------------------------------------
 Gather Merge  (cost=769298.66..1838817.93 rows=9166668 width=10)
   Workers Planned: 2
   ->  Sort  (cost=768298.63..779756.97 rows=4583334 width=10)
         Sort Key: name
         ->  Parallel Seq Scan on names  (cost=0.00..104539.34 rows=4583334 width=10)
(5 rows)
```

**Works are starting from inside (bottom-up)**. So Parallel Seq Scan happen first.

Tasks planned:
* to sort something that is not in index - it first goes to heap and pull everything (`Parallel Seq Scan`);
* `Sort  (cost=768298.63` amount of time just to START the sorting;
* `Gather Merge` merging of two sorted lists.

## Select indexed PK

```sql
explain select id from names;

 Seq Scan on names  (cost=0.00..168706.01 rows=11000001 width=4)
 JIT:
   Functions: 2
   Options: Inlining false, Optimization false, Expressions true, Deforming true
```

```sql
explain select * from names where id = 10;

 Index Scan using names_pkey on names  (cost=0.43..8.45 rows=1 width=10)
   Index Cond: (id = 10)
(2 rows)
```

Obviously it's fast.


# Size of columns in explain differ from size of column


```sql
explain select name from names;
                                   QUERY PLAN                                    
---------------------------------------------------------------------------------
 Seq Scan on names  (cost=0.00..168706.01 rows=11000001 width=6)
 JIT:
   Functions: 2
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(4 rows)

\d names
 Column |         Type          | Collation | Nullable |              Default              

 id     | integer               |           | not null | nextval('names_id_seq'::regclass)
 name   | character varying(10) |           | not null | 
Indexes:
    "names_pkey" PRIMARY KEY, btree (id)
```

Why varchar(10) takes 6 bytes? Because width is averages size of one entry. Postgres tries to optimize even fixed-size data and don't take all 10 bytes if don't need.


