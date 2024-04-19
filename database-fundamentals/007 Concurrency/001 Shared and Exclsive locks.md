# Shared vs Exclusive locks

Exclusive lock (Write lock) - nobody except me can update or read the value. 
Exclusive lock can't be acquired on row with shared lock acquired.

Shared lock (Read lock) - nobody can change that value but anybody 
can read it. 

## Dead Lock

Two clients fight for resource and either of them waits another.


```sql
CREATE TABLE test(
	key integer primary key
);
```

t1:

```sql
-- t1
begin transaction;

-- 1 this is not commited but written and has exclusive lock on value 20
insert into test values(20);

-- 3 wait fot t2
insert into test values(22);
```

```sql
-- t2
begin transaction;

-- 2 normal insert but will acquire lock on it
insert into test values (22);

-- 4 will wait for t1 to complete
insert into test values (20);
```

Database will fail on the latest input (#4), fail the transaction and accept the first one:

```sql
ERROR:  Process 74 waits for ShareLock on transaction 792; blocked by process 72.
Process 72 waits for ShareLock on transaction 795; blocked by process 74.deadlock detected 

ERROR:  deadlock detected
SQL state: 40P01
Detail: Process 74 waits for ShareLock on transaction 792; blocked by process 72.
Process 72 waits for ShareLock on transaction 795; blocked by process 74.
Hint: See server log for query details.
Context: while inserting index tuple (0,6) in relation "test_pkey"
Total rows: 0 of 0
Query complete 00:00:01.049

```

## Two-Phase locks

Acquiring database locks in two phases - first acquire everything you need and then release.

Double-booking problem:

```sql
CREATE TABLE seats(
	id integer primary key,
	isBooked boolean not null,
	name varchar(256)
);


-- t1
begin transaction;

select * from seats where id = 13;

update seats set isbooked = true, name = 'hussein' where id = 13;

select * from seats where id = 13;

-- commits first
commit;



-- t2

begin transaction;

select * from seats where id = 13;

-- it will wait for t1 but then will let to update
update seats set isbooked = true, name = 'denis' where id = 13;

select * from seats where id = 13;

-- commits second
commit;
```

Transactions only check if seat is booked at the beginning,
so they commit after each other and the last who commit
actually gets the seat.

Two-phase locking solution:

```sql
-- t1
begin transaction;

-- it will give an exclusive lock on that row
select * from seats where id = 13 for update;

update seats set isbooked = true, name = 'hussein' where id = 13;

select * from seats where id = 13;

commit;



-- t2
begin transaction;

-- it will stuck until the end of t1
-- then it will return booked = true so we won't update by logic
select * from seats where id = 13 for update;

update seats set isbooked = true, name = 'denis' where id = 13;

select * from seats where id = 13;

commit;
```

`select for update` locks the row for every other transaction with
 `select for update`.

### Another solutions for double booking:

Atomic select with update:

```sql
begin;
update seats set isbooked = true, name = 'denis' where id = 13 and isbooked=0;
commit;
```

`update` acquires exclusive lock which is working much like `select for update`.
So if two transaction will do this - one will wait for another. 
Under the hood db already fetched the entry with `isbooked` = 0. But then
what happens is depends on database:
  - postgres won't update such entry because postgres refreshes the row
    after lock released. And in this example postgres won't find it again
    because `isbooked` has changed;
    - it is happening because postgres has technical row_id outside of table
      heap so it has to go back there;
    - this might not work if isbooked was in index.
  - might not even be intentional, should use select for update instead.



