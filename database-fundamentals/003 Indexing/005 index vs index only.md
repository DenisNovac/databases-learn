# Index vs Index only scans

```sql
Column |          Type          |Nullable |              Default               
 id     | integer                | not null | nextval('grades_id_seq'::regclass)
 name   | character varying(256) |          | 
 grade  | smallint               |          | 
```

No indices on that table yet.

```sql
explain analyze select name from grades where id = 7;

 Gather  (cost=1000.00..107139.34 rows=1 width=5) (actual time=7.344..178.054 rows=1 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on grades  (cost=0.00..106139.24 rows=1 width=5) (actual time=80.569..135.177 rows=0 loops=3)
         Filter: (id = 7)
         Rows Removed by Filter: 3333333
 Planning Time: 0.383 ms
 Execution Time: 185.089 ms
```

```sql
create index idx_id on grades(id);

explain analyze select name from grades where id = 7;

 Index Scan using idx_id on grades  (cost=0.43..8.45 rows=1 width=5) (actual time=0.161..0.162 rows=1 loops=1)
   Index Cond: (id = 7)
 Planning Time: 0.732 ms
 Execution Time: 0.222 ms


 explain analyze select id  from grades where id = 7;

 Index Only Scan using idx_id on grades  (cost=0.43..4.45 rows=1 width=4) (actual time=0.350..0.354 rows=1 loops=1)
   Index Cond: (id = 7)
   Heap Fetches: 0
 Planning Time: 0.212 ms
 Execution Time: 0.465 ms
```

Index Scan - we had to go to the table because name is not on index. So we had to go to table too.

Index Only Scan - we didn't go to table at all.

We can put name into index too because we know most of our queries are asking for name:

```sql
postgres=# drop index idx_id;
postgres=# create index idx_grades_id on grades(id) include(name);
postgres=# explain analyze select name from grades where id = 7;

 Index Only Scan using idx_grades_id on grades  (cost=0.43..4.45 rows=1 width=5) (actual time=0.694..0.697 rows=1 loops=1)
   Index Cond: (id = 7)
   Heap Fetches: 0
 Planning Time: 6.234 ms
 Execution Time: 0.795 ms
```

Index Only scan while we requested the name.

```
create index idx_grades_id on grades(id) include(name);
```

- id - key-column, used for search
- name - non-key column, used only after search by id to not go to the table heap.

Of course, expanding the index' size leads to slower index searches.
