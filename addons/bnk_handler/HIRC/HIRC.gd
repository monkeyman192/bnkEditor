extends Reference

# Create an abstract base class
class_name HIRC_OBJ

const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

# Store the underlying bytes associated with this HIRC object
var _byte_pool: PoolByteArray
var hirc_type: int
var change_count: int = 0
var size: int = 0 setget ,_get_size
var _end_bytes: PoolByteArray

func load(type: int, data: PoolByteArray):
	# Initial entry point for loading the HIRC chunk.
	# Associate the read type, then also set the byte pool so that we can mutate it later if
	# required.
	self.hirc_type = type
	# We'll pass the data in as a PoolByteArray directly for performance reasons.
	# If we convert it before-hand, it will be needlessly converted for any chunk which is unknown,
	# which may be many in big bnk files.
	# All conversion of PoolByteArray's to StreamPeerbuffer's has to be done in the subclasses
	# _load method (sadly godot doesn't have decorators like python :'( )
	self._load(data)
	# Assign the data to the internal buffer so that if we need to export it unchanged it's easy.
	self._byte_pool = data


func _load(data: PoolByteArray):
	# Abstract method to be overwritten by the inheriting classes.
	pass


func _get_size():
	# Total size is the hirc_type (u8) + chunk_size (u32) + payload (self._byte_pool size)
	return 5 + self._byte_pool.size()


func byte_pool() -> PoolByteArray:
	# Construct an Poolbyte Array which consists of the hirc_type, chunk_size and chunk data.
	var out_array: PoolByteArray = []
	# Add the hirc_type
	out_array.append(self.hirc_type)
	# Add the hirc chunk size.
	# We'll just write this manually since it's probably faster than instantiating a StreamPeer
	# just to convert the int to a u32.
	var _size = self._byte_pool.size()
	var bytes_size = [_size & 0xFF, _size & 0xFF00, _size & 0xFF0000, _size & 0xFF000000]
	out_array.append_array(bytes_size)
	out_array.append_array(self._byte_pool)
	return out_array


func persist_changes():
	# Persist and changes to the underlying PoolByteArray
	# We only need to try and update the byte pool if there are actually changes. If there aren't,
	# then simply return
	if self.change_count == 0:
		return
	# If we have actual changes, then we need to do something
	self._persist_changes()


func _persist_changes():
	# Abstract method to be overwritten by inheriting classes.
	# The overwriting methods should have the following structure:
	# var buffer = StreamPeerBuffer.new()
	# buffer.set_data_array(self._byte_pool)
	# Do a bunch of stuff to the buffer
	# self._byte_pool = buffer.data_array
	pass