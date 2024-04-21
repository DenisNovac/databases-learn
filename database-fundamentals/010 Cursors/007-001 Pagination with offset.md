# Pagination with offset

```sql
select title
from news
offset 100
limit 10
```

offset = drop first 100 entries. Database **WILL FETCH** 100 rows before dropping them. So offset-based pagination is ineffective.

also if there was new record added meanwhile - next offset might read the same value again. So offset-based pagination is inconsistent.

```sql
create table news(
  id serial not null,
  a text,
  b text,
  c integer,
  title text
);

create index on news(id);

insert into
  news(a, b, c, title)
select
  'a', 'b',  
  random() * 100, -- 0 to 100
  'title' || (random()*100)::varchar(255)
from
  generate_series(0, 1000000);
```

Let's try to paging on it.

```sql
explain analyze select title from news order by id desc offset 0 limit 10;

 Limit  (cost=0.42..0.77 rows=10 width=27) (actual time=0.030..0.034 rows=10 loops=1)
   ->  Index Scan Backward using news_id_idx on news  (cost=0.42..34317.44 rows=1000001 width=27) (actual time=0.027..0.029 rows=10 loops=1)
 Planning Time: 0.440 ms
 Execution Time: 0.063 ms
(4 rows)
```

We pulled 10 rows: `rows=10`.

Offset 1000:

```sql
explain analyze select title from news order by id desc offset 1000 limit 10;

 Limit  (cost=34.74..35.09 rows=10 width=27) (actual time=0.614..0.622 rows=10 loops=1)
   ->  Index Scan Backward using news_id_idx on news  (cost=0.42..34317.44 rows=1000001 width=27) (actual time=0.214..0.549 rows=1010 loops=1)
 Planning Time: 0.416 ms
 Execution Time: 0.764 ms
(4 rows)
```

We pulled 1010 rows: `rows=1010` and made limit on top of them.

Let's see 100.000 offset:

```sql
explain analyze select title from news order by id desc offset 100000 limit 10;

 Limit  (cost=3432.12..3432.47 rows=10 width=27) (actual time=40.974..40.985 rows=10 loops=1)
   ->  Index Scan Backward using news_id_idx on news  (cost=0.42..34317.44 rows=1000001 width=27) (actual time=0.179..31.647 rows=100010 loops=1)
 Planning Time: 0.279 ms
 Execution Time: 41.133 ms
(4 rows)
```

Yes, we've pulled 100.000 rows.

If it was SQL Server - it would lock them but won't be able to because of size. 

## Fix

We might use id field in this particular case to navigate through pages - user would send us the last id he saw and we could get next few ids. Only works with serial ids obviously.

**Cursors**
