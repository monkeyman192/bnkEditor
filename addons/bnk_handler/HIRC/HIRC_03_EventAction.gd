extends HIRC_OBJ

class_name _HIRC_03_EVENT_ACTION

const hirc_id: int = HIRC_ENUMS.HIRC_OBJ_TYPES._03_EVENT_ACTION
const hirc_name: String = "Event Action"

const INT_PARAM_TYPES = [
	HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.DELAY_TIME,
	HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.FADE_IN_TIME,
]
const FLOAT_PARAM_TYPES = [
	HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.PROBABILITY,
]

# Entry with identifier of 0x03
var id: int
var _scope: int
var scope: String setget ,_get_scope
var _action_type: Dictionary
var action_type: int setget ,_get_action_type
var reference_id: int
var additional_parameter_count: int
var additional_parameters: Array
var state_group_id: int
var state_id: int
var switch_group_id: int
var switch_id: int
var easing_curve: int


const EVENT_ACTIONS = [
	HIRC_ENUMS.HIRC_03_ACTION_TYPE.PLAY,
	HIRC_ENUMS.HIRC_03_ACTION_TYPE.STOP,
	HIRC_ENUMS.HIRC_03_ACTION_TYPE.RESUME,
]


func _load(data: PoolByteArray):
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.set_data_array(data)
	self.id = buffer.get_u32()
	self._scope = buffer.get_u8()
	self._action_type = {"value": buffer.get_u8()}
	self.reference_id = buffer.get_u32()
	buffer.seek(buffer.get_position() + 1)		# skip a byte which is always 0
	self.additional_parameter_count = buffer.get_u8()
	for i in range(self.additional_parameter_count):
		# Add the parameter type. Depending on the type, we'll need to load a different data
		# type next time we loop over the range.
		self.additional_parameters.append([buffer.get_u8()])
	for i in range(self.additional_parameter_count):
		if self.additional_parameters[i][0] in INT_PARAM_TYPES:
			self.additional_parameters[i].append(buffer.get_u32())
		elif self.additional_parameters[i][0] in FLOAT_PARAM_TYPES:
			self.additional_parameters[i].append(buffer.get_float())
	buffer.seek(buffer.get_position() + 1)		# skip a byte which is always 0
	if self.action_type == HIRC_ENUMS.HIRC_03_ACTION_TYPE.SET_STATE:
		self.state_group_id = buffer.get_u32()
		self.state_id = buffer.get_u32()
	elif self.action_type == HIRC_ENUMS.HIRC_03_ACTION_TYPE.SET_SWITCH:
		self.switch_group_id = buffer.get_u32()
		self.switch_id = buffer.get_u32()
	if self.action_type in EVENT_ACTIONS:
		# Get the easing curve.
		self.easing_curve = buffer.get_u8()
	self._end_bytes = buffer.get_partial_data(buffer.get_available_bytes())[1]


func _get_scope() -> String:
	return Utils.back_enum(HIRC_ENUMS.HIRC_03_EVENT_ACTION_SCOPE, self._scope)


func _get_action_type() -> int:
	return self._action_type["value"]
	# return Utils.back_enum(HIRC_ENUMS.HIRC_03_ACTION_TYPE, self._action_type)


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


func _persist_changes():
	var buffer = StreamPeerBuffer.new()
	buffer.put_u32(self.id)
	buffer.put_u8(self._scope)
	buffer.put_u8(self.action_type)
	buffer.put_u32(self.reference_id)
	buffer.put_u8(0)
	buffer.put_u8(self.additional_parameter_count)
	for param in self.additional_parameters:
		buffer.put_u8(param[0])
	for param in self.additional_parameters:
		if param[0] in INT_PARAM_TYPES:
			buffer.put_u32(param[1])
		elif param[0] in FLOAT_PARAM_TYPES:
			buffer.put_float(param[1])
	buffer.put_u8(0)
	if self.action_type == HIRC_ENUMS.HIRC_03_ACTION_TYPE.SET_STATE:
		buffer.put_u32(self.state_group_id)
		buffer.put_u32(self.state_id)
	elif self.action_type == HIRC_ENUMS.HIRC_03_ACTION_TYPE.SET_SWITCH:
		buffer.put_u32(self.switch_group_id)
		buffer.put_u32(self.switch_id)
	if self.action_type in EVENT_ACTIONS:
		buffer.put_u8(self.easing_curve)
	buffer.put_partial_data(self._end_bytes)
	self._byte_pool = buffer.data_array
