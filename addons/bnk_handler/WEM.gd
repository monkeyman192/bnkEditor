extends BitWiseStreamPeerBuffer

class_name WEM

# Offsets for all of the different possible chunks.
var _fmt_chunk_offset = null
var _fmt_chunk_size = null
var _cue_chunk_offset = null
var _cue_chunk_size = null
var _list_chunk_offset = null
var _list_chunk_size = null
var _smpl_chunk_offset = null
var _smpl_chunk_size = null
var _vorb_chunk_offset = null
var _vorb_chunk_size = null
var _data_chunk_offset = null
var _data_chunk_size = null

# metadata about the audio.
var channels: int = 0
var sampleRate: int = 0
var averageBitrate: int = 0

var audio_length: float setget ,_get_audio_length

# smpl chunk data
var loopFlag: bool
var loopStartSample: int
var loopEndSample: int

# vorb chunk data
var sampleCount: int
var setupOffset: int
var audioOffset: int
var blockSize0Pow: int
var blockSize1Pow: int
var noGranule: bool = true
var _old_packet_headers: bool = false
var _mod_packets: bool = false

# ogg export stream buffer
var ogg_buffer: BitWiseStreamPeerBuffer
# A buffer for each segment.
# This will be never bigger than 255 bytes, and multiple together will make up a single segment.
var segment_buffer: BitWiseStreamPeerBuffer
var current_segment_sizes: PoolIntArray
# Have a seprate stream buffer for each page also.
# We always write to the page buffer and then this will get flushed to the
# ogg stream buffer.
var page_buffer: BitWiseStreamPeerBuffer
var page_bytes: int

# Ogg page variables
var packetContinued: bool = false
var pageFirst: bool = true
var granule: int = 0
var pageSeqNo: int = 0
var last_blocksize: int = 0
var granpos: int = 0

# Mode stuff
var mode_block_flag: PoolByteArray
var mode_bits: int

const OGG_PAGE_HEADER_SIZE = 27
const MAX_SEGMENTS = 0xFF			# 255 (bytes)
const SEGMENT_SIZE = 0xFF			# 255 (bytes)
const NOMINAL_MAX_PAGE_SIZE = 0xFFF	# 4095 (bytes)

var codebookCount: int


func open(path: String) -> int:
	# Load a .wem file from disk into memory.
	var f = File.new()
	print("opening %s" % path)
	var err: int = f.open(path, f.READ)
	if err != OK:
		print("There was an error: %s" % err)
		return err
	self.set_data_array(f.get_buffer(f.get_len()))
	self.big_endian = false
	f.close()
	self._parse_wem()
	return OK


func from_bytes(bytes: PoolByteArray):
	# Load a wem from memory.
	self.set_data_array(bytes)
	self.big_endian = false
	self._parse_wem()


func preparse_chunks():
	# Do an initial pass over the wem file to get the offsets of the chunks.

	# Make certain we are at the start of the stream.
	self.cseek(0)
	var magic = self.get_string(4)
	if magic != "RIFF":
		print("Invalid .wem file")
		return null
	# Total size of the RIFF chunk.
	var _riff_size = self.get_u32() + 8
	var wave_magic = self.get_string(4)
	if wave_magic != "WAVE":
		print("Invalid .wem file")
		return null
	# Now, go over each of the chunks and see what we have.
	while self.get_position() < _riff_size:
		# Get the magic, size and current position.
		var chunk_magic = self.get_string(4)
		var chunk_size = self.get_u32()
		var chunk_start = self.get_position()
		# Now, match the magic against some values so we know what to assign it to.
		if chunk_magic.left(3) == "fmt":
			self._fmt_chunk_offset = chunk_start
			self._fmt_chunk_size = chunk_size
		elif chunk_magic.left(3) == "cue":
			self._cue_chunk_offset = chunk_start
			self._cue_chunk_size = chunk_size
		elif chunk_magic == "LIST":
			self._list_chunk_offset = chunk_start
			self._list_chunk_size = chunk_size
		elif chunk_magic == "smpl":
			self._smpl_chunk_offset = chunk_start
			self._smpl_chunk_size = chunk_size
		elif chunk_magic == "vorb":
			self._vorb_chunk_offset = chunk_start
			self._vorb_chunk_size = chunk_size
		elif chunk_magic == "data":
			self._data_chunk_offset = chunk_start
			self._data_chunk_size = chunk_size
		elif chunk_magic == "JUNK":
			# Junk just seems to be some number of bytes of nothing.
			# Store nothing and skip it.
			pass
		elif chunk_magic.left(3) == "akd":
			# This has some data in it. But for now, we'll not parse it as I am
			# not sure what it is...
			pass
		# Seek to the end of the chunk.
		self.cseek(chunk_start + chunk_size)

		# If we have no vorb chunk and the fmt chunk is 0x42 long, then we will
		# actually only take the first 0x18 bytes of the fmt chunk, and the
		# remaining bytes are considered the vorb chunk.
		if (self._vorb_chunk_offset == null) and (self._fmt_chunk_size == 0x42):
			self._vorb_chunk_offset = self._fmt_chunk_offset + 0x18
			# Set the sizes correct also while we are here.
			self._vorb_chunk_size = 0x2A
			self._fmt_chunk_size = 0x18
			self._old_packet_headers = false


func read_fmt_chunk() -> bool:
	# Read the fmt chunk to get some header data.

	# Format:
	# 0x00: u16: codecID
	# 0x02: u16: channels
	# 0x04: u32: sampleRate
	# 0x08: u32: averageBitrate
	# 0x0C: u16: blockSize
	# 0x0E: u16: bitsPerSample
	# 0x10: u16: extraSize
	# if extraSize > 0x6:
	# 0x14: u32: channelLayout
	# Note: some further processing is done on the channelLayout.
	# if channelLayout & 0xFF == channels:
	# channelLayout = channelLayout >> 12
	# channelType = (channelLayout >> 8) & 0xF

	self.cseek(self._fmt_chunk_offset)
	var codecID = self.get_u16()
	if codecID != 0xFFFF:
		print("CodecID is incorrect. Expected 0xFFFF")
		return false

	self.channels = self.get_u16()
	self.sampleRate = self.get_u32()
	self.averageBitrate = self.get_u32()

	# Read some extra values. At the moment just use these for checking.
	if self.get_u16() != 0:
		print("FMT Chunk - Wrong Block Align")

	if self.get_u16() != 0:
		print("FMT Chunk - Wrong Bits Per Sample")

	var extraData = self.get_u16()
	if extraData != self._vorb_chunk_size + 0x6:
		print("FMT Chunk - extra data size doesn't match")

	return true


func read_smpl_chunk() -> bool:
	# Read the smpl section.
	# We will skip the first 0x1C bytes as all there is is the sample rate which we already know.
	if self._smpl_chunk_offset == null:
		# If we have no smpl offset, do nothing.
		return false
	self.cseek(self._smpl_chunk_offset + 0x1C)
	var loopCount = self.get_u32()
	self.cseek(self._smpl_chunk_offset + 0x28)
	var loopType = self.get_u32()
	if (loopCount == 1) && (loopType == 0):
		self.loopFlag = true
		self.loopStartSample = self.get_u32()
		self.loopEndSample = self.get_u32() + 1  # +1 like standard RIFF
	return true


func read_vorb_chunk() -> bool:
	# Read the vorb chunk.
	# If this isn't it's own distinct chunk, then it will be in the extra section of the fmt chunk
	# (hopefully!)

	# Format:
	# 0x00: u32: sampleCount
	# 0x04: modSignal
	# ...
	# 0x10: u32: setupOffset
	# 0x14: u32: audioOffset
	# 0x28: u8: blockSize0Pow
	# 0x29: u8: blockSize1Pow
	self.cseek(self._vorb_chunk_offset)
	self.sampleCount = self.get_u32()
	var mod_signal = self.get_u32()
	if not mod_signal in [0x4A, 0x4B, 0x69, 0x70]:
		self._mod_packets = true
	self.cseek(self._vorb_chunk_offset + 0x10)
	self.setupOffset = self.get_u32()
	self.audioOffset = self.get_u32()
	self.cseek(self._vorb_chunk_offset + 0x28)
	self.blockSize0Pow = self.get_u8()
	self.blockSize1Pow = self.get_u8()

	return true


func postprocess_chunks():
	# Now that we have gone over all the chunks (other than data), do some post-processing
	# to set some data.
	if self.loopFlag:
		if self.loopEndSample == 0:
			self.loopEndSample = self.sampleCount
		else:
			self.loopEndSample += 1


# Next chunk are related to writing of ogg data.


func export_to_ogg(path: String, full_setup: bool = false):
	# Export to an ogg file on disk.
	var f = File.new()

	if f.open(path, f.WRITE) != OK:
		print("Can't write to the file %s" % path)

	f.store_buffer(self.to_ogg(full_setup))
	f.close()


func to_ogg(full_setup: bool = false) -> PoolByteArray:
	# Convert the wem file to an ogg in memory, returning a PoolByteArray.

	# Create two stream buffers. The ogg buffer will be the one which will
	# eventually be output to a file or byte array.
	self.ogg_buffer = BitWiseStreamPeerBuffer.new()
	# This page buffer stream will contain each page, flushed to the ogg
	# buffer, then cleared.
	self.page_buffer = BitWiseStreamPeerBuffer.new()
	# Also create a segment buffer for each segment so that we can flush them to a page until it
	# reaches some size, then flush that to the ogg stream and continue.
	self.segment_buffer = BitWiseStreamPeerBuffer.new()

	# Seek to teh start of the wem file just to make sure.
	self.cseek(0)
	# Write the headers then audio pages.
	self._write_vorbis_headers(full_setup)
	self._write_audio_pages()
	return self.ogg_buffer.data_array


func flush_page(next_continued: bool = false, last: bool = false, audio_page: bool = false,
				blocksize: int = 0):
	# Flush the ogg page to file.
	var segments: int = 0
	var _flush: bool = false
	var granpos: int
	if !audio_page:
		# If it's a header we are flushing, write the whole lot in one page.
		self.page_buffer._flush_bits()
		self.page_bytes = self.page_buffer.get_size()
		_flush = true
		self.current_segment_sizes.append(self.page_bytes)
	else:
		# Otherwise, capture the number of bytes in this segment.
		# Flush the bits in the current segment buffer.
		self.segment_buffer._flush_bits()
		var segment_size = self.segment_buffer.get_size()
		self.page_bytes += segment_size
		self.current_segment_sizes.append(segment_size)
		# Then write to the page buffer.
		self.page_buffer.put_data(self.segment_buffer.data_array)
		# And then clear the segment buffer.
		self.segment_buffer.clear()
		# If the number of page bytes is greater than the nominal max, flush.
		if self.page_bytes > NOMINAL_MAX_PAGE_SIZE or last:
			_flush = true

	if self.page_bytes == 0:
		# If we somehow have nothing to write, return.
		return

	segments = self.current_segment_sizes.size()
	if self.last_blocksize != 0:
		self.granpos += int((self.last_blocksize + blocksize) / 4)
	self.last_blocksize = blocksize

	if !_flush:
		# If we don't need to flush, simply return now.
		return

	# Calculate the segment sizes before we write stuff as we need the size.
	# We loop over the current_segment_sizes and write the values to a PoolByteArray
	var lacing_data: PoolByteArray = PoolByteArray()
	for i in self.current_segment_sizes:
		var _segments = Utils.segment_value(i, SEGMENT_SIZE)
		if _segments[0] == 1:
			# If there is only one segment, then we write just the remainder.
			lacing_data.append(_segments[1])
		else:
			# Write n x 0xFF byte section lacing values.
			for j in range(_segments[0] - 1):
				lacing_data.append(SEGMENT_SIZE)
			# Then, write the remainder.
			lacing_data.append(_segments[1])

	var page_start = self.ogg_buffer.get_position()
	self.ogg_buffer.put_data("OggS".to_ascii())		# 0x00 -> magic
	self.ogg_buffer.put_u8(0)						# 0x04 -> stream_structure_version
	# Determine the header_type flag.
	var header_type: int = (
		(int(self.packetContinued) << 0)
		| (int(self.pageFirst) << 1)
		| (int(last) << 2)
	)
	self.ogg_buffer.put_u8(header_type)				# 0x05 -> header_type
	self.ogg_buffer.put_u64(self.granpos)			# 0x06 -> absolute granule position
	self.ogg_buffer.put_data("gdt".to_ascii())		# 0x0E -> stream serial number (gdt for Godot)
	self.ogg_buffer.put_u8(0)						# (one extra empty byte so it's 4 bytes)
	self.ogg_buffer.put_u32(self.pageSeqNo)			# 0x12 -> page sequence number
	# Get the location of the crc value, so we can write to it later.
	var crc_loc = self.ogg_buffer.get_position()
	self.ogg_buffer.put_u32(0)						# 0x16 -> crc checksum (empty for now)
	self.ogg_buffer.put_u8(lacing_data.size())		# 0x1A -> page_segments

	# Now, we can write the lacing data
	for i in lacing_data:
		self.ogg_buffer.put_u8(i)

	# Now, we need to append the actual page buffer.
	self.ogg_buffer.put_data(self.page_buffer.data_array)
	# Clear the page buffer
	self.page_buffer.clear()
	# Then, get the bytes that we just put in and create the crc checksum for it.
	var chksum: int = crc.new().checksum(
		self.ogg_buffer.data_array.subarray(page_start, -1)
	)
	self.ogg_buffer.cseek(crc_loc)
	self.ogg_buffer.put_u32(chksum)
	self.ogg_buffer.cseek(self.ogg_buffer.get_size())

	self.pageFirst = false
	self.packetContinued = next_continued
	self.page_bytes = 0
	self.current_segment_sizes.resize(0)
	self.pageSeqNo += 1


func write_vorbis_header(packet_type: int):
	# Write the common vorbis header format.
	# This will be the packet_type:
	# 1: Identification
	# 3: Comment
	# 5: Setup
	# Note. The headers MUST be written in this order.
	# A packet_type of 0 indiciates an audio packet.
	self.page_buffer.put_u8(packet_type)
	self.page_buffer.put_data("vorbis".to_ascii())


func _write_vorbis_headers(fullSetup: bool):
	self._write_vorbis_id_header()
	self._write_vorbis_comment_header()
	self._write_vorbis_setup_header(fullSetup)

func _write_vorbis_id_header():
	# Write the id header packet
	# This has the following format:
	#
	# u32: vorbis_version = 0
	# u8: audio_channels
	# u32: audio_sample_rate = read 32 bits as unsigned integer
	# s32: bitrate_maximum = read 32 bits as signed integer
	# s32: bitrate_nominal = read 32 bits as signed integer
	# s32: bitrate_minimum = read 32 bits as signed integer
	# u4: blocksize_0 = 2 exponent (read 4 bits as unsigned integer)
	# u4: blocksize_1 = 2 exponent (read 4 bits as unsigned integer)
	# 1b: framing_flag = 0
	self.write_vorbis_header(1)
	self.page_buffer.put_u32(0)
	self.page_buffer.put_u8(self.channels)
	self.page_buffer.put_u32(self.sampleRate)
	self.page_buffer.put_u32(0)
	self.page_buffer.put_u32(self.averageBitrate * 8)
	self.page_buffer.put_u32(0)
	self.page_buffer.put_bits(self.blockSize0Pow, 4)
	self.page_buffer.put_bits(self.blockSize1Pow, 4)
	self.page_buffer.put_bits(1, 1)
	self.flush_page()


func _write_vorbis_comment_header():
	# Write the comment header.
	# We will do a simplified version and not add any comments in the list,
	# but instead use the vendor section to write a comment.
	self.write_vorbis_header(3)
	var comment_string = "Converted to ogg by wwGodot"
	var comment_length = comment_string.length()
	self.page_buffer.put_u32(comment_length)
	self.page_buffer.put_data(comment_string.to_ascii())
	# Write this as 0 to indicate we have no other comments.
	self.page_buffer.put_u32(0)
	self.page_buffer.put_bits(1, 1)
	self.flush_page()


func _write_vorbis_setup_header(fullSetup: bool):
	# Write the setup header.
	# This has a bunch of stuff in it...
	self.write_vorbis_header(5)
	var pckt = Packet.new()
	pckt.create(self, self._data_chunk_offset + self.setupOffset, self.noGranule)
	self.cseek(pckt.get_offset())
	self.codebookCount = self.get_u8()
	self.page_buffer.put_u8(self.codebookCount)
	self.codebookCount += 1

	# For now, we will assume only an external codebook.
	var codebook: Codebook = Codebook.new()
	codebook.open("packed_codebooks_aoTuV_603.bin")
	for i in range(self.codebookCount):
		var codebookID = self.get_bits(10)
		codebook.rebuild(codebookID, self.page_buffer)

	# Time domain transforms
	self.page_buffer.put_bits(0, 6)		# TimeCount. Value isn't used so set to 0.
	self.page_buffer.put_bits(0, 16)		# These bits MUST all be 0.

	if fullSetup:
		print("THIS ISNT IMPLEMENTED...")
		# TODO: Make this work...
		pass
	else:
		# Floor count.
		var floorCount = self.get_bits(6)
		self.get_position()
		self.page_buffer.put_bits(floorCount, 6)
		floorCount += 1

		# Rebuild floor data.
		for i in range(floorCount):
			self.page_buffer.put_bits(1, 16)	# floorType We'll use type 1.
			var floorPartitions = self.get_bits(5)
			self.page_buffer.put_bits(floorPartitions, 5)

			var floorPartitionClassList: PoolByteArray = PoolByteArray()
			floorPartitionClassList.resize(floorPartitions)
			var maximumClass: int = 0
			# Iterate over the partitions.
			# Add each value to an array, and capture the maximum value in the array.
			for j in range(floorPartitions):
				var floorPartitionClass = self.get_bits(4)
				self.page_buffer.put_bits(floorPartitionClass, 4)
				floorPartitionClassList[j] = floorPartitionClass
				if floorPartitionClass > maximumClass:
					maximumClass = floorPartitionClass

			var floorClassDimensionList: PoolByteArray = PoolByteArray()
			floorClassDimensionList.resize(maximumClass + 1)
			for j in range(maximumClass + 1):
				var classDimension = self.get_bits(3)
				self.page_buffer.put_bits(classDimension, 3)
				floorClassDimensionList[j] = classDimension + 1

				var classSubclasses = self.get_bits(2)
				self.page_buffer.put_bits(classSubclasses, 2)
				if classSubclasses != 0:
					var masterbook: int = self.get_bits(8)
					self.page_buffer.put_bits(masterbook, 8)
					if masterbook >= self.codebookCount:
						print("Invalid floor masterbook: %s" % masterbook)
				
				for k in range(1 << classSubclasses):
					var subclassBook = self.get_bits(8)
					self.page_buffer.put_bits(subclassBook, 8)
					if (subclassBook - 1) >= 0 and (subclassBook - 1) >= self.codebookCount:
						print("Invalid floor subclass book")

			self.page_buffer.put_bits(self.get_bits(2), 2)		# floorMultiplier
			var rangeBits = self.get_bits(4)
			self.page_buffer.put_bits(rangeBits, 4)
			
			for j in range(floorPartitions):
				var currentClassNumber = floorPartitionClassList[j]
				for k in range(floorClassDimensionList[currentClassNumber]):
					self.page_buffer.put_bits(self.get_bits(rangeBits), rangeBits)

		# Residue count.
		var residueCount = self.get_bits(6)
		self.page_buffer.put_bits(residueCount, 6)
		residueCount += 1

		# Rebuild residues.
		for i in range(residueCount):
			var residueType = self.get_bits(2)
			self.page_buffer.put_bits(residueType, 16)
			if residueType > 2:
				print("Invalid residue type: %s" % residueType)

			var residueBegin = self.get_bits(24)
			var residueEnd = self.get_bits(24)
			var residuePartitionSize = self.get_bits(24)
			var residueClassifications = self.get_bits(6)
			var residueClassbook = self.get_bits(8)

			self.page_buffer.put_bits(residueBegin, 24)
			self.page_buffer.put_bits(residueEnd, 24)
			self.page_buffer.put_bits(residuePartitionSize, 24)
			self.page_buffer.put_bits(residueClassifications, 6)
			self.page_buffer.put_bits(residueClassbook, 8)

			residueClassifications += 1
			if residueClassbook >= self.codebookCount:
				print("Invalid residue codebook")
			
			var residueCascade: PoolByteArray = PoolByteArray()
			residueCascade.resize(residueClassifications)

			# Determine which partition classes code values in which passes.
			for j in range(residueClassifications):
				var highBits = 0
				var lowBits = self.get_bits(3)
				self.page_buffer.put_bits(lowBits, 3)

				var bitFlag = self.get_bits(1)
				self.page_buffer.put_bits(bitFlag, 1)

				if bitFlag == 1:
					highBits = self.get_bits(5)
					self.page_buffer.put_bits(highBits, 5)

				residueCascade[j] = highBits * 8 + lowBits

			for j in range(residueClassifications):
				for k in range(8):
					if (residueCascade[j] & (1 << k)) != 0:
						var residueBook = self.get_bits(8)
						self.page_buffer.put_bits(residueBook, 8)
						if residueBook >= self.codebookCount:
							print("Invalid residue book found")
			
			residueCascade.resize(0)
		
		# Mapping count
		var mappingCount = self.get_bits(6)
		self.page_buffer.put_bits(mappingCount, 6)
		mappingCount += 1

		# Rebuild mapping.
		for i in range(mappingCount):
			# Mapping Type of 0 always (it's the only option).
			self.page_buffer.put_bits(0, 16)

			var submapsFlag = self.get_bits(1)
			self.page_buffer.put_bits(submapsFlag, 1)

			var submaps = 1
			if submapsFlag:
				var _submaps = self.get_bits(4)
				self.page_buffer.put_bits(_submaps, 4)
				submaps = _submaps + 1
			
			var squarePolarFlag = self.get_bits(1)
			self.page_buffer.put_bits(squarePolarFlag, 1)

			if squarePolarFlag == 1:
				var couplingSteps = self.get_bits(8)
				self.page_buffer.put_bits(couplingSteps, 8)
				couplingSteps += 1
			
				for j in range(couplingSteps):
					var ilog_channels = Utils.ilog(self.channels - 1)
					var magnitude = self.get_bits(ilog_channels)
					var angle = self.get_bits(ilog_channels)
					self.page_buffer.put_bits(magnitude, ilog_channels)
					self.page_buffer.put_bits(angle, ilog_channels)
					if (angle == magnitude) or (magnitude >= self.channels) or (angle >= self.channels):
						print("Invalid coupling")
			
			var mappingReserved = self.get_bits(2)
			self.page_buffer.put_bits(mappingReserved, 2)
			if mappingReserved != 0:
				print("Invalid mapping reserve. Expected 0")
			
			if submaps > 1:
				for j in range(self.channels):
					var mappingMux = self.get_bits(4)
					self.page_buffer.put_bits(mappingMux, 4)
					if mappingMux >= submaps:
						print("Invalid mappingMux")
			
			for j in range(submaps):
				self.page_buffer.put_bits(self.get_bits(8), 8)		# timeConfig

				var floorNumber = self.get_bits(8)
				self.page_buffer.put_bits(floorNumber, 8)
				if floorNumber >= floorCount:
					print("Invalid floorNumber")

				var residueNumber = self.get_bits(8)
				self.page_buffer.put_bits(residueNumber, 8)
				if residueNumber >= residueCount:
					print("Invalid residueNumber")

		# Mode count.
		var modeCount = self.get_bits(6)
		self.page_buffer.put_bits(modeCount, 6)
		modeCount += 1

		# Rebuild mode.
		self.mode_block_flag = PoolByteArray()
		self.mode_block_flag.resize(modeCount)
		self.mode_bits = Utils.ilog(modeCount - 1)

		for i in range(modeCount):
			var blockFlag = self.get_bits(1)
			self.page_buffer.put_bits(blockFlag, 1)
			self.mode_block_flag[i] = blockFlag

			self.page_buffer.put_bits(0, 16)		# WindowType
			self.page_buffer.put_bits(0, 16)		# transformType

			var mapping = self.get_bits(8)
			self.page_buffer.put_bits(mapping, 8)
			if mapping >= mappingCount:
				print("Invalid mapping value")
		
		# Finish by writing the framing bit
		self.page_buffer.put_bits(1, 1)

	self.flush_page()


func _write_audio_pages():
	var offset = self._data_chunk_offset + self.audioOffset

	var prev_block_flag = 0

	# Loop over the data chunk.
	while offset < self._data_chunk_offset + self._data_chunk_size:
		var size: int
		var granule: int
		var packet_header_size: int
		var packet_payload_offset: int
		var next_offset: int
		var blocksize: int = 0

		if self._old_packet_headers:
			# Maybe make this work?
			return
		else:
			var audio_packet: Packet = Packet.new()
			audio_packet.create(self, offset, self.noGranule)
			size = audio_packet.get_size()
			packet_payload_offset = audio_packet.get_offset()
			granule = audio_packet.get_granule()
			next_offset = audio_packet.next_offset()
		
		if offset + packet_header_size > self._data_chunk_offset + self._data_chunk_size:
			print("Page header truncated")
		
		offset = packet_payload_offset

		self.cseek(offset)
		if granule == 0xFFFFFFFF:
			self.granule = 1
		else:
			self.granule = granule
		
		if self._mod_packets:
			# Modified packets. Need to rebuild packet type and window info.
			if self.mode_block_flag.size() == 0:
				print("Error loading mode_block_flag")
			self.segment_buffer.put_bits(0, 1)
			var mode_number: int = 0
			var remainder: int = 0

			mode_number = self.get_bits(self.mode_bits)
			self.segment_buffer.put_bits(mode_number, self.mode_bits)
			remainder = self.get_bits(8 - self.mode_bits)

			if self.mode_block_flag[mode_number] != 0:
				blocksize = (1 << self.blockSize1Pow)
				self.cseek(next_offset)
				var next_block_flag: int = 0  # bool, but we'll use int for simplicity.
				if next_offset + packet_header_size <= self._data_chunk_offset + self._data_chunk_size:
					# This is a "long window". Basically the window overlaps with the next or
					# previous window. We need to add some flags to indicate this, so we need to
					# look at the following block and assign the flags appropriately.
					var audio_packet: Packet = Packet.new()
					audio_packet.create(self, next_offset, self.noGranule)
					var next_packet_size: int = audio_packet.get_size()
					if next_packet_size > 0:
						self.cseek(audio_packet.get_offset())
						var next_mode_number: int = self.get_bits(self.mode_bits)
						next_block_flag = self.mode_block_flag[next_mode_number]
				self.segment_buffer.put_bits(prev_block_flag, 1)
				self.segment_buffer.put_bits(next_block_flag, 1)

				# Go to the next bit to continue reading.
				self.cseek(offset + 1)
			else:
				blocksize = (1 << self.blockSize0Pow)
			prev_block_flag = self.mode_block_flag[mode_number]
			self.segment_buffer.put_bits(remainder, 8 - self.mode_bits)
		else:
			self.segment_buffer.put_bits(self.get_u8(), 8)
		# The rest of the payload is copied as usual.
		var _data = self.get_partial_data(size - 1)[1]
		self.segment_buffer.put_array(_data)
		offset = next_offset
		self.flush_page(false, offset == self._data_chunk_offset + self._data_chunk_size, true,
						blocksize)


# Other functions.


func print_info():
	# Print a bunch of info about the wem file. Mostly for debugging.
	print("Channels: %s" % self.channels)
	print("Sample rate: %sHz" % self.sampleRate)
	print("Average bitrate: %s" % self.averageBitrate)
	print("Sample count: %s" % self.sampleCount)
	if self.loopFlag:
		print("Loop from %s to %s" % [self.loopStartSample, self.loopEndSample])
	print("Block Size 0: %s" % self.blockSize0Pow)
	print("Block Size 1: %s" % self.blockSize1Pow)


func _parse_wem():
	preparse_chunks()
	read_fmt_chunk()
	read_smpl_chunk()
	read_vorb_chunk()
	postprocess_chunks()


func _get_audio_length() -> float:
	return float(self.sampleCount) / float(self.sampleRate)
