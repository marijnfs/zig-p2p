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

# personal github
    - Sub-tree for keeping Github style repo base. How to store your files in other peoples bases? Periodically pay for hashes of files with new random? Pay extra when retrieving? Or sometimes retrieve completely to test? 
    - Dunno how privacy works here. All files are stored encrypted, you heep hashes. Keep all files organized only for you. Keep storage key-based. One file could be base tree to keep it organized, other files are whole blobs (like archiver / git structure). Base hash retrieve all the rest. Base hash comes from base key.
    
# Sub-currenies
    - How to deal with sub-currencies, like trust currency. What currency type fits trust currency, something more ephemeral?
    - Sub-currencies could be their own apps with clear app intercommunication. Intercommunication could be through a base currency, but maybe something more local is possible. 
    - Somewhere there would be a bottlenecks with maximum transactions. These should not be able to be clogged. 
      - Could be base currency, that is somehow not getting clogged. Is cap flexible? Could someone assume a risk? Would need that there is always money vetted. 
      - A base currency always implies a base distribution; the only way is if anyone can start their own / somehow inflate on volition? How could this be generalized.
      - Base currency inflation could be done under sub-worlds. Inflated sub-currency could be created, and main currency could allow tracking it. Then people can trade base currency for that sub-currency! They could get into contracts that start valueing sub-currency and trading it. Where does it consolidate? Does everything become part of the base currency under a certain condition? Could work, distribution of base currency has happened. However, a completely non-interacting owner would own more. So inflated Base-currency should really inflate it as it becomes part of the real. Basically base currency needs to assume the pretend created by subcurrency, or could get into cents-to-the-dollar contracts. This could be part of the assumption, as slowly the initial proposal + concession = trade deal become new base currency!
    
# Sub-trees.
    - Sub trees are cryptographic bases for specified apps.
    - App definition should be part of the tree.
    - Any data can create a tree, so should be easy if we define how to create this data easily.
    - App name mostly.
    - App hash. Or base trust hash which works with app name (which would mean you just need app name).
    -

# Ratings
    - How would ratings work.
    - Mechanism design, Schulze basis.
    - ratings need to be public, to be verified.
    - Could have anonymous trust-basis using currency. Does the currency here get burned? Can you just pass it along, doesn't seem right. If it gets burned, it should probably by inflationary. Who would want to keep that, people that want to use it. Who would pay for it from a base currency, also people that need it right now. Needs Safe auction currency-sub-currency exchange (SSCE [Safe Sub Currency Exchange]). Needs time-locked contracts and settlement in both (see atomic exchange protocols).
