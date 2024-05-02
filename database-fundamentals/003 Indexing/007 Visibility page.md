# Visibility page

Sometimes `bitmap heap scan` is used regardless of index because visibility info for transactions is written in table itself. So even if you have and index - sometimes Postgres will hit the table anyway. E.g.: count query. Count could be easily gathered from index but index could be updated by other transaction so it need to recheck count from heap.

Postgres has a visibility page in memory which tells him which pages shouldn't be checked. So not every index check will hit the heap (`vacuum` fill such pages).
