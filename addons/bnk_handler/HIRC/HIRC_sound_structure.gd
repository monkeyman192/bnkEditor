extends Reference

class_name SoundStructure

var override_parent_fx: bool
var num_effects: int
var override_params: int
var override_bus_id: int
var parent_obj_id: int
var param_overrides: int
var additional_params: Array
var _end_bytes: PoolByteArray


func load(buffer: StreamPeerBuffer):
	self.override_parent_fx = buffer.get_u8()
	self.num_effects = buffer.get_u8()
	if self.num_effects > 0:
		# Loop over the effects. TODO: Add this functionality?
		pass
	self.override_params = buffer.get_u8()
	self.override_bus_id = buffer.get_u32()
	self.parent_obj_id = buffer.get_u32()
	self.param_overrides = buffer.get_u8()
	var add_param_count = buffer.get_u8()
	self.additional_params = []
	for i in range(add_param_count):
		# For each additional parameter, get the type
		self.additional_params.append([buffer.get_u8()])
	# Now, we need to loop over this range again, adding the value.
	for i in range(add_param_count):
		# For now, this is just a float. This will change to get the data type correctly.
		self.additional_params[i].append(buffer.get_float())
	self._end_bytes = buffer.get_partial_data(buffer.get_available_bytes())[1]
	return self


func serialize() -> PoolByteArray:
	var buffer = StreamPeerBuffer.new()
	buffer.put_u8(self.override_parent_fx)
	buffer.put_u8(self.num_effects)
	# TODO: Add the loop over these.
	buffer.put_u8(self.override_params)
	buffer.put_u32(self.override_bus_id)
	buffer.put_u32(self.parent_obj_id)
	buffer.put_u8(self.param_overrides)
	var add_param_count = self.additional_params.size()
	buffer.put_u8(add_param_count)
	for i in range(add_param_count):
		buffer.put_u8(self.additional_params[i][0])
	for i in range(add_param_count):
		buffer.put_float(self.additional_params[i][1])
	buffer.put_partial_data(self._end_bytes)
	return buffer.data_array
