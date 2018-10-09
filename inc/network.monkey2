Namespace koreTcp

#Import "packets.monkey2"

' A simple TCP listen server
Class Server
	
	Field _socket:Socket
	
	Field _acceptFiber:Fiber
	Field _acceptSleep:Float = 0.25
	
	Field _maxClients:UInt
	Field _clientCount:UInt
	Field _clients:Client[]
	
	Field GotPacketHook:Void( packet:Packet, client:Client )
	Field NewClientHook:Void( client:Client )
	Field DropClientHook:Void( client:Client, reason:String )
	
	Property AcceptSleep:Float()
		
		Return _acceptSleep
	Setter( sleep:Float )
		
		_acceptSleep=sleep
	End
	
	Property ClientCount:UInt()
		
		Return _clientCount
	End
	
	Property Address:String()
		
		Return _socket.Address
	End
	
	Property PeerAddress:String()
		
		Return _socket.PeerAddress
	End
	
	Method GetClient:Client( ID:UInt )
		
		Return _clients[ID]
	End
	
	Method New()
	End
	
	Method New( port:Int, maxClients:Int = 32 )
		Self.Listen( port, maxClients )
	End
	
	Method Listen:Bool( port:Int, maxClients:Int = 32 )
		
		_socket = Socket.Listen( port )
		If Not _socket Return False
		
		_socket.SetOption( "SO_REUSEADDR", 1 )
		_socket.SetOption( "TCP_NODELAY", 1 )
		
		_maxClients = maxClients
		_clients = New Client[_maxClients+1]
		
		_acceptFiber = New Fiber( AcceptLoop )
		
		Return True
	End
	
	Method AcceptLoop()
		
		Local newSocket:Socket
		Local newID:UInt
		
		While Not _socket.Closed
			'If _clientCount>=_maxClients Then Return
			
			' Check and pause here until new clients
			newSocket = _socket.Accept() ' Blocking
			
			If Not newSocket Then
				
				Print "Error 1 - Report to Hezkore!"
				Continue
			Endif
			
			' Find a new empty client ID for our client
			newID = EmptyClientID()
			
			If newID Then
				
				_clientCount += 1
				
				_clients[newID] = New Client(newID)
				_clients[newID]._server = Self
				_clients[newID]._socket = newSocket
				_clients[newID]._socket.SetOption( "TCP_NODELAY", 1 )
				_clients[newID]._stream = New SocketStream( newSocket )
				_clients[newID]._readFiber = New Fiber( _clients[newID].ReadLoop )
				
				'Hooks for new client
				_clients[newID]._packetConst.CompleteHook += Self.NewPacketProcessor
				
				NewClientHook( _clients[newID] )
				
			Else
				
				newSocket.Close()
			Endif
			
			'Sleep between new clients to prevent spam
			Fiber.Sleep( _acceptSleep )
		Wend
	End
	
	Method NewPacketProcessor( packet:Packet, fromID:UInt )
		GotPacketHook( packet, GetClient( fromID ) )
	End
	
	Method SendPacketTo( data:DataBuffer, size:UInt, toID:UInt )
		GetClient(toID).SendBuffer( data, size )
	End
	
	Method EmptyClientID:UInt()
		
		For Local i:UInt=1 Until _clients.Length
			
			If Not _clients[i] Then Return i
		Next
		
		Return 0
	End
	
	Method DropClient( id:UInt, reason:String="" )
		
		If Not _clients[id] Then Return
		
		GetClient( id ).Close( reason )
	End
	
	' The server client connections
	Class Client Extends ClientBase
		
		Field _id:UInt
		Field _socket:Socket
		Field _stream:SocketStream
		Field _packetConst:PacketConst
		Field _server:Server
		Field _packet:Packet
		Field _readFiber:Fiber
		
		Property Server:Server()
			
			Return _server
		Setter( server:Server )
			
			_server=server
		End
		
		Property Address:String()
			
			Return _socket.Address
		End
		
		Property PeerAddress:String()
			
			Return _socket.PeerAddress
		End
		
		Property ID:UInt()
			
			Return _id
		End
		
		Property Connected:Bool()
			
			If Not _socket Or Not _stream Then Return False
			If _socket.Closed Then Return False
			If _stream.Eof Then Return False
			
			Return True
		End
		
		Property Packet:Packet()
			
			Return _packet
		End
		
		Method New( id:UInt )
			
			Self._id = id
			_packetConst = New PacketConst
		End
		
		Method NewPacket:Packet( packetID:UByte )
			
			_packet = New Packet( packetID )
			Return _packet
		End
		
		Method ReadLoop()
			
			Local data:DataBuffer
			Local readCount:Int
			
			Repeat
				
				data = New DataBuffer( _packetConst.ExpectedSize )
				readCount = _stream.Read( data, 0, _packetConst.ExpectedSize )
				
				If readCount>0 Then
					
					_packetConst.Construct( data, _packetConst.ExpectedSize, ID )
				Else
					
					Close()
				Endif
				
			Until Not Connected
		End
		
		Method SendPacket()
			
			'Always to self/own ID!
			_packet.SendToHook += _server.SendPacketTo
			_packet.SendTo( ID )
		End
		
		Method SendBuffer( data:DataBuffer, size:UInt )
			
			Self._stream.Write( data, 0, size )
		End
		
		Method Close( reason:String = "" )
			
			_server.DropClientHook( Self, reason )
			_server._clientCount-=1
			
			If Connected Then
				
				If _socket Then _socket.Close()
				If _stream Then _stream.Close()
			Endif
			
			_socket = Null
			_stream = Null
			
			_server._clients[ID]=Null
		End
	End
End

' A simple TCP client
Class Client Extends ClientBase
	
	Field _socket:Socket
	Field _stream:Stream
	
	Field _packetConst:PacketConst
	Field _packet:Packet
	
	Field _readFiber:Fiber
	
	Field GotPacketHook:Void( packet:Packet )
	
	Property Packet:Packet()
		
		Return _packet
	End
	
	Property Connected:Bool()
		
		If Not _socket Or Not _stream Then Return False
		If _socket.Closed Then Return False
		If _stream.Eof Then Return False
		
		Return True
	End
	
	Property Address:String()
		
		Return _socket.Address
	End
	
	Property PeerAddress:String()
		
		Return _socket.PeerAddress
	End
	
	Method New()
		
		_packetConst = New PacketConst
		_packetConst.CompleteHook = NewPacketProcessor
	End
	
	Method New( host:String, port:UInt )
		
		Self.New()
		
		Self.Connect( host, port )
	End
	
	Method Connect:Bool( host:String, port:UInt )
		
		_socket = Socket.Connect( host, port )
		
		If Not _socket Return False
		
		_socket.SetOption( "TCP_NODELAY",1 )
		
		_stream = New SocketStream( _socket )
		
		_readFiber = New Fiber( ReadLoop )
		
		Return True
	End
	
	Method NewPacketProcessor( packet:Packet, fromID:UInt )
		
		GotPacketHook( packet )
	End
	
	Method ReadLoop()
		
		Local data:DataBuffer
		Local readCount:Int
		
		Repeat
			
			data = New DataBuffer( _packetConst.ExpectedSize )
			readCount = _stream.Read( data, 0, _packetConst.ExpectedSize )
			
			If readCount > 0 Then
				
				_packetConst.Construct( data, _packetConst.ExpectedSize, 0 )
			Else
				
				Close()
			Endif
		Until Not Connected
	End
	
	Method NewPacket:Packet( packetID:UByte )
		
		_packet = New Packet( packetID )
		Return _packet
	End
	
	Method SendPacket()
		
		_packet.SendHook += SendBuffer
		_packet.Send()
	End
	
	Method SendBuffer( data:DataBuffer, size:UInt )
		
		If Not Connected Then Return
		_stream.Write( data, 0, size )
	End
	
	Method Close()
		
		If _stream Then _stream.Close()
		If _socket Then _socket.Close()
		
		_stream = Null
		_socket = Null
	End
End

' Client base
Class ClientBase
	
	
End