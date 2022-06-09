extends HIRC_OBJ

class_name _HIRC_02_SOUND_SFX

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._02_SOUND_SFX
const hirc_name: String = "Sound FX"

var id: int
var plugin_id: int
var _inc_or_streamed: int
var inc_or_streamed: String setget ,_get_inc_or_streamed
var audio_id: int
var audio_size: HIRC_field
var _sound_type: int
var embedded_offset: int
var embedded_size: int
var sound_structure: SoundStructure


func _load(data: PoolByteArray):
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.set_data_array(data)
	self.id = buffer.get_u32()
	self.plugin_id = buffer.get_u32()
	self._inc_or_streamed = buffer.get_u8()
	self.audio_id = buffer.get_u32()
	self.audio_size = HIRC_field.new(buffer.get_u32())
	self._sound_type = buffer.get_u8()
	var ss = SoundStructure.new()
	self.sound_structure = ss.load(buffer)
	self._end_bytes = buffer.get_partial_data(buffer.get_available_bytes())[1]


func _get_inc_or_streamed() -> String:
	return Utils.back_enum(HIRC_ENUMS.HIRC_02_INC_OR_STREAMED, self._inc_or_streamed)


func _to_string() -> String:
	var out_str = "Sound FX (0x2)\n"
	out_str += "> SFX id: %s\n" % self.id
	out_str += "> audio id: %s\n" % self.audio_id
	out_str += "> audio location: %s" % self.inc_or_streamed
	return out_str


func _persist_changes():
	var buffer = StreamPeerBuffer.new()
	buffer.put_u32(self.id)
	buffer.put_u32(self.plugin_id)
	buffer.put_u8(self._inc_or_streamed)
	buffer.put_u32(self.audio_id)
	buffer.put_u32(self.audio_size.value)
	buffer.put_u8(self._sound_type)
	buffer.put_partial_data(self.sound_structure.serialize())
	buffer.put_partial_data(self._end_bytes)
	self._byte_pool = buffer.data_array
