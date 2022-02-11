extends HIRC_OBJ

class_name _HIRC_EVENT_DUMMY

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._00_DUMMY
const hirc_name: String = "Dummy"

var type: int
var chunk_size: int
var data: PoolByteArray = []

func load_dummy(type: int, chunk_size: int, data: PoolByteArray):
    self.type = type
    self.chunk_size = chunk_size
    self.data = data

func _to_string() -> String:
    return "Dummy HIRC entry of type %s" % self.type