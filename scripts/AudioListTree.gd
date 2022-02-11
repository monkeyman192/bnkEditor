extends Tree

# Icons
const included_audio_texture = preload("res://icons/icon_included.svg")
const referenced_audio_texture = preload("res://icons/icon_ref.svg")
const play_unconverted_texture = preload("res://icons/icon_play.svg")
const play_converted_texture = preload("res://icons/icon_play_green.svg")

const wemFile = preload("res://addons/bnk_handler/WEM.gd")
const bnkXmlParser = preload("res://addons/bnk_handler/META/bnk_xml.gd")
const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

onready var audioController = get_tree().get_root().get_node("main/VBoxContainer/NowPlayingBox")

var audio_tree_data = Dictionary()
var audio_mapping = Dictionary()
var bnk_fullpath: String = ""
var _bnkFile
var root: TreeItem
var program_settings: Dictionary


func _ready():
	self.set_column_titles_visible(true)
	self.set_column_title(0, "File")


func play_wem(file_name: String, wem: WEM):
	audioController.play_audio(file_name, wem)


func deselect_all():
	# Deselect all the currently selected items in the tree.
	var curr_selected = self.get_next_selected(null)
	if curr_selected != null:
		curr_selected.deselect(0)
	while curr_selected:
		curr_selected = self.get_next_selected(curr_selected)
		if curr_selected != null:
			curr_selected.deselect(0)


func select_audio(audio_id: int) -> int:
	# Scroll to and select the audio with the specified id.
	var req_treeItem = audio_mapping.get(audio_id)
	if req_treeItem != null:
		self.deselect_all()
		req_treeItem.select(0)
		req_treeItem.get_parent().collapsed = false
		self.scroll_to_item(req_treeItem)
		return OK
	else:
		return FAILED


func populate_audio_tree(data: Dictionary):
	# Populate the audio tree from the dictionary.
	self.clear()
	root = self.create_item()
	self.set_hide_root(true)
	for key in data:
		# Create the event "folders" to contain multiple audio files.
		var value = data[key]
		var current_child = self.create_item(root)
		current_child.set_text(0, key)
		current_child.collapsed = true
		# Each event has a number of files within it.
		for v in value:
			var sub_child: TreeItem = self.create_item(current_child)
			sub_child.set_text(0, v[0])
			sub_child.set_metadata(0, {"id": v[1], "location": v[2]})
			sub_child.add_button(0, play_unconverted_texture, -1, false, "PLAY")
			if v[2] == bnkXmlParser.AUDIO_TYPE.INCLUDED:
				sub_child.set_icon(0, included_audio_texture)
			else:
				sub_child.set_icon(0, referenced_audio_texture)
			audio_mapping[v[1]] = sub_child


func _on_AudioListTree_button_pressed(item: TreeItem, column: int, id: int):
	if id == 0:
		# Play button has id 0.
		var meta: Dictionary = item.get_metadata(column)
		var audio_id = meta["id"]
		var audio_loc = meta["location"]
		if audio_loc == bnkXmlParser.AUDIO_TYPE.INCLUDED:
			var wem_data: PoolByteArray = _bnkFile.get_wem(int(audio_id))
			var wem = wemFile.new()
			wem.from_bytes(wem_data)
			play_wem("%s.wem" % audio_id, wem)
		elif audio_loc == bnkXmlParser.AUDIO_TYPE.REFERENCED:
			# Load the wem file from disk. Look in the root directory.
			var possible_paths = Utils.filepath_iter(
				program_settings["data_dir"],
				bnk_fullpath.get_base_dir()
			)
			for path in possible_paths:
				var wem_fullpath = path + "/%s.wem" % audio_id
				if File.new().file_exists(wem_fullpath):
					print("loading external file %s" % wem_fullpath)
					var wem = wemFile.new()
					if wem.open(wem_fullpath) == OK:
						print("playing...")
						play_wem(item.get_text(0).get_file(), wem)
				else:
					continue
		else:
			# In this case the event has no associated audio, so do nothing (if we got here
			# somehow...)
			return
