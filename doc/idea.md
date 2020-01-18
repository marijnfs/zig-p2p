# Notebook
    - start program anywhere (any computer), connects over network. Given proper private key (any), keeps certain folder up to date. Database (folder) could be more sophisticated like a DB, with markdown lists (main organizing item). DB and folder ideally can both be present at the same time.
    
Chat:
    - again, start program anywere. Given proper key, retrieve chat state. Chat state is a tree probably, of a whole history. Probably want to have a hierarchical structure where a certain key is a mode where which defines a policy / requirement. Like only get tree of last day, or subset of tree (using filter). This should be editable as well, through transactions. Transactions ideally can adress specifically a certain subtree, such that the rest of the tree doesn't need an update. Could be basically a transaction list that gets taken up by blocks, taking up a transaction means adding it to a (sorted in time) list of actions which are applied to the subtree. Then subtree updates, due to parent tree embedding the transactions. 
      - Could even be proven using a homomorphic proof (whatever that is called). Probably just verify whole thing, but means top levels need to prove everything which grows exponentially. Could also be done by proof-of-falseness such that players can't cheat. Penalty would need a timeout, if someone didn't penalize in that time stuff stands. Otherwise no-one can trust a transaction ever.
    - 
    
# Keys
    - Base key: Using key based merkle-tree derivate to generate sub-keys. You probably don't want to use basekey anywhere, apps only see sub-key.
    
# Fiction
    - Flash Fiction board. Simple message board, with pe rsonal ratings. How to keep privacy (you assert you give this part to openness.
    - Program has subtree key, but public part has a subtree of that. Continuously updates by hashing key continuously. Just keep a number that increments (forward safety) as part of the hash-input. 
    - Should define standard _public_ protocol, with forward secrecy keys. In the end though we need ratings, that need a base-trustee to give trust to ratings. Passing on trust to sub-entities would still give a path to this entity, unless sub-entities are very well managed as anonymous ghost entitities. Trust could be transfered in a non-trackable mixing style (like lightning), 
    - This could define base of trust-setup. Could all trees and subtrees use base trust 'currency'? Maybe sub-trees need lightning style commitments to keep them off-chain.

# Life-line
    - Patreon style tree (/or whole sub currency), that keeps donations going, keeps track of what should be public or not (people like to show this, see total donations). Could work to assert certain work in other places to ensure authenticity. Authenticity is the main problem, did the creator create this work. Could use ideas like https signed pages parsing (Should be time-based parsing in case style updates). 
    
# Sub-currenies
