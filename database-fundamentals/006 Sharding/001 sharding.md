# Sharding

Sharding is a process of partitioning table on multiple database servers. It allows to speedup queries.

Partitioning done through certain column - partition id. When you know that id - you could connect to correct server with data you need.

How to evenly spread some abstract string like "5FTOJ" - consistent hashing.

```
Hash("Input 1") = 1
Hash("Input 2") = 1
Hash("Input 3") = 2
```

This should evenly spread string between two shards - 1 and 2.

Simplest example: 

```
num("Input2") % 3
```

Pros:
  - scalability (data, memory);
  - security (users can access certain shards);
  - smaller indices.
  
Cons:
  - complex client (??? what if my sharding not on client);
  - transaction across shards;
  - rollbacks;
  - schema changes are hard;
  - joins.

Looks like the best option for PostgreSQL right now is https://github.com/citusdata/citus 

MySQL tool made by YouTube looks much more mature: https://github.com/vitessio/vitess
