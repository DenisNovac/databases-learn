-- docker exec -it postgres psql -U postgres
create table temp(t int);

insert into
  temp(t)
select
  random() * 100 -- 0 to 100
from
  generate_series(0, 1000000);

-- select random from array
with variances as (
  select
    array ['Yes', 'No', 'Maybe'] as a
)
select
  a [floor(random() * cardinality(a) + 1)]
FROM
  variances;

-- select random from array 100 times
with variances as (
  select
    array [
       'Yes', 
       'No',
       'Maybe'] as a
)
select
  a [floor(random() * cardinality(a) + 1)]
from
  variances v
  left join (
    select
      *
    from
      generate_series(0, 100)
  ) r ON 1 = 1;

-- insert random names to table
create table names(name varchar(256));

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
      generate_series(0, 1000000)
  ) r ON 1 = 1;

select
  name,
  count(*) c
from
  names
group by
  name
order by
  c desc;

-- name   |   c    
-- -------+--------
-- Lena    | 200883
-- Leon    | 100421
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

create table abc(a integer, b integer, c integer);

insert into
  abc(a, b, c)
select
  floor(random() * 100),
  floor(random() * 100),
  floor(random() * 100)
from
  generate_series(0, 10000000);