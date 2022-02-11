extends Node

# Create an abstract base class
class_name HIRC_OBJ

const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

# Store the underlying bytes associated with this HIRC object
var _byte_pool: PoolByteArray
var size: int = 0 setget ,_get_size

func load(data: PoolByteArray):
    var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
    buffer.set_data_array(data)
    self._load(buffer)
    # Assign the data to the internal buffer so that if we need to export it unchanged it's easy.
    self._byte_pool = data


func _load(data: StreamPeerBuffer):
    # This method is to be overwritten by the inheriting classes.
    pass


func _get_size():
    return self._byte_pool.size()
