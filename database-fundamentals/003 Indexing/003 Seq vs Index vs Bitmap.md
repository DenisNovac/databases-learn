# Seq table scan vs Index scan vs Bitmap index scan

Bitmap index scan - postgres-specific.

```sql
postgres=# explain select name from names where id > 100;

 Seq Scan on names  (cost=0.00..196206.01 rows=10999897 width=6)
   Filter: (id > 100)
 JIT:
   Functions: 4
   Options Inlining false, Optimization false, Expressions true, Deforming true
```

Postgres is smart enough to not use index where almost all entries are in answer. It's cheaper to do full scan instead of reading each index and jump into heap. Basically databases contain a lot of stats like indices size, tables size, etc to make such decisions.

But sometimes you have a lot of rows but it is still cheaper to use index. In those cases Postgres do a Bitmap index scan.

## Bitmap index scan

New table with two indices:

```sql
create table grades(
  id serial primary key,
  name varchar(256),
  grade smallint
);

create index idx_grades_grade on grades(grade);

with variances as (
  select
    array [
       'John', 
       'Stan',
       'Lena',
       'Lena', 
       'Matthew',
       'Clair', 
       'Leon', 
       'Richard',
       'Nikita',
       'Sam'] as n
)
insert into
  grades(name, grade)
select
  n [floor(random() * cardinality(n) + 1)],
  floor(random() * 100)
from
  variances v
  left join (
    select
      *
    from
      generate_series(0, 1000000)
  ) r ON 1 = 1;
  
```

```
 id |  name  | grade 
----+--------+-------
  1 | Stan   |    39
  2 | Clair  |    23
  3 | Leon   |    14
  4 | Lena   |    26
```

Seems like PostgreSQL fallbacks to full table scan only where entries > 50% of table.

```sql
explain select name from grades where grade > 50;

 Bitmap Heap Scan on grades  (cost=5444.69..17051.11 rows=496034 width=5)
   Recheck Cond: (grade > 50)
   ->  Bitmap Index Scan on idx_grades_grade  (cost=0.00..5320.68 rows=496034 width=0)
         Index Cond: (grade > 50)


explain select name from grades where grade > 45;

 Seq Scan on grades  (cost=0.00..17906.01 rows=544867 width=5)
   Filter: (grade > 45)
```

- `Bitmap index scan` - first goes through index and mark all pages to retrieve by given filter. And then it does one go to heap and takes all the pages;
- `Recheck cond` - page might contain results that not satisfy the condition so they need to be filtered after reading.

If there are more bi-tree indices in WHERE clause - Postgres might sum multiple bitmap index scans to go to heap only once.


For some reason it doesn't work for serial indices, perhaps that's because they are in serial order and unique:

```sql
explain select name from names where  id < 5000000;

 Index Scan using names_pkey on names  (cost=0.43..169613.77 rows=5017208 width=6)
   Index Cond: (id < 5000000)
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(5 rows)

explain select name from names where  id < 6000000;

 Seq Scan on names  (cost=0.00..196206.01 rows=6018482 width=6)
   Filter: (id < 6000000)
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(5 rows)

```
