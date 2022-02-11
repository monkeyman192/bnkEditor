extends HIRC_OBJ

class_name _HIRC_11_MOTION_FX

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._11_MOTION_FX
const hirc_name: String = "Motion FX"

# Event. This will be a single id with a sub-list of ids for other event actions.
var id: int
var event_count: int = 0
var events: Array = []


func _load(buffer: StreamPeerBuffer):
    self.id = buffer.get_u32()
