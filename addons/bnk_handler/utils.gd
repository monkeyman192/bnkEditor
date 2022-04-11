extends Reference

class_name Utils


const FNVINIT = 0x811c9dc5  # inital value for the hash we build from
const FNVPRIME = 0x01000193  # FNV prime multiplier


static func ilog(value: int) -> int:
	# Returns the integer log of the provided value.
	# This corresponds with the length of the value in bits up to the MSB.
	var ret: int = 0
	while value > 0:
		ret += 1
		value = value >> 1

	return ret


static func lookup1_values(entries: int, dimensions: int) -> int:
	# Return the the greatest integer `n` such that n^dimensions <= entries
	# TODO: Maybe make this more efficient?
	return int(pow(entries, (1.0 / dimensions)))


static func bin(value: int) -> String:
	# Convert a integer value to binary.
	var bin_string = ""
	var _value: int = value;
	while _value > 0:
		bin_string += "%s" % (_value & 1)
		_value = _value >> 1
	return bin_string


static func leftpad(input_str: String, length: int, padding_char: String) -> String:
	# Left pad the provided string with the provided character up to teh provided length.
	var _out_str = ""
	for i in range(max(0, length - input_str.length())):
		_out_str += padding_char
	_out_str += input_str
	return _out_str


static func segment_value(value: int, segment_size):
	# Take an integer and split it up into chunks of size `segment_size`.
	# This returns two values. The first is the number of segments, and the second is the
	# remainder, ie. how many bytes to write for the last segment
	var segments = int((value + segment_size) / segment_size)
	var remainder = value % segment_size
	return [segments, remainder]


static func back_enum(_enum, value) -> String:
	# Get the string of the key associated with the provided value.
	var idx: int = _enum.values().find(value)
	if idx != -1:
		return _enum.keys()[idx].capitalize()
	else:
		return "Unmapped value: %s" % value


static func stringify_enum(_enum) -> String:
	var out_string: String = ""
	var _arr: Array = []
	for k in _enum.keys():
		_arr.append([k, _enum[k]])
	for d in _arr:
		out_string += "%s:%s," % d
	# Then trim the trailing comma.
	out_string = out_string.trim_suffix(",")
	return out_string


static func fnv_hash(obj_name: String) -> int:
	# Calculate the 32 bit FNV-1 hash.
	# The source for the constants is found here:
	# https://www.audiokinetic.com/library/2018.1.11_6987/?source=SDK&id=_ak_f_n_v_hash_8h_source.html
	var _hash = FNVINIT
	var split_word: PoolByteArray = obj_name.to_lower().to_ascii()
	for letter in split_word:
		_hash = (_hash * FNVPRIME) ^ letter
		_hash &= 0xFFFFFFFF
	return _hash


static func filepath_iter(root_dir: String, child_dir: String):
	# Return a list of file paths from bottom-up for the purposes of finding a wem.
	if not child_dir.to_lower().begins_with(root_dir.to_lower()):
		return FAILED
	# If the child dir is somewhere underneath the root dir, keep stripping off parts until we get
	# to the root
	var out_dirs = [child_dir]
	while child_dir != root_dir:
		child_dir = child_dir.get_base_dir()
		out_dirs.append(child_dir)
	return out_dirs
