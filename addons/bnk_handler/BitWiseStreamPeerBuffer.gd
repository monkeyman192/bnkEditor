# Extend the StreamPeerBuffer object to be able to read individual bits.
extends StreamPeerBuffer
class_name BitWiseStreamPeerBuffer

var _bit_buffer: int
# Keep track of number of bits left to read.
var _bits_left: int = 0
# Keep track of number of bits already written.
var _bits_written: int = 0


func _get_bit() -> int:
	# Get an individual bit from the buffer.
	if self._bits_left == 0:
		# If there are no bits left in the buffer, then we need to read the next byte.
		self._bit_buffer = self.get_u8()
		self._bits_left = 8
	self._bits_left -= 1
	# Use a mask which picks the nth bit in the byte (0x80 >> n).
	# Because we read the bits from right to left in the bytes
	# (cf. https://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-360002 section 2.1.2)
	# decreasing self._bits_left moves the "pointer" left.
	return int((self._bit_buffer & (0x80 >> self._bits_left)) != 0)


func get_bits(count: int) -> int:
	# Get multiple bits from the buffer. This can handle an arbitrary number of bytes.
	var result = 0

	for i in range(count): 
		var bit = self._get_bit()
		if bit:
			result |= (1 << i)
	return result


func _put_bit(value: int):
	if value == 1:
		self._bit_buffer |= (1 << self._bits_written)
	self._bits_written += 1
	if self._bits_written == 8:
		self._flush_bits()


func put_bits(value: int, count: int):
	for i in range(count):
		self._put_bit(int(value & (1 << i) != 0))


func _flush_bits():
	# Flush the current bit buffer to the underlying stream.
	# if there are no bytes written to it, don't bother.
	if self._bits_written != 0:
		self.put_u8(self._bit_buffer)
		self._bit_buffer = 0
		self._bits_written = 0

func cseek(position: int):
	# Seek to the specified position but set the bit buffer and such back to 0 so that there are no
	# issues if we read less than 8 bits, then seek then keep reading.
	self._bit_buffer = 0
	self._bits_left = 0
	self._bits_written = 0
	self.seek(position)

func tell() -> String:
	# Get the current location we are reading.
	# This is purely for informational purposes as it will return a string
	# in the format `0XNNN bytes, b bits`
	return "0x%X bytes, %s bits" % [self.get_position() - 1, 8 - self._bits_left]


func _to_string() -> String:
	# Return the bytes representation of the object.
	var out_string = ""
	for b in self.data_array:
		out_string += "%s\n" % Utils.leftpad(Utils.bin(b), 8, "0")
	if self._bits_written > 0:
		out_string += "%s" % Utils.leftpad(
			Utils.leftpad(Utils.bin(self._bit_buffer),self._bits_written,"0"),
			8, "x")
	return out_string
