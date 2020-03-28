P2P Structure
=============

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

further:
    - database can contain apps (runnable code).
