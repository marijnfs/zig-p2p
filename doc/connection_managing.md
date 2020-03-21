Manage Connections

Resources:
- List of possible connectors (ip addresses), ideally divorced of entities.
  - A connector should also have some sort of rating. I.e how reliable it is, if it's completely new or not.
  - time since last connect would make sense
- List of entities: user name, pub key, rating
- 

Connection topology:
- Incoming: Rep socket for all peers to connect to
- Outgoing: Req sockets for every peer
- Queue: For outgoing messages
- Thread per connection

Connection Management:
- Keep K connections open and active
- Active means host is replying, send simple ping if nothing happens
- A manager checks states of nodes once in a while (polling, could be event based later). Adds connections if needed.

Peer Discovery:
- Once in a while, send request of known peers of a peer (possibly use bloom filter).
- Peer replies with N (new) peers.

- Add peer to new peers.

Message creation:
- Create chat message and add to work list
- Worklist grabs it and send to all connected peers
- Every connection probably needs its' own queue of outgoing messages

Message passing:
- Retrieve message
- Create uid of it (hash)
- Check if message was processed
  - Should this be on connection level? 
  - How to ensure recovery, say temporary connection failure
  - 
