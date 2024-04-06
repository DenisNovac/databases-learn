# Combining indexes

```sql
create table abc(a integer, b integer, c integer);

insert into
  abc(a, b, c)
select
  floor(random() * 100),
  floor(random() * 100),
  floor(random() * 100)
from
  generate_series(0, 10000000);
```

```sql
create index on abc(a); create index on abc(b);

explain analyze select c from abc where a = 70;

 Bitmap Heap Scan on abc  (cost=559.93..56370.47 rows=50000 width=4) (actual time=32.460..306.950 rows=100473 loops=1)
   Recheck Cond: (a = 70)
   Heap Blocks: exact=45640
   ->  Bitmap Index Scan on abc_a_idx  (cost=0.00..547.43 rows=50000 width=0) (actual time=19.409..19.410 rows=100473 loops=1)
         Index Cond: (a = 70)
 Planning Time: 0.979 ms
 Execution Time: 310.478 ms
```

It used bitmap to query that index because there are a lot of rows and it needs to read c from table. If a was unique it would do just an index scan + one heap jump.

## BitmapAnd

```sql
explain analyze select c from abc where a = 90 and b = 12;


 Bitmap Heap Scan on abc  (cost=2167.64..5699.78 rows=986 width=4) (actual time=39.238..43.195 rows=977 loops=1)
   Recheck Cond: ((b = 12) AND (a = 90))
   Heap Blocks: exact=969
   ->  BitmapAnd  (cost=2167.64..2167.64 rows=986 width=0) (actual time=39.078..39.078 rows=0 loops=1)
         ->  Bitmap Index Scan on abc_b_idx  (cost=0.00..1064.94 rows=97668 width=0) (actual time=26.089..26.089 rows=100375 loops=1)
               Index Cond: (b = 12)
         ->  Bitmap Index Scan on abc_a_idx  (cost=0.00..1101.95 rows=101002 width=0) (actual time=11.203..11.203 rows=100071 loops=1)
               Index Cond: (a = 90)
 Planning Time: 0.337 ms
 Execution Time: 43.994 ms
```

It scans two indices in parallel (-> on the same offset).

Then it sums the bitmap (bitmapAnd) and takes all pages. Then it filters rows on those pages to exclude non-sufficient.

## BitmapOr

```sql
explain analyze select c from abc where a = 90 or b = 12;

 Bitmap Heap Scan on abc  (cost=2265.74..59300.79 rows=197684 width=4) (actual time=36.111..346.396 rows=199469 loops=1)
   Recheck Cond: ((a = 90) OR (b = 12))
   Heap Blocks: exact=52762
   ->  BitmapOr  (cost=2265.74..2265.74 rows=198670 width=0) (actual time=23.488..23.488 rows=0 loops=1)
         ->  Bitmap Index Scan on abc_a_idx  (cost=0.00..1101.95 rows=101002 width=0) (actual time=19.068..19.068 rows=100071 loops=1)
               Index Cond: (a = 90)
         ->  Bitmap Index Scan on abc_b_idx  (cost=0.00..1064.94 rows=97668 width=0) (actual time=4.417..4.417 rows=100375 loops=1)
               Index Cond: (b = 12)
 Planning Time: 0.638 ms
 Execution Time: 352.845 ms
(10 rows)
```

It took longer because OR brings more pages, thus more IO reading amount and more filtering afterwards.

## Composed index

This index more efficient on queries that includes both a and b fields.

```sql
drop index abc_a_idx;
drop index abc_b_idx;

create index on abc(a,b);
```

```sql
explain analyze select c from abc where a = 70;

 Bitmap Heap Scan on abc  (cost=1221.43..56639.92 rows=108000 width=4) (actual time=42.544..531.957 rows=100473 loops=1)
   Recheck Cond: (a = 70)
   Heap Blocks: exact=45640
   ->  Bitmap Index Scan on abc_a_b_idx  (cost=0.00..1194.43 rows=108000 width=0) (actual time=33.399..33.400 rows=100473 loops=1)
         Index Cond: (a = 70)
 Planning Time: 1.030 ms
 Execution Time: 537.113 ms
(7 rows)
```

Since A on left side of the index - postgres still uses an index where search by single a field. Values on the left can be scanned easily. Indices are built left to right.

```sql
explain analyze select c from abc where b = 10;

 Gather  (cost=1000.00..117038.34 rows=99000 width=4) (actual time=21.823..204.583 rows=100922 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on abc  (cost=0.00..106138.34 rows=41250 width=4) (actual time=11.514..160.532 rows=33641 loops=3)
         Filter: (b = 10)
         Rows Removed by Filter: 3299693
 Planning Time: 0.228 ms
 JIT:
   Functions: 12
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.314 ms, Inlining 0.000 ms, Optimization 2.485 ms, Emission 31.911 ms, Total 36.710 ms
 Execution Time: 208.375 ms
(12 rows)
```

Full table scan because index couldn't be used here.

```sql
explain analyze select c from abc where a = 90 and b = 12;

 Bitmap Heap Scan on abc  (cost=14.54..3546.68 rows=986 width=4) (actual time=1.060..15.372 rows=977 loops=1)
   Recheck Cond: ((a = 90) AND (b = 12))
   Heap Blocks: exact=969
   ->  Bitmap Index Scan on abc_a_b_idx  (cost=0.00..14.29 rows=986 width=0) (actual time=0.808..0.808 rows=977 loops=1)
         Index Cond: ((a = 90) AND (b = 12))
 Planning Time: 0.136 ms
 Execution Time: 16.188 ms
```

Best case scenario for composed index.

However, no bonuses for Or queries, they are even more expensive than two separate indices:

```sql
explain analyze select c from abc where a = 90 or b = 12;

 Gather  (cost=1000.00..137323.01 rows=197680 width=4) (actual time=14.829..218.044 rows=199469 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on abc  (cost=0.00..116555.01 rows=82367 width=4) (actual time=8.697..170.395 rows=66490 loops=3)
         Filter: ((a = 90) OR (b = 12))
         Rows Removed by Filter: 3266844
 Planning Time: 0.321 ms
 JIT:
   Functions: 12
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.011 ms, Inlining 0.000 ms, Optimization 1.801 ms, Emission 24.027 ms, Total 27.840 ms
 Execution Time: 224.178 ms
```

### Composed index and separate index

```sql
create index on abc(b);
\d abc
                Table "public.abc"
 Column |  Type   | Collation | Nullable | Default 
--------+---------+-----------+----------+---------
 a      | integer |           |          | 
 b      | integer |           |          | 
 c      | integer |           |          | 
Indexes:
    "abc_a_b_idx" btree (a, b)
    "abc_b_idx" btree (b)
```

And query - same result:

```sql
explain analyze select c from abc where a = 90 and b = 12;

 Bitmap Heap Scan on abc  (cost=14.54..3546.68 rows=986 width=4) (actual time=0.879..11.113 rows=977 loops=1)
   Recheck Cond: ((a = 90) AND (b = 12))
   Heap Blocks: exact=969
   ->  Bitmap Index Scan on abc_a_b_idx  (cost=0.00..14.29 rows=986 width=0) (actual time=0.545..0.546 rows=977 loops=1)
         Index Cond: ((a = 90) AND (b = 12))
 Planning Time: 0.116 ms
 Execution Time: 11.341 ms
```

Or query - optimized:

```sql
explain analyze select c from abc where a = 90 or b = 12;

 Bitmap Heap Scan on abc  (cost=2281.71..59316.72 rows=197680 width=4) (actual time=45.620..470.221 rows=199469 loops=1)
   Recheck Cond: ((a = 90) OR (b = 12))
   Heap Blocks: exact=52762
   ->  BitmapOr  (cost=2281.71..2281.71 rows=198667 width=0) (actual time=34.075..34.075 rows=0 loops=1)
         ->  Bitmap Index Scan on abc_a_b_idx  (cost=0.00..1117.93 rows=101000 width=0) (actual time=27.727..27.727 rows=100071 loops=1)
               Index Cond: (a = 90)
         ->  Bitmap Index Scan on abc_b_idx  (cost=0.00..1064.94 rows=97667 width=0) (actual time=6.344..6.344 rows=100375 loops=1)
               Index Cond: (b = 12)
 Planning Time: 0.393 ms
 Execution Time: 476.752 ms
```

It searches a from index a_b (because a on the left) and use b index to search for b.

