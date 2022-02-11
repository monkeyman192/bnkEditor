extends Node

class_name Codebook


var _codebookCount: int
var _codebookData: PoolByteArray
var _codebookOffsets: PoolIntArray


func open(cb_path: String):
	var f = File.new()
	if f.open(cb_path, f.READ) != OK:
		print("Cannot load %s" % cb_path)
	# Read the file into a buffer then close the file.
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.set_data_array(f.get_buffer(f.get_len()))
	stream.big_endian = false
	f.close()

	# Read the offset from the last 4 bytes of the file.
	stream.seek(stream.get_size() - 4)
	var offset = stream.get_u32()
	self._codebookCount = int((stream.get_size() - offset) / 4)
	# Reserve self._codebookCount values in self._codebookOffsets
	self._codebookOffsets.resize(self._codebookCount)
	stream.seek(0)
	# Read the codebook data into the variable.
	# TODO: Should be able to do this by doing `get_data` to move the current position.
	# Not sure why it's not working... :/
	self._codebookData = stream.data_array.subarray(0, offset - 1)
	stream.seek(offset)
	for i in range(self._codebookCount):
		self._codebookOffsets.set(i, stream.get_u32())


func rebuild(index: int, oggBuffer: BitWiseStreamPeerBuffer):
	var codebookStream: BitWiseStreamPeerBuffer = BitWiseStreamPeerBuffer.new()
	codebookStream.set_data_array(self.get_codebook(index))
	var codebookSize = self.get_codebook_size(index)
	self._rebuild(codebookStream, codebookSize, oggBuffer)


func _rebuild(codebook: BitWiseStreamPeerBuffer, codebookSize: int, oggBuffer: BitWiseStreamPeerBuffer):
	codebook.seek(0)
	# Get some initial data.
	var dimensions = codebook.get_bits(4)
	var entries = codebook.get_bits(14)

	# Now, write some data back to the ogg stream.
	oggBuffer.put_bits(0x564342, 24)
	oggBuffer.put_bits(dimensions, 16)
	oggBuffer.put_bits(entries, 24)

	# Consider whether the data is ordered or not.
	var orderedFlag = codebook.get_bits(1)
	oggBuffer.put_bits(orderedFlag, 1)

	if orderedFlag == 1:
		# The codebooks are ordered by size.
		# In this case we read the initial length (5 bits), then go over the codebooks.
		oggBuffer.put_bits(codebook.get_bits(5), 5)	# Initial length

		var currentEntry = 0
		while currentEntry < entries:
			var bitCount = Utils.ilog(entries - currentEntry)
			var number = codebook.get_bits(bitCount)
			oggBuffer.put_bits(number, bitCount)
			currentEntry += number
	else:
		var codewordLengthLength = codebook.get_bits(3)
		var sparseFlag = codebook.get_bits(1)
		oggBuffer.put_bits(sparseFlag, 1)

		if codewordLengthLength == 0 or codewordLengthLength > 5:
			print("Error rebuilding codebook!")

		for i in range(entries):
			var present: bool = true
			if sparseFlag == 1:
				var sparsePresenceFlag = codebook.get_bits(1)
				oggBuffer.put_bits(sparsePresenceFlag, 1)
				present = (sparsePresenceFlag == 1)
			if present:
				oggBuffer.put_bits(codebook.get_bits(codewordLengthLength), 5)
	
	# Next, handle lookup types.
	var lookupType = codebook.get_bits(1)
	oggBuffer.put_bits(lookupType, 4)

	if lookupType == 1:
		oggBuffer.put_bits(codebook.get_bits(32), 32)	# minimum length (float)
		oggBuffer.put_bits(codebook.get_bits(32), 32)	# maxaximum length
		var valueLength = codebook.get_bits(4)
		oggBuffer.put_bits(valueLength, 4)
		oggBuffer.put_bits(codebook.get_bits(1), 1)	# sequence flag

		var quantValues = Utils.lookup1_values(entries, dimensions)
		for i in range(quantValues):
			oggBuffer.put_bits(codebook.get_bits(valueLength + 1), valueLength + 1)

func get_codebook(index: int) -> PoolByteArray:
	return self._codebookData.subarray(self._codebookOffsets[index], self._codebookOffsets[index + 1] - 1)


func get_codebook_size(index: int) -> int:
	# Get the size of the specified codebook.
	# TODO: Add some safety to this...
	return self._codebookOffsets[index + 1] - self._codebookOffsets[index]


func print_details():
	print("Codebook count: %s" % self._codebookCount)
	# print("Codebook offsets: %s" % self._codebookOffsets)
