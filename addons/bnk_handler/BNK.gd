extends Node

class_name BNK

const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

var version: int setget ,_get_bnk_version

# Keep a reference in the class to the stream we load the file into so we only need to read it from
# disk once.
var _file_stream: StreamPeerBuffer

# Containers for the various data types
var bkhd: BKHD = BKHD.new()
var didx: DIDX = DIDX.new()
var hirc: HIRC = HIRC.new()
var stid: STID		# Don't instantiate it as we'll only want to write this back if it's not null.

# Locations of each of the sections. We'll store these so that we can lazy load the file, loading
# everything except the data chunk to save time
var _bkhd_offset: int
var _bkhd_size: int
var _didx_offset: int
var _didx_size: int
var _data_offset: int
var _data_size: int
var _hirc_offset: int
var _hirc_size: int
var _stid_offset: int
var _stid_size: int

var audio_ids: Array = [] setget ,_get_audio_ids

# Keep track of what wems we have extracted.
# Once we have extracted it once it will be stored here and we can immediately pull it out.
var wem_data: Dictionary
# Keep a count of the number of modified HIRC segments. If this is 0 then we can just write the
# original HIRC chunk back as it was.
# TODO: Maybe this will be a list. For now will be a count.
var modified_hirc_chunks: int

# Some variables to be read to allow us to hook into the import or export progress to show this on
# the front end. This will be run in a separate thread so these values MUST only be written to from
# within this class.
var import_progress: int = 0
var import_process_hirc: int = 0
var export_progress: int = 0
var export_progress_hirc: int = 0
var export_subprogress: int = 0

enum EXPORT_STEPS {NOTHING, BKHD, DIDX, DATA, HIRC, STID, TO_FILE, COMPLETE}
enum HIRC_EXPORT_STEPS {NOTHING, PERSIST, WRITE}

# Create a mapping between the hirc types and the objects used to load the data.
var HIRC_MAPPING: Dictionary = {
	0x2: _HIRC_02_SOUND_SFX,
	0x3: _HIRC_03_EVENT_ACTION,
	0x4: _HIRC_04_EVENT,
}


class BKHD:
	var version: int = 0
	var sound_bank_id: int
	var unknown: PoolByteArray

	func size() -> int:
		return 8 + self.unknown.size()


class DIDX_entry:
	var offset: int
	var file_size: int


class DIDX:
	var id_mapping: Dictionary = {}

	func size() -> int:
		return 0xC * self.id_mapping.size()


class HIRC:
	var object_count: int
	var data: Array = []

	func persist_changes():
		# For every HIRC object with changes, persist them to the underlying PoolByteArray so that
		# the size calculation is correct.
		self.export_progress_hirc = 0
		for obj in data:
			obj.persist_changes()
			self.export_progress_hirc += 1

	func size() -> int:
		# Return the total size of the HIRC section. We start with 4 (the size of the count).
		var _size = 4
		for chunk in data:
			_size += chunk.size
		return _size


class STID:
	var unknown: int = 1	# This value is always 1.
	var soundbank_count: int
	var soundbank_data: Dictionary


func get_wem(audio_id: int) -> PoolByteArray:
	# Get the specified wem to a PoolByteArray so that it can be converted to ogg...
	if not audio_id in self.wem_data:
		# Extract the audio chunk from the underlying stream
		var _wem_data: DIDX_entry = self.didx.id_mapping[audio_id]
		# Jump the filestream to the offset of this and then read the approriate amount of bytes.
		self._file_stream.seek(self._data_offset + _wem_data.offset)
		self.wem_data[audio_id] = self._file_stream.get_partial_data(_wem_data.file_size)[1]
	return self.wem_data[audio_id]


func export_wem(audio_id: int, out_path: String, to_ogg: bool = false):
	# Export the specified wem to a file.
	# If `to_ogg` is true, convert to an .ogg file.
	var _wem_data: PoolByteArray = self.get_wem(audio_id)
	var out_fname: String = out_path + "/%s" % audio_id
	if to_ogg:
		var wem = WEM.new()
		wem.from_bytes(_wem_data)
		wem.export_to_ogg(out_fname + ".ogg")
	else:
		var ofile = File.new()
		ofile.open(out_fname + ".wem", File.WRITE)
		ofile.store_buffer(_wem_data)
		ofile.close()


func extract_all(out_path: String, to_ogg: bool = false):
	# Export all contained audio files, optionionally converting to ogg.
	for audio_id in self.didx.id_mapping.keys():
		self.export_wem(audio_id, out_path, to_ogg)


func extract_many(audio_ids: PoolIntArray, out_path: String, to_ogg: bool = false):
	# Export multiple wem's from within the bnk.
	for audio_id in audio_ids:
		self.export_wem(audio_id, out_path, to_ogg)


func open(path: String, preload_data: bool = false) -> bool:
	# Open a .bnk file for processing.
	# If preload_data is true, then the entire data chunk will be preloaded into memory.
	# This option has slower initial load times, but once the bnk is loaded, all other operations
	# will be more efficient.
	# Note: Setting this as false will incur a single disk load for every wem extracted unless
	# bulk extraction mode is used. Further, when extracting wem files if preload_data is false,
	# The extracted data blocks will be stored in memory also for later use (eg. if playing the
	# wem file from the bnk, don't want to extract it repeatedly. Although in this case the
	# exported ogg will also be cached to save repeated re-encodings, so caching the wem may not be
	# necessary... We shall see...)
	var f = File.new()

	if f.open(path, File.READ) != OK:
		return false
	self._file_stream = StreamPeerBuffer.new()
	var bnk_length = f.get_len()
	self._file_stream.set_data_array(f.get_buffer(bnk_length))
	self._file_stream.big_endian = false
	f.close()

	self._read_file(bnk_length, preload_data)
	return true


func write(path: String) -> int:
	# Write the bnk file back to disk, including any changes that have been made to it.
	var f = File.new()
	var _f_res = f.open(path, File.WRITE)
	if _f_res != OK:
		return _f_res
	# Create a stream buffer for the output.
	var fs = StreamPeerBuffer.new()
	fs.big_endian = false
	self.export_progress = EXPORT_STEPS.BKHD
	self._write_bkhd(fs)
	self.export_progress = EXPORT_STEPS.DIDX
	self._write_didx(fs)
	self.export_progress = EXPORT_STEPS.DATA
	self._write_data(fs)
	self.export_progress = EXPORT_STEPS.HIRC
	self._write_hirc(fs)
	if self.stid != null:
		self.export_progress = EXPORT_STEPS.STID
		self._write_stid(fs)
	self.export_progress = EXPORT_STEPS.TO_FILE
	f.store_buffer(fs.data_array)
	self.export_progress = EXPORT_STEPS.COMPLETE
	return OK


func _read_file(bnk_length: int, preload_data: bool = false):
	# First port of call for reading the file.
	# The structure is very simple. We'll read 4 bytes as a string and 4 bytes for its size,
	# determine whether we know how to deal with the chunk, if so, load it, if not, store the raw
	# bytes and skip it.
	self._file_stream.seek(0)
	var _offset = 0
	while _offset < bnk_length:
		var magic = self._read_string(self._file_stream, 4)
		var chunk_size = self._file_stream.get_u32()
		if magic == "BKHD":
			# Read the header chunk.
			self._bkhd_offset = self._file_stream.get_position()
			self._bkhd_size = chunk_size
			self._read_bkhd()
		elif magic == "DIDX":
			# Read the Data index chunk.
			self._didx_offset = self._file_stream.get_position()
			self._didx_size = chunk_size
			self._read_didx()
		elif magic == "DATA":
			# Read the data chunk.
			self._data_offset = self._file_stream.get_position()
			self._data_size = chunk_size
			if preload_data:
				self._read_data()
			# Jump to the end of the data section even if we read it because we may not necessarily
			# read it in order (we'll be reading in the order the didx chunk has the audio ids).
			self._file_stream.seek(self._file_stream.get_position() + self._data_size)
		elif magic == "HIRC":
			# Read the HIRC chunk.
			self._hirc_offset = self._file_stream.get_position()
			self._hirc_size = chunk_size
			self._read_hirc()
		elif magic == "STID":
			# Read the STID chunk.
			self._stid_offset = self._file_stream.get_position()
			self._stid_size = chunk_size
			self._read_stid()
		else:
			# Read some unknown chunk.
			print("Found a chunk with magic: %s" % magic)
			pass
		# Increment the offset and add 8 to include the 8 bytes we read for magic and chunk size.
		_offset += chunk_size + 8


func _read_bkhd():
	# Read the BNK header.
	self.bkhd.version = self._file_stream.get_u32()
	self.bkhd.sound_bank_id = self._file_stream.get_u32()
	# Read the rest of the data into a byte array so we can write it back later.
	self.bkhd.unknown = self._file_stream.get_partial_data(self._bkhd_size - 8)[1]


func _write_bkhd(buffer: StreamPeerBuffer):
	buffer.put_data([0x42, 0x4B, 0x48, 0x44])  # BKHD
	buffer.put_u32(self.bkhd.size())
	buffer.put_u32(self.bkhd.version)
	buffer.put_u32(self.bkhd.sound_bank_id)
	buffer.put_partial_data(self.bkhd.unknown)


func _read_didx():
	# Read the DIDX chunk of the BNK file.
	for i in range(self._didx_size / 0xC):
		# For the number of entries, get the data.
		var audio_id: int = self._file_stream.get_u32()
		# Assign the offset and size of the data to the value of the id_mapping dictionary so that
		# we can easily find and extract data from the data chunk.
		var didx_entry: DIDX_entry = _read_didx_entry()
		self.didx.id_mapping[audio_id] = didx_entry


func _write_didx(buffer: StreamPeerBuffer):
	buffer.put_data([0x44, 0x49, 0x44, 0x58])  # DIDX
	buffer.put_u32(self.didx.size())
	# Get the list of audio ids. Because we can't guarantee that godot will return them in the
	# correct order, manually order them (increasing value)
	var audio_ids = self.didx.id_mapping.keys()
	audio_ids.sort()

	# We need to keep track of the actual location the audio will get written to.
	# WEM files can be any number of bytes, but each will be written to a location with an
	# alignment of 4 relative to the DATA section.
	var offset = 0

	for audio_id in audio_ids:
		var entry: DIDX_entry = self.didx.id_mapping[audio_id]
		buffer.put_u32(audio_id)
		buffer.put_u32(offset)
		buffer.put_u32(entry.file_size)

		# Now, update the offset so that the next file will have the correct offset.
		offset += entry.offset
		offset += 4 - (offset % 4)


func _read_didx_entry() -> DIDX_entry:
	# Read an individual didx entry.
	var didx_entry: DIDX_entry = DIDX_entry.new()
	didx_entry.offset = self._file_stream.get_u32()
	didx_entry.file_size = self._file_stream.get_u32()
	return didx_entry


func _read_data():
	# Read the entire data chunk and chunk it up into individual BytePoolArrays with an associated
	# audio id, for easy lookup.
	for audio_id in self.didx.id_mapping.keys():
		var _wem_data: DIDX_entry = self.didx.id_mapping[audio_id]
		# Jump the filestream to the offset of this and then read the approriate amount of bytes.
		self._file_stream.seek(self._data_offset + _wem_data.offset)
		self.wem_data[audio_id] = self._file_stream.get_partial_data(_wem_data.file_size)[1]


func _write_data(buffer: StreamPeerBuffer):
	buffer.put_data([0x44, 0x41, 0x54, 0x41])
	# Before we write anything, we need to determine if anything has changed. If nothing has then
	# we can just write the entire data chunk from the original bank file by reading the whole
	# chunk from one buffer to another.
	if self.wem_data.size() == 0:
		buffer.put_u32(self._data_size)
		self._file_stream.seek(self._data_offset)
		buffer.put_partial_data(self._file_stream.get_partial_data(self._data_size)[1])
	else:
		print("NOT SUPPORTED YET!")


func _read_hirc():
	self.hirc.object_count = self._file_stream.get_u32()
	for i in range(self.hirc.object_count):
		var entry_type: int = self._file_stream.get_u8()
		var entry_size: int = self._file_stream.get_u32()
		var data: PoolByteArray = self._file_stream.get_partial_data(entry_size)[1]
		var entry_obj
		# TODO: Implement this like a defaultdict in python...
		if entry_type in HIRC_MAPPING.keys():
			entry_obj = HIRC_MAPPING[entry_type].new()
			entry_obj.load(entry_type, data)
		else:
			entry_obj = _HIRC_EVENT_DUMMY.new()
			entry_obj.load(entry_type, data)
		self.hirc.data.append(entry_obj)


func _write_hirc(buffer: StreamPeerBuffer):
	buffer.put_data([0x48, 0x49, 0x52, 0x43])
	# Determine whether the HIRC chunk has any changes. If it doesn't then we just write the entire
	# original chunk.
	if self.modified_hirc_chunks == 0:
		buffer.put_u32(self._hirc_size)
		self._file_stream.seek(self._hirc_offset)
		buffer.put_partial_data(self._file_stream.get_partial_data(self._hirc_size)[1])
	else:
		self.export_subprogress = HIRC_EXPORT_STEPS.PERSIST
		self.hirc.persist_changes()
		buffer.put_u32(self.hirc.size())
		buffer.put_u32(self.hirc.object_count)
		self.export_subprogress = HIRC_EXPORT_STEPS.WRITE
		self.export_progress_hirc = 0
		for obj in self.hirc.data:
			buffer.put_partial_data(obj.byte_pool())
			self.export_progress_hirc += 1
		self.export_subprogress = HIRC_EXPORT_STEPS.NOTHING


func _read_stid():
	self.stid = STID.new()
	self._file_stream.seek(self._stid_offset + 4)		# Skip the 4 bytes that is always 00000001
	self.stid.soundbank_count = self._file_stream.get_u32()
	for i in range(self.stid.soundbank_count):
		var soundbank_id = self._file_stream.get_u32()
		var name_length = self._file_stream.get_u8()
		var soundbank_name = self._read_string(self._file_stream, name_length)
		self.stid.soundbank_data[soundbank_id] = soundbank_name


func _write_stid(buffer: StreamPeerBuffer):
	pass


func _read_string(stream: StreamPeerBuffer, size: int) -> String:
	# Read up to `size` characters from the underlying stream.
	return stream.get_partial_data(size)[1].get_string_from_ascii()


func _get_audio_ids() -> Array:
	if self.didx != null:
		return self.didx.id_mapping.keys()
	return []


func _get_bnk_version() -> int:
	return self.bkhd.version
