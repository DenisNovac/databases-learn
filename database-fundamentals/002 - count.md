# Count(*)

If we do `count(g)` - it will only count `g` that are not null. If g is indexed - it could use index but it will go to heap anyway.

`count(*)` - it doesn't actually collect anything and it could even be index-only scan which is faster than `count(g)`.

Count of big amount of data is expensive anyway. One could use estimate count from query plan which is extremely cheap.

```sql
explain (format json) select count(*) from grades
```


