extends HIRC_OBJ

class_name _HIRC_03_EVENT_ACTION

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._03_EVENT_ACTION
const hirc_name: String = "Event Action"

# Entry with identifier of 0x03
var id: int
var _scope: int
var scope: String setget ,_get_scope
var _action_type: int
var action_type: String setget ,_get_action_type
var reference_id: int
var additional_parameter_count: int
var additional_parameters: Array
var state_group_id: int
var state_id: int
var switch_group_id: int
var switch_id: int


func _load(buffer: StreamPeerBuffer):
	self.id = buffer.get_u32()
	self._scope = buffer.get_u8()
	self._action_type = buffer.get_u8()
	self.reference_id = buffer.get_u32()
	buffer.seek(buffer.get_position() + 1)		# skip a byte which is always 0
	self.additional_parameter_count = buffer.get_u8()
	for i in range(self.additional_parameter_count):
		# Add the parameter type. Depending on the type, we'll need to load a different data
		# type next time we loop over the range.
		self.additional_parameters.append([buffer.get_u8()])
	for i in range(self.additional_parameter_count):
		if self.additional_parameters[i][0] == HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.DELAY:
			self.additional_parameters[i].append(buffer.get_u32())		# time in ms
		elif self.additional_parameters[i][0] == HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.FADE_IN_TIME:
			self.additional_parameters[i].append(buffer.get_u32())		# time in ms
		elif self.additional_parameters[i][0] == HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.PROBABILITY:
			self.additional_parameters[i].append(buffer.get_float())
	buffer.seek(buffer.get_position() + 1)		# skip a byte which is always 0
	if self._action_type == HIRC_ENUMS.HIRC_03_ACTION_TYPE.SET_STATE:
		self.state_group_id = buffer.get_u32()
		self.state_id = buffer.get_u32()
	elif self._action_type == HIRC_ENUMS.HIRC_03_ACTION_TYPE.SET_SWITCH:
		self.switch_group_id = buffer.get_u32()
		self.switch_id = buffer.get_u32()


func _get_scope() -> String:
	return Utils.back_enum(HIRC_ENUMS.HIRC_03_EVENT_ACTION_SCOPE, self._scope)


func _get_action_type() -> String:
	return Utils.back_enum(HIRC_ENUMS.HIRC_03_ACTION_TYPE, self._action_type)


func _to_string() -> String:
	var out_str = "Event Action (0x3)\n"
	out_str += "> Event id: %s\n" % self.id
	out_str += "> Action type: %s\n" % self.action_type
	out_str += "> additional parameters (%s):\n" % self.additional_parameter_count
	for i in range(self.additional_parameter_count):
		out_str += ">> %s: %d" % [
			Utils.back_enum(HIRC_ENUMS.HIRC_03_PARAMETER_TYPE, self.additional_parameters[i][0]),
			self.additional_parameters[i][1]
		]
	return out_str
