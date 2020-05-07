# c.zig #c codes
# p2p.zig #master
# connection_management.zig
	+ outgoing_connections
	+ known_addresses
	+ muxtex
	+ zmq_context
	- init
	OutgoingConnection
		- init/deinit
		- connect
		- queue_event
		- start_event_loop
		+ connection_point
		+ event_queue
		+ socket
		+ active
#router.zig
	RouteId [4]u8
	RouteIdMessage
		+ id RouteId
		+ buffer
		- deinit
	Router
		+ socket
		+ reply_queue(RouterIdMessage)
		+ bind_point
		+ pull_bind_point
		+ callback
		+ allocator
		- init/deinit
		- add_route(tag, context, func)
		- queue_message
		- start_writer #reply queue to router
		- start_router #router to callback
		- start
#socket.zig
	Socket
	+ socket_type
	+ socket #zig ptr
	+ uuid
	- init/deinit
	- connect
	- bind
	- send
	- send_more
	- recv
	- recv_noblock
#message.zig
	Message
		- init #init empty
		- init_slice #init from slice, makes copy
		- deinit
		- more #has more?
		- get_peer_ip4 #get source ipv4
		- get_buffer #get buffer from message data
#event.zig
	Event
		# interface to events
		- process()
		- deinit/free
	EventQueue
		+ queue
		+ thread
		- init
		- queue_event
		- event_processor
		- start_event_loop
		- join
	make_event(type, func) #event struct builder
#serializer.zig
	- serialize #return buffer
	- deserialize
	- serialize_tagged
	- deserialize_tagged
	Deserialize_tagged
		- init / deinit
		- tag #get tag
		- deserialize
#serialize_allocate.zig
	#used by serializer.zig
	#could go to core
#hash.zig
	+ Hash [32]u8
	- hash #create hash, calls blake_hash
	- blake_hash_allocate #variable size
	- blake_hash #heap
#proxy.zig
	- proxy #call proxy on frontend / backend
#queue.zig
	AtomicQueue(T)
		- push
		- pop
		- empty
		- size
		- size
#timer.zig
	Timer
		- init/deinit
		- add_timer
		- start
#thread_pool.zig
	+ thread_pool
	+ mutex
	- add_thread
	- join #join all thread, call at end
#pool.zig
	#todo
	-init
	-put
	
