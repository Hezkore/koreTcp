Namespace koreTcp

' Packet constructor
' Feed stream data into this
Class PacketConstructor
	
	Field CompleteHook:Void( packet:Packet, fromID:UInt )
	
	Field _step:UInt
	Field _packet:Packet
	Field _expectedSize:UInt
	
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
	
	Global DefaultSize:Int = 512'Default size for every buffer
	Global _sizeOffset:UInt = 1	'Where in the buffer is size stored?
	Global _dataOffset:UInt = 3	'Where does the packet data start?
	
	Field SendHook:Void( data:DataBuffer, size:UInt )
	Field SendToHook:Void( data:DataBuffer, size:UInt, toID:UInt )
	
	Field _id:UByte
	Field _buffer:DataBuffer
	Field _offset:UInt	'Next write position (in bytes)
	Field _lastOffset:UInt	'Previous write size (in bytes)
	
	Property ID:UByte()
		
		Return _id
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
	
	Method WriteUByte( v:UByte )
		
		_buffer.PokeUByte( _offset, v )
		AddOffset( 1 )
	End
	
	Method WriteUShort( v:UShort )
		
		_buffer.PokeUShort( _offset, v )
		AddOffset( 2 )
	End
	
	Method ReadUByte:UByte()
		
		AddOffset( 1 )
		Return _buffer.PeekUByte( _lastOffset )
	End
	
	Method ReadUShort:UShort()
		
		AddOffset( 2 )
		Return _buffer.PeekUShort( _lastOffset )
	End
	
	Method Send()
		'Update size
		_buffer.PokeUShort( _sizeOffset, _offset )
		
		SendHook( _buffer, _offset )
	End
	
	Method SendTo( toID:UInt )
		
		Send()
		SendToHook( _buffer, _offset, toID )
	End
	
	Method AddOffset( s:UByte )
		
		_lastOffset = _offset
		_offset += s
		
		'Print "Wrote "+(_offset-_lastOffset)+" at "+_lastOffset
	End
End