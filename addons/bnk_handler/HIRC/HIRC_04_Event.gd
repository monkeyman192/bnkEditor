extends HIRC_OBJ

class_name _HIRC_04_EVENT

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._04_EVENT
const hirc_name: String = "Event"

# Event. This will be a single id with a sub-list of ids for other event actions.
var id: int
var event_count: int = 0
var events: Array = []


func _load(data: PoolByteArray):
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.set_data_array(data)
	self.id = buffer.get_u32()
	self.event_count = buffer.get_u8()
	for i in range(self.event_count):
		self.events.append(buffer.get_u32())


func _to_string() -> String:
	var out_str = "Event (0x4)\n"
	out_str += "> Event id: %s\n" % self.id
	out_str += "> Events (%s): \n" % self.event_count
	for event in self.events:
		out_str += ">> %s\n" % event
	return out_str
