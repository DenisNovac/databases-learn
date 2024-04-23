# NoSQL vs SQL

Database has frontend part (user io, data formatting) and storage part.

On the storing level you have page which contains bytes. It doesn't matter what you use to request it - SQL or NoSQL bases. 

The difference between NoSQL and SQL dbs mostly on frontend part. 

## MongoDB < 4.2

MMAPv1 - memory map v1 - bunch of data files. It was offset-based. From `_id` it knew which datafile and which offset to read (diskloc).

B-tree index on `_id`.

So it doesn't read the whole datafile. 

The problem - if you update one document - the offset changes so the whole file changes with all documents.

Another problem - MMAP was locking the whole database for each update. Basically it was serialized by default between all transactions.

They changed that to collection-level lock later which is bad too.

## WiredTiger in MongoDB < 5.2

MongoDB changed to **WiredTiger** engine later on. They basically bought the company in 2014 instead of improving their own engine.

- document-level locking;
- page-level compression (really effective since all documents in json and has A LOT of the same text in them);
- search `_id` points to hidden clustered index b+tree `recordId`;
  - `recordId` points to document;
  - `recordId` is tiny - 8 bytes;
  - two lookups `O(logn)`;
  - two writes;
  - `_id` - secondary index;
  - documents are sorted by recordId and placed together;
  - range queries are effective;

## MongoDB > 5.3

Optional clustered collections were introduced. Those collections are clustered around `_id` directly so thats faster.

The problem with that and why you might want to use `recordId`: all secondary indices point to your `_id`. But `_id` field is bigger than `recordId` - 12 bytes. But `_id` could be also anything - like UUIDs or something. So all indices are going to point to those giant ids.
