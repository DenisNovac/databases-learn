# Partitioning

## Vertical vs Horizontal

- Horizontal - splitting by rows;
- Vertical - split columns (large columns might be stored in separate own table (even on different disk) to not be read every time you do a page read, e.g. BLOB (BINARY LARGE OBJECT)).

We are going to talk about **horizontal partitioning** here mostly.

## Horizontal partitioning

Partitioning is when you break large table into multiple smaller tables - partitions. Such partitioning allows faster search (because data is smaller) and more concurrent access (because partitions are separated files).

Types of partitions (how to spread the values):

- range;
  - dates, ids;
- list;
  - discrete values (zip codes, states like CA, AL, etc);
- hash;
  - Hash functions (consistent hashing).

### Pros and cons

Pros:
  - improves when query access single partition;
  - sequential scan vs scattered index scan;
  - easy bulk loading (attach partition);
  - archive old data into cheap storage (if partitioned by date).

Cons:
  - updates that moves rows from one partition to another is slow;
  - inefficient queries could scan all partitions which is slower than scan one table;
    - searching through partitioned table should always be done through partition filter;
  - schema changes can be challenging.


## Partitioning vs Sharding

- Partitioning splits table into multiple tables in the same database;
- sharding splits table into multiple tables across multiple database servers;
- Partitioned table name changes (or schema);
- Sharding everything is the same but server changes.

## Practice

We need id not null because we are going to use it as partitioning key.

```sql
create table grades_org(
  id serial not null,
  grade int not null
);

insert into
  grades_org(grade)
select
  floor(random() * 100)
from
  generate_series(0, 10000000);

create index idx_grades_org_g on grades_org(grade);
```

Explains:

```sql
explain analyze select count(*) from grades_org where grade = 30;

 Aggregate  (cost=47661.70..47661.71 rows=1 width=8) (actual time=83.680..83.684 rows=1 loops=1)
   ->  Bitmap Heap Scan on grades_org  (cost=559.93..47536.70 rows=50000 width=0) (actual time=42.174..75.998 rows=100267 loops=1)
         Recheck Cond: (grade = 30)
         Heap Blocks: exact=39790
         ->  Bitmap Index Scan on idx_grades_org_g  (cost=0.00..547.43 rows=50000 width=0) (actual time=31.078..31.079 rows=100267 loops=1)
               Index Cond: (grade = 30)
 Planning Time: 0.496 ms
 Execution Time: 85.963 ms
(8 rows)


explain analyze select count(*) from grades_org where grade > 30 and grade < 50;

 Finalize Aggregate  (cost=35529.60..35529.61 rows=1 width=8) (actual time=115.667..121.586 rows=1 loops=1)
   ->  Gather  (cost=35529.38..35529.59 rows=2 width=8) (actual time=115.536..121.579 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=34529.38..34529.39 rows=1 width=8) (actual time=76.224..76.224 rows=1 loops=3)
               ->  Parallel Index Only Scan using idx_grades_org_g on grades_org  (cost=0.43..32595.35 rows=773615 width=0) (actual time=0.160..41.858 rows=633314 loops=3)
                     Index Cond: ((grade > 30) AND (grade < 50))
                     Heap Fetches: 0
 Planning Time: 0.913 ms
 Execution Time:  121.705 ms
(10 rows)

```

Actual partitioning:

```sql
create table grades_parts(
  id serial not null,
  grade int not null
) partition by range(grade);

-- four partitions
create table g_part0035(like grades_parts including indexes);
create table g_part3560(like grades_parts including indexes);
create table g_part6080(like grades_parts including indexes);
create table g_part80100(like grades_parts including indexes);

alter table grades_parts attach partition g_part0035 for values from (0) to (35);
alter table grades_parts attach partition g_part3560 for values from (35) to (60);
alter table grades_parts attach partition g_part6080 for values from (60) to (80);
alter table grades_parts attach partition g_part80100 for values from (80) to (100);



\d+ grades_parts
                                                 Partitioned table "public.grades_parts"
 Column |  Type   | Collation | Nullable |                 Default                  | Storage | Compression | Stats target | Description 
--------+---------+-----------+----------+------------------------------------------+---------+-------------+--------------+-------------
 id     | integer |           | not null | nextval('grades_parts_id_seq'::regclass) | plain   |             |              | 
 grade  | integer |           | not null |                                          | plain   |             |              | 
Partition key: RANGE (grade)
Partitions: g_part0035 FOR VALUES FROM (0) TO (35),
            g_part3560 FOR VALUES FROM (35) TO (60),
            g_part6080 FOR VALUES FROM (60) TO (80),
            g_part80100 FOR VALUES FROM (80) TO (100)
```

Now we fill the tables:

```sql
-- database will decide automatically which partition to use
insert into grades_parts select * from grades_org;

select max(grade) from grades_parts;
  99

select max(grade) from g_part0035;
  34

select count(*) from g_part0035;
 3501642

-- it will create indices for all partitions
create index idx_grades_parts_grade on grades_parts(grade);
```

Explains:

```sql
 explain analyze select count(*) from grades_parts where grade = 30;

 Aggregate  (cost=2384.05..2384.06 rows=1 width=8) (actual time=12.842..12.842 rows=1 loops=1)
   ->  Index Only Scan using g_part0035_grade_idx on g_part0035 grades_parts  (cost=0.43..2129.60 rows=101781 width=0) (actual time=0.079..7.429 rows=100267 loops=1)
         Index Cond: (grade = 30)
         Heap Fetches: 0
 Planning Time: 3.373 ms
 Execution Time: 12.914 ms

 explain analyze select count(*) from grades_parts where grade > 30 and grade < 50;

 Finalize Aggregate  (cost=40358.36..40358.37 rows=1 width=8) (actual time=139.187..143.710 rows=1 loops=1)
   ->  Gather  (cost=40358.15..40358.36 rows=2 width=8) (actual time=139.102..143.704 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=39358.15..39358.16 rows=1 width=8) (actual time=108.144..108.145 rows=1 loops=3)
               ->  Parallel Append  (cost=0.43..37376.14 rows=792802 width=0) (actual time=0.165..80.216 rows=633314 loops=3)
                     ->  Parallel Index Only Scan using g_part3560_grade_idx on g_part3560 grades_parts_2  (cost=0.43..26332.32 rows=624820 width=0) (actual time=0.088..32.698 rows=500124 loops=3)
                           Index Cond: ((grade > 30) AND (grade < 50))
                           Heap Fetches: 0
                     ->  Parallel Index Only Scan using g_part0035_grade_idx on g_part0035 grades_parts_1  (cost=0.43..7079.81 rows=167982 width=0) (actual time=0.157..19.544 rows=199785 loops=2)
                           Index Cond: ((grade > 30) AND (grade < 50))
                           Heap Fetches: 0
 Planning Time: 1.536 ms
 Execution Time: 143.812 ms
(14 rows)
```

We only hit one partition with this query.

Sizes of tables and indices (bytes):

```sql
select pg_relation_size(oid), relname from pg_class order by pg_relation_size(oid) desc;

 362479616 | grades_org
 126926848 | g_part0035
  90619904 | g_part3560
  72474624 | g_part80100
  72466432 | g_part6080
  69361664 | idx_grades_org_g
  24305664 | g_part0035_grade_idx
  17358848 | g_part3560_grade_idx
  13885440 | g_part6080_grade_idx
  13885440 | g_part80100_grade_idx
         0 | grades_parts
```

Individual indices are smaller so they are faster to fetch.

grades_parts table doesn't contain any actual data.

## Dynamic partitions

E.g. when you have partition by month - you need to create new partition every month. The same goes to partitions by id.

Postgres doesn't have anything to make this automatically (?) so it is required to do in psql or on backend.


### Pruning

Pruning should be ON by default:

```sql
show ENABLE_PARTITION_PRUNING;
 enable_partition_pruning 
--------------------------
 on
```

If this is off - postgres basically doesn't use partition range (and will look into each index of each partition).
