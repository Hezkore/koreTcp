Namespace koreTcp

#Import "<libc>"
Using libc..

' Packet constructor
' Feed stream data into this
Class PacketConstructor
	
	Field CompleteHook:Void( packet:Packet, fromID:UInt )
	
	Private
		
		Field _step:UInt
		Field _packet:Packet
		Field _expectedSize:UInt
	Public
	
	Property ExpectedSize:UInt()
		
		If _step = 0 Then Return Packet._sizeOffset
		If _step = 1 Then Return Packet._dataOffset - Packet._sizeOffset
		
		Return _expectedSize - Packet._dataOffset
	End
	
	Method Reset()
		
		_expectedSize = 0
		_step = 0
		_packet = Null
	End
	
	Method Construct( buffer:DataBuffer, size:UInt, fromID:UInt )
		
		If Not buffer Or size <= 0 Then Return
		
		For Local i:UInt = 0 Until size
			
			Select _step
				Case 0 'Create a new packet and skip tmp size
					Reset()
					
					_packet = New Packet( buffer.PeekUByte( i ), False )
					_step += 1
					
				Default 'Write data to packet
					_packet.WriteUByte( buffer.PeekUByte( i ) )
			End
			
			If _packet._offset >= Packet._dataOffset And Not _expectedSize Then
				
				_expectedSize = _packet._buffer.PeekUShort( Packet._sizeOffset )
				_step += 1
			Endif
			
			If _expectedSize And _packet._offset >= _expectedSize Then
				
				_packet._size = _expectedSize
				
				'Reset offset and return packet!
				_packet._offset = Packet._dataOffset
				CompleteHook( _packet, fromID )
				
				Reset()
			Endif
			
		Next
		
	End
End

'Complete packet
'Either a received packet or packet about to be send
Class Packet
	
	Field SendHook:Void( data:DataBuffer, size:UInt )
	Field SendToHook:Void( data:DataBuffer, size:UInt, toID:UInt )
	
	Private
	
		Global DefaultSize:Int = 512'Default size for every buffer
		Global _sizeOffset:UInt = 1	' Where in the buffer is size stored?
		Global _dataOffset:UInt = 3	' Where does the packet data start?
		
		Field _id:UByte
		Field _buffer:DataBuffer
		Field _offset:UInt		' Next write position (in bytes)
		Field _lastOffset:UInt	' Previous write size (in bytes)
		Field _size:UInt		' Manually set size
		
		Method AddOffset( s:UByte )
			
			_lastOffset = _offset
			_offset += s
			
			'Print "Wrote "+(_offset-_lastOffset)+" at "+_lastOffset
		End
	Public
	
	Property ID:UByte()
		
		Return _id
	End
	
	Property Eof:Bool()
		
		If _offset >= _size Then Return True
		
		Return False
	End
	
	Method New( id:UByte, useTmpSize:Bool = True )
		
		_id = id
		_buffer = New DataBuffer( DefaultSize )
		
		_buffer.PokeUByte( 0, id ) 'Write id
		
		If useTmpSize Then
			'Write temp size
			_buffer.PokeUShort( _sizeOffset, _buffer.Length )
			
			'Prepare for buffer offset for data!
			_offset = _dataOffset
		Else
			'Prepare for buffer size
			_offset = _sizeOffset
		Endif
		
	End
	
	Method Send()
		
		'Update size value
		_buffer.PokeUShort( _sizeOffset, _offset )
		
		SendHook( _buffer, _offset )
	End
	
	Method SendTo( toID:UInt )
		
		Send()
		SendToHook( _buffer, _offset, toID )
	End
	
	' Writing
	
	Method WriteUByte( v:UByte )
		
		_buffer.PokeUByte( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteByte( v:Byte )
		
		_buffer.PokeByte( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteUShort( v:UShort )
		
		_buffer.PokeUShort( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteShort( v:Short )
		
		_buffer.PokeShort( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteUInt( v:UInt )
		
		_buffer.PokeUInt( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteInt( v:Int )
		
		_buffer.PokeInt( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteULong( v:ULong )
		
		_buffer.PokeULong( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteLong( v:Long )
		
		_buffer.PokeLong( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteFloat( v:Float )
		
		_buffer.PokeFloat( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteDouble( v:Double )
		
		_buffer.PokeDouble( _offset, v )
		AddOffset( sizeof( v ) )
	End
	
	Method WriteString( str:String )
		
		' Write length of the string
		WriteUShort( str.Length )
		
		_buffer.PokeString( _offset, str )
		AddOffset( str.Length )
	End
	
	' Reading
	
	Method ReadUByte:UByte()
		
		AddOffset( sizeof( UByte( 0 ) ) )
		Return _buffer.PeekUByte( _lastOffset )
	End
	
	Method ReadByte:Byte()
		
		AddOffset( sizeof( Byte( 0 ) ) )
		Return _buffer.PeekByte( _lastOffset )
	End
	
	Method ReadUShort:UShort()
		
		AddOffset( sizeof( UShort( 0 ) ) )
		Return _buffer.PeekUShort( _lastOffset )
	End
	
	Method ReadShort:Short()
		
		AddOffset( sizeof( Short( 0 ) ) )
		Return _buffer.PeekShort( _lastOffset )
	End
	
	Method ReadUInt:UInt()
		
		AddOffset( sizeof( UInt( 0 ) ) )
		Return _buffer.PeekUInt( _lastOffset )
	End
	
	Method ReadInt:Int()
		
		AddOffset( sizeof( Int( 0 ) ) )
		Return _buffer.PeekInt( _lastOffset )
	End
	
	Method ReadULong:ULong()
		
		AddOffset( sizeof( ULong( 0 ) ) )
		Return _buffer.PeekULong( _lastOffset )
	End
	
	Method ReadLong:Long()
		
		AddOffset( sizeof( Long( 0 ) ) )
		Return _buffer.PeekLong( _lastOffset )
	End
	
	Method ReadFloat:Float()
		
		AddOffset( sizeof( Float( 0 ) ) )
		Return _buffer.PeekFloat( _lastOffset )
	End
	
	Method ReadDouble:Double()
		
		AddOffset( sizeof( Double( 0 ) ) )
		Return _buffer.PeekDouble( _lastOffset )
	End
	
	Method ReadString:String()
		
		' Read the length of the string
		Local strLength := ReadUShort()
		
		AddOffset( strLength )
		Return _buffer.PeekString( _lastOffset, strLength )
	End
End