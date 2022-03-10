extends Reference

class_name SoundStructure

var override_parent_fx: bool
var num_effects: int
var override_bus_id: int
var parent_obj_id: int
var additional_params: Array


func load(buffer: StreamPeerBuffer):
	self.override_parent_fx = buffer.get_u8()
	self.num_effects = buffer.get_u8()
	if self.num_effects > 0:
		# Loop over the effects. TODO: Add this functionality?
		pass
	var override_params = buffer.get_u8()
	self.override_bus_id = buffer.get_u32()
	self.parent_obj_id = buffer.get_u32()
	var param_overrides = buffer.get_u8()
	var add_param_count = buffer.get_u8()
	self.additional_params = []
	for i in range(add_param_count):
		# For each additional parameter, get the type
		self.additional_params.append([buffer.get_u8()])
	# Now, we need to loop over this range again, adding the value.
	for i in range(add_param_count):
		# For now, this is just a float. This will change to get the data type correctly.
		self.additional_params[i].append(buffer.get_float())
	return self
