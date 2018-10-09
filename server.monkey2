Namespace koreTcp

#Import "<std>"
#Import "<mojo>"
Using std..
Using mojo.app

#Import "inc/network.monkey2"

'Our own custom packet IDs
#Import "packetID.monkey2"

Global server:Server

Function Main()
	
	New AppInstance
	
	'Create a server
	server = New Server
	
	If server.Listen( 4012 ) Then
		
		Print "Server @" + server.Address + " listening"
	Else
		
		Print "Unable to start listening server"
	Endif
	
	'Add hooks
	server.GotPacketHook = GotPacket
	server.NewClientHook = NewClient
	server.DropClientHook = DropClient
	
	App.Run()
End

Function GotPacket( packet:Packet, client:Server.Client )
	
	Select packet.ID
		Case PacketID.Key
			Local keyPressed:UShort = packet.ReadUShort()
			
			'Send the key back to the client
			client.NewPacket( PacketID.Key )
			client.Packet.WriteUShort( keyPressed )
			client.SendPacket()
			
			Print "Client #" + client.ID + " hit key " + keyPressed
		
		Default
			Print "Unknown packet: " + packet.ID
	End
End

Function NewClient( client:Server.Client )
	
	Print "Server accepted client @" + client.PeerAddress + " as #" + client.ID
	'Print "Clients connected: "+client.Server.ClientCount
End

Function DropClient( client:Server.Client, reason:String )
	
	If reason Then
		
		Print "Client left #" + client.ID + " : " + reason
	Else
		
		Print "Client left #" + client.ID
	Endif
End