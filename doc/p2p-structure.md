P2P Structure
=============
todo:
	- make dynamic pool (bloom filters)
	- needs set reconciliation, protocol.
	- deserialize multi-type
	- later, make set pool (utreexo)

initial:
- append-only database that is kept in sync.
- sync with bloom filters.
- can be continuous thread / worker items.

- head of database / some local state is not in there:
  - database could have global pointer, this can be updated with a block.
  - ideally block is self-validating (applying rules of tree(block-1) ).
  
storage:
    - database could use key value (flexible).
    - storage like archiver.
    
pools:
	- static pool (block chain)
		- aggregation based / mined pool
		- block updates
	- dynamic pool, keep fast things up to date.
		- deterministic pool
		- as messages show up in pool, send immediately
		- aggregation might contain items you don't have yes
			- you can wait for it to show up, or add directly to get pool
			- item might not exist

further:
    - database can contain apps (runnable code).

chat:
	dynamic storage:
		- chat messages pass around
		- chats could be little items in database
		- every database item should be a transaction
		- but they should be aggregated.
		- problem when to aggregate, aggregation invalidated the future changes.
		- aggregation is transaction that refers to both paths.
			- on validation user can choose path (so shortcut can function, only hash of other side is kept)
			- aggregation has to be a block (should allow for new txs, otherwise doesn't get mined).
				- reward could also come from a pool that pays for compression.

	steps:
		- chat gets created, tx update( chat + roothash ), send around
		- people aggregate deterministically all chats they have active.
		- all chats stay in memory and keep getting synced (needs dynamic bloom pool!)



