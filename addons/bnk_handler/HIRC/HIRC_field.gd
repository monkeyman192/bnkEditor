extends Reference

class_name HIRC_field

var value
var _original_value

var changed: bool = false setget ,get_changed

func _init(val=null):
	self.value = val
	self._original_value = val

func reset():
	self.value = self._original_value

func get_changed() -> bool:
	return value != _original_value
