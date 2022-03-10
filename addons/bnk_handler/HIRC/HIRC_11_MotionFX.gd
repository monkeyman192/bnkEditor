extends HIRC_OBJ

class_name _HIRC_11_MOTION_FX

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._11_MOTION_FX
const hirc_name: String = "Motion FX"

var id: int


func _load(data: PoolByteArray):
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.set_data_array(data)
	self.id = buffer.get_u32()
