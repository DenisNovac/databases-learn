# WAL, redo, undo

After db said the transaction was committed - i assume the data will be here even if i unplug the db in the next second.

## How transactions are working?

What if we do all those updates in memory to not touch disk on every change? And flush everything to disk on commit. Commit could be expensive if there are a lot of changes. But what if db shut down in the middle of such flushing? 

## Persistent log

So actually dbs has log of what actually changed. This log immediately flushed to disk. It is called **Write-ahead log**. 

This way dirty pages could be kept in memory while you working with them. When we commit - all changes are already kept in log so it could be simply *replayed* to pages on disk.

## Page flushing

But page flushing doesn't actually happens on commit. WAL is always flashed but writing the pages from DB memory happens in random moments because it is expensive (also it is called *checkpoint*). If db shut down in the middle of such flushing - we still have WAL this time and could replay it again on startup.

On checkpoint database stops all operations which could affect some queries.

## fsync

Database is working on top of some Operating System. And OS has own filesystem buffers, it doesn't really write to disk all the time as well as database.

So when database tries to write to disk - it actually ends up in OS buffer. **WAL** is affected too. But database could call system function **fsync** to force that all it's writings are persistent.

## undo log

We might to want to see state of the row before it was changed. It is required for transactions to see old state of the row before other transactions changed it.

Postgres doesn't have undo log because it has versioning. You always have older state of rows.

Other databases take rows and make undo operations on them. Long transactions could require a lot of undo operations. 




















