# Replication

## Master/Backup replication

- One master/leader that accepts writes;
- one or more backup/standby nodes that receive writes from master;
- simple to implement, no conflicts;
- can only scale reads.

## Multi-master replication

- Multiple master nodes for writes;
- one or more follower that receive writes from masters;
- conflicts;
- scale writes and reads.

## Sync vs Async replication

- Sync - write transaction waits until some replicas (one or all - could be tweaked in databases) receives updates;
  - so some replicas might be eventually consistent anyway;
  - or it could be fully consistent if you wait for all replicas;
- Async - write is done when written to master, async apply to backup nodes;
  - eventually consistent;
  - fastest transactions.


Setting up of replica requires to modify text configs of Postgres.
