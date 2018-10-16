Namespace koreTcp

#Import "packets.monkey2"

' A simple TCP listen server
Class Server
	
	Field GotPacketHook:Void( packet:Packet, client:Client )
	Field NewClientHook:Void( client:Client )
	Field DropClientHook:Void( client:Client, reason:String )
	
	Private
		Field _socket:Socket
		
		Field _acceptFiber:Fiber
		Field _acceptSleep:Float = 0.25
		
		Field _maxClients:UInt
		Field _clientCount:UInt
		Field _clients:Client[]
	Public
	
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
			
			' Check and pause here until new clients
			newSocket = _socket.Accept() ' Blocking
			
			If Not newSocket Then
				
				Print "Error 1 - Report to Hezkore!"
				Continue
			Endif
			
			' Find a new ID for our new client
			newID = EmptyClientID()
			
			If newID > 0 Then
				
				_clientCount += 1
				
				_clients[newID] = New Client(newID)
				_clients[newID]._server = Self
				_clients[newID]._socket = newSocket
				_clients[newID]._socket.SetOption( "TCP_NODELAY", 1 )
				_clients[newID]._stream = New SocketStream( newSocket )
				_clients[newID]._readFiber = New Fiber( _clients[newID].ReadLoop )
				
				'Hooks for new client
				_clients[newID]._packetConstructor.CompleteHook += Self.NewPacketProcessor
				
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
		
		GetClient( toID ).SendBuffer( data, size )
	End
	
	Method EmptyClientID:UInt()
		
		For Local i:UInt = 1 Until _clients.Length
			
			If Not _clients[i] Then Return i
		Next
		
		Return 0
	End
	
	' The server client connections
	Class Client Extends ClientBase
		
		Field _server:Server
		
		Property Server:Server()
			
			Return _server
		Setter( server:Server )
			
			_server = server
		End
		
		Method New( id:UInt )
			
			Self._id = id
			_packetConstructor = New PacketConstructor
		End
		
		Method SendPacket() Override
			
			'Always to self/own ID!
			_packet.SendToHook += _server.SendPacketTo
			_packet.SendTo( ID )
		End
		
		Method Close( reason:String = "" ) Override
			
			Super.Close( reason )
			
			_server.DropClientHook( Self, reason )
			_server._clientCount -= 1
			
			If _customProperties Then _customProperties.Clear()
			
			_customProperties = Null
			
			_server._clients[ID] = Null
		End
	End
End

' A simple TCP client
Class Client Extends ClientBase
	
	Field GotPacketHook:Void( packet:Packet )
	Field _connecting:Int
	
	Property Connecting:Bool()
		
		Return _connecting
	End
	
	Method New()
		
		_packetConstructor = New PacketConstructor
		_packetConstructor.CompleteHook = NewPacketProcessor
	End
	
	Method New( host:String, port:UInt )
		
		Self.New()
		
		Self.Connect( host, port )
	End
	
	Method Connect:Bool( host:String, port:UInt )
		
		_connecting = True
		
		_socket = Socket.Connect( host, port )
		
		If Not _socket Then
			
			_connecting = False
			Return False
		Endif
		
		_socket.SetOption( "TCP_NODELAY",1 )
		
		_stream = New SocketStream( _socket )
		
		_readFiber = New Fiber( ReadLoop )
		
		_connecting = False
		
		Return True
	End
	
	Method NewPacketProcessor( packet:Packet, fromID:UInt )
		
		GotPacketHook( packet )
	End
	
	Method SendPacket() Override
		
		_packet.SendHook += SendBuffer
		_packet.Send()
	End
End

' Client base
Class ClientBase
	
	Private
	
		Field _id:UInt
		
		Field _socket:Socket
		Field _stream:Stream
		
		Field _readFiber:Fiber
		
		Field _packetConstructor:PacketConstructor
		Field _packet:Packet
		
		Field _customProperties:Map<String,Variant>
	Public
	
	Property ID:UInt()
		
		Return _id
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
	
	Property Packet:Packet()
		
		Return _packet
	End
	
	Method SendPacket() Virtual
	End
	
	Method Close( reason:String = "" ) Virtual
		
		If _readFiber Then _readFiber.Terminate()
		
		_readFiber = Null
		
		If _stream Then _stream.Close()
		If _socket Then _socket.Close()
		
		_stream = Null
		_socket = Null
	End
	
	Method SetProperty( key:Int, value:Variant )
		
		SetProperty( String( key ), value )
	End
	
	Method SetProperty( key:String, value:Variant )
		
		If Not _customProperties Then
			
			_customProperties = New Map<String, Variant>
		Endif
		
		_customProperties.Set( key, value )
	End
	
	Method GetProperty:Variant( key:Int )
		
		Return GetProperty( String( key ) )
	End
	
	Method GetProperty:Variant( key:String )
		
		If Not _customProperties Then
			
			_customProperties = New Map<String, Variant>
		Endif
		
		Return _customProperties.Get( key )
	End
	
	Method NewPacket:Packet( packetID:UByte )
		
		_packet = New Packet( packetID )
		Return _packet
	End
	
	Method ReadLoop()
		
		Local data:DataBuffer
		Local readCount:Int
		
		Repeat
			
			data = New DataBuffer( _packetConstructor.ExpectedSize )
			readCount = _stream.Read( data, 0, _packetConstructor.ExpectedSize )
			
			If readCount > 0 Then
				
				_packetConstructor.Construct( data, _packetConstructor.ExpectedSize, ID )
			Else
				
				Close()
			Endif
		Until Not Connected
	End
	
	Method SendBuffer( data:DataBuffer, size:UInt )
		
		If Not Connected Then Return
		_stream.Write( data, 0, size )
	End
End