extends Node

class_name Packet

var _offset: int
var _size: int
var _absolute_granule: int
var _no_granule: bool


func create(stream: BitWiseStreamPeerBuffer, offset: int, no_granule: bool = false):
	self._offset = offset
	self._size = -1
	self._absolute_granule = 0
	self._no_granule = no_granule

	stream.cseek(self._offset)
	self._size = stream.get_u16()

	if !self._no_granule:
		self._absolute_granule = stream.get_u32()


func get_header_size() -> int:
	# The size of the header. This will depend on whether there are granules or not.
	if self._no_granule:
		return 2
	else:
		return 6


func get_offset() -> int:
	return self.get_header_size() + self._offset


func get_granule() -> int:
	return self._absolute_granule


func get_size() -> int:
	return self._size


func next_offset() -> int:
	return self._offset + self.get_header_size() + self._size
