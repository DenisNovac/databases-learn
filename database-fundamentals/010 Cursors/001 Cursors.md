# Cursors

Solution to work with large data sets.

You first create cursor and then fetch from it. Database will do the work only on fetches. 

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
      generate_series(0, 10000000)
  ) r ON 1 = 1;
```

How to make a cursor: 

```sql
begin;

declare c cursor for select id from grades where grade between 90 and 100;

-- first row
fetch c;

-- second row
fetch c;

fetch last c;
-- ERROR:  cursor can only scan forward
-- HINT:  Declare it with SCROLL option to enable backward scan
```

Pros:

- save on memory (at least on client side);
- streaming;
- can be canceled;
- paging;
  - not an easy thing to do.

Cons:

- stateful - memory and transaction points to that cursor;
- long transaction.

## Client-side cursor 

Basically you read everything from database and then iterate on results.


