extends Node

class_name BNK_XML_Parser

# Parse a <soundbank name>.xml file.
# This will get called when we load a .BNK and find an .xml file with the same base name.

var parser: XMLParser = XMLParser.new()

enum AUDIO_TYPE {REFERENCED, INCLUDED}

func parse_bnk_xml(filepath: String) -> Dictionary:
	var audio_tree_data = Dictionary()
	# Parse the xml file associated with a bnk to get the streamed and included
	# wem files.
	self.parser.open(filepath)
	var _file_subtree = null
	var _in_shortname: bool = false
	var _in_event: bool = false
	var event_name = null
	var current_id = null
	var audio_type = -1
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == parser.NODE_ELEMENT:
			if parser.get_node_name() == "Event":
				_in_event = true
				event_name = parser.get_named_attribute_value_safe("Name")
				audio_tree_data[event_name] = []
			if parser.get_node_name() == "Path":
				_in_shortname = true
			if _in_event:
				if parser.get_node_name() == "File":
					current_id = int(parser.get_named_attribute_value_safe("Id"))
				elif parser.get_node_name() == "ReferencedStreamedFiles":
					audio_type = AUDIO_TYPE.REFERENCED
				elif parser.get_node_name() == "IncludedEvents":
					audio_type = AUDIO_TYPE.INCLUDED
			else:
				current_id = null
				audio_type = -1
		if parser.get_node_type() == parser.NODE_ELEMENT_END:
			if parser.get_node_name() == "Event":
				_in_event = false
		if parser.get_node_type() == parser.NODE_TEXT:
			if _in_shortname and _in_event:
				var fpath: String = parser.get_node_data()
				if fpath.strip_edges() != '':
					audio_tree_data[event_name].append([fpath, current_id, audio_type])
				_in_shortname = false
	return audio_tree_data
