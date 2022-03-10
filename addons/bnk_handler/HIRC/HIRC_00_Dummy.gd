extends HIRC_OBJ

class_name _HIRC_EVENT_DUMMY

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._00_DUMMY
const hirc_name: String = "Dummy"

var chunk_size: int


func _to_string() -> String:
    return "Dummy HIRC entry of type %s" % self.type
