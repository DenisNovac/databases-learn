

```bash
 docker exec -it postgres psql -U postgres
```

million rows:

```sql
insert into
  news(a, b, c, title)
select
  'a', 'b',  
  random() * 100, -- 0 to 100
  'title' || (random()*100)::varchar(255)
from
  generate_series(0, 1000000);
```