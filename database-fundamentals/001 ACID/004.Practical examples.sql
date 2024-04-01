create table products(
  pid serial primary key,
  name text,
  price float,
  inventory int
);

create table sales(
  saleid serial primary key,
  pid integer,
  price float,
  quantity int
);

insert into
  products(name, price, inventory)
values
  ('phone', 999.99, 100);

-- sale phone - multiple queries in one transaction - atomicity
begin transaction;

update
  products
set
  inventory = inventory - 10
where
  pid = 1;

insert into
  sales(pid, price, quantity)
values
  (1, 999.99, 10);

select
  *
from
  sales;

select
  *
from
  products;

-- sales.quantity + products.inventory = 100 , initial value = consistency
-- other users not see that transaction before commit = isolation
commit;

delete from
  sales;

delete from
  products;

insert into
  products(name, price, inventory)
values
  ('Phone', 999.99, 80);

insert into
  products(name, price, inventory)
values
  ('Earbuds', 99.99, 160);

insert into
  sales(pid, price, quantity)
values
  (1, 999.99, 10),
  (1, 999.99, 5),
  (1, 999.99, 5),
  (2, 99.99, 10),
  (2, 89.99, 10),
  (2, 79.99, 20);

begin transaction;

-- this isolation would solve this problem since it creates a snapshot
-- begin transaction isolation level repeatable read;
select
  pid,
  count(pid)
from
  sales
group by
  pid;

-- 2,3
-- 1,3
-- tx2 in other terminal
-- begin transaction;
-- this is actually writes new row but in postgres repeatable read is the same as snapshot
-- so phantom read won't happen too
-- insert into sales(pid, price, quantity) values(
-- 	1, 999.99, 10
-- );
-- this is just a repeatable read
-- update products set inventory = inventory-10 where pid = 2;
-- commit;
-- tx2 end
select
  pid,
  price,
  quantity
from
  sales;

-- product 1 actually have 4 sales now but we already used previous response in app somewhere
commit;