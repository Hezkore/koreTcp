Namespace koreTcp

#Import "<std>"
#Import "<mojo>"
Using std..
Using mojo..

#Import "inc/network.monkey2"

'Our own custom packet IDs
#Import "packetID.monkey2"

Function Main()
	New AppInstance
	New MyWindow( "koreTcp client", 640, 480, Null )
	App.Run()
End

Class MyWindow Extends Window
	
	Field client:Client
	
	Method New( title:String,width:Int,height:Int,flags:WindowFlags )
		Super.New( title, width, height, flags )
		
		'Make a new client
		client=New Client
		
		'Add hooks
		client.GotPacketHook=GotPacket
		
		'Connect to a server
		Print "Connecting to server..."
		If client.Connect( "127.0.0.1", 4012 ) Then
			Print "Client @"+client.Address+" connected to server @"+client.PeerAddress
		Else
			Print "Unable to connect to server!"
			Print "Make sure the server is running"
		Endif
		
		'SwapInterval=False
	End
	
	Method OnWindowEvent( event:WindowEvent ) Override
		
		If event.Type=EventType.WindowClose Then
			client.Close()
			App.Terminate()
		Endif
	End
	
	Method OnRender( canvas:Canvas ) Override
		App.RequestRender()
		
		If client.Connected Then
			canvas.DrawText( "Connected to: "+client.PeerAddress, 0, 0 )
			canvas.DrawText( "Press the arrow keys and look at the console", 0, 13 )
		Else
			canvas.DrawText( "Not connected to a server", 0, 0 )
		Endif
		
		If Keyboard.KeyHit( Key.Up ) Then
			Print Millisecs()+" Keyhit 1"
			client.NewPacket( PacketID.Key )
			client.Packet.WriteUShort( 1 )
			client.SendPacket()
		Endif
		
		If Keyboard.KeyHit( Key.Right ) Then
			Print Millisecs()+" Keyhit 2"
			client.NewPacket( PacketID.Key )
			client.Packet.WriteUShort( 2 )
			client.SendPacket()
		Endif
		
		If Keyboard.KeyHit( Key.Down ) Then
			Print Millisecs()+" Keyhit 3"
			client.NewPacket( PacketID.Key )
			client.Packet.WriteUShort( 3 )
			client.SendPacket()
		Endif
		
		If Keyboard.KeyHit( Key.Left ) Then
			Print Millisecs()+" Keyhit 4"
			client.NewPacket( PacketID.Key )
			client.Packet.WriteUShort( 4 )
			client.SendPacket()
		Endif
		
		'This doesn't work!
		If Keyboard.KeyHit( Key.Escape ) Then
			client.Close()
			App.Terminate()
		Endif
		
	End
End

Function GotPacket( packet:Packet )
	
	Select packet.ID
		Case PacketID.Key
			Print Millisecs()+"Server says we hit key "+packet.ReadUShort()
		
		Default
			Print "Unknown packet: "+packet.ID
	End
End