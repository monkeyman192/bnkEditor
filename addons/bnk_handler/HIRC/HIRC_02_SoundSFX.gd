extends HIRC_OBJ

class_name _HIRC_02_SOUND_SFX

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._02_SOUND_SFX
const hirc_name: String = "Sound FX"

var id: int
var _inc_or_streamed: int
var inc_or_streamed: String setget ,_get_inc_or_streamed
var audio_id: int
var source_id: int
var embedded_offset: int
var embedded_size: int
var sound_type: int
var sound_structure		# TODO: have a `SoundStructure` class to put here...


func _load(buffer: StreamPeerBuffer):
    self.id = buffer.get_u32()
    buffer.seek(buffer.get_position() + 4)
    self._inc_or_streamed = buffer.get_u8()
    self.audio_id = buffer.get_u32()
    self.source_id = buffer.get_u32()
    if self._inc_or_streamed == HIRC_ENUMS.HIRC_02_INC_OR_STREAMED.EMBEDDED:
        self.embedded_offset = buffer.get_u32()
        self.embedded_size = buffer.get_u32()
    self.sound_type = buffer.get_u8()
    # TODO: Add sound structure data


func _get_inc_or_streamed() -> String:
    return Utils.back_enum(HIRC_ENUMS.HIRC_02_INC_OR_STREAMED, self._inc_or_streamed)


func _to_string() -> String:
    var out_str = "Sound FX (0x2)\n"
    out_str += "> SFX id: %s\n" % self.id
    out_str += "> audio id: %s\n" % self.audio_id
    out_str += "> audio location: %s" % self.inc_or_streamed
    return out_str