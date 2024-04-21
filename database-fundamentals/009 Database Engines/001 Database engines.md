# Database engines

Storage Engine/Embedded database

Software libraries used in DBs for low-level storing of data on disk (CRUD). Some do transactions.

Library that takes care of the disk storage and CRUD operations on disk.
  - can be simple as key-value store;
  - can be rich and complex with full ACID, transactions, foreign keys.

DBMS use engine to build features on top (server, replication, isolation, procedures, etc).

MySQL & MariaDB allows to switch engines. 

Postgres doesn't allow to change that.

## MyISAM

- Indexed Sequential Access Method;
- B-tree indexes point to row directly;
- no transaction;
  - could be done on db level anyway;
- inserts are fast, updates and deletes are problematioc;
- indexes point to the row directly;
- corrupt tables on crash;
- table locking;
- used to be default for MySQL.

by Oracle (people forked it)

Used in system tables storages in many dbs.

### Aria

- fork of MyISAM;
- crash-safe;
- designed for MySQL fork MariaDB.

## InnoDB

- acid transactional;
- replaces MyISAM;
- default for MySQL and MariaDB;
- b+tree with indexes point to PK and PK to row;
  - always has primary key;
- foreign keys;
- tablespaces;
- row locking;
- spatial operations.

by Oracle (people forked it)

### XtraDB

- fork of InnoDB;
- was default in MariaDB;
- couldn't kept up with InnoDB features.

## SQLite

- embedded db for local data;
- B-Tree (LSM as extension);
- Postgres-like syntax;
- Full ACID & table locking;
- Concurrent read & writes;
- Web SQL in browsers uses it;
- Included in many OS.

## Berkeley DB

- key-value embedded database;
- acid transactions, locks, replications;
- used in bitcoin core (switched to LevelDB).

by Oracle

## Level DB

- log structured merge tree (LSM) (great for inserts and SSD);
- no transactions;
- levels of files;
  - memtable;
  - level 0;
  - level 1-6.
- as files grow large levels are merged;
- used in bitcoin blockchain, AutoCad, Minecraft PE.

by Google

## Rocks DB

- fork of LevelDB;
- transactional;
- high performance, multi-threaded compaction;
- many features not in LevelDB;
- MyRocks for MySQL, MariaDB, Percona;
- MongoRocks for MongoDB;
- many more use it.

by Facebook



