extends BitWiseStreamPeerBuffer

class_name OGG

func write_vorbis_header(packet_type: int):
	# Write the common vorbis header format.
	# This will be the packet_type:
	# 1: Identification
	# 3: Comment
	# 5: Setup
	# Note. The headers MUST be written in this order.
	# A packet_type of 0 indiciates an audio packet.
	self.put_u8(packet_type)
	self.put_data("vorbis".to_wchar())


func write_id_header():
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
	self.put_u32(0)
	pass
