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
onready var extractionRow = get_node("../ExtractRow")
onready var HIRCTree = get_node("../../HIRCExplorer")
onready var BNKTabs = get_node("../..")

enum EXTRACTION_MODE {SELECTED, ALL}

var audio_tree_data: Dictionary = {}
var audio_mapping: Dictionary = {}
var bnk_fullpath: String = ""
var _bnkFile
var root: TreeItem
var program_settings: Dictionary


func _ready():
	self.set_column_titles_visible(true)
	self.set_column_title(0, "File")


func play_wem(file_name: String, wem: WEM):
	audioController.play_audio(file_name, wem)


func _extract_all(to_ogg: bool = false):
	self.extract(EXTRACTION_MODE.ALL, to_ogg)


func _extract_selected(to_ogg: bool = false):
	self.extract(EXTRACTION_MODE.SELECTED, to_ogg)


func extract(method: int = EXTRACTION_MODE.SELECTED, to_ogg: bool = false):
	# Extract the selected audios.
	var selected_audio_data: Dictionary = self.get_contained_audio(method)
	extractionRow.file_count = (
		selected_audio_data[bnkXmlParser.AUDIO_TYPE.INCLUDED].size()
		+ selected_audio_data[bnkXmlParser.AUDIO_TYPE.REFERENCED].size()
	)
	var export_path: String = self.program_settings["export_path"]

	# For the included audios, we extract them from within the bnk.
	for audio_id in selected_audio_data[bnkXmlParser.AUDIO_TYPE.INCLUDED]:
		if extractionRow.extraction_state == extractionRow.STATE.CANCELLED:
			# Check to see if the extraction row has been cancelled.
			break
		self._bnkFile.export_wem(audio_id, export_path, to_ogg)
		extractionRow.curr_processing_file += 1

	# For the referenced ones, we'll simply copy them over (or convert if exporting to ogg.)
	for audio_id in selected_audio_data[bnkXmlParser.AUDIO_TYPE.REFERENCED]:
		if extractionRow.extraction_state == extractionRow.STATE.CANCELLED:
			# Check to see if the extraction row has been cancelled.
			break
		var wem_fullpath: String = self.get_audio_path(audio_id)
		if wem_fullpath != "":
			var output_path: String = export_path + "/%s" % audio_id
			if to_ogg:
				# If converting, then we will load the wem from disk and write to ogg in the export
				# folder.
				var wem = wemFile.new()
				if wem.open(wem_fullpath) == OK:
					wem.export_to_ogg(output_path + ".ogg")
			else:
				# Otherwise, simply copy the file over.
				var dir: Directory = Directory.new()
				if dir.copy(wem_fullpath, output_path + ".wem") != OK:
					print("Failed to copy the file")
		extractionRow.curr_processing_file += 1
	# Once extraction has completed, set the value in the ExtractRow to allow things to be selected
	# again.
	extractionRow.extraction_state = extractionRow.STATE.DONE


func get_all_children(parent: TreeItem) -> Array:
	var child = parent.get_children()
	var children: Array = []
	while child:
		children.append(child)
		child = child.get_next()
	return children


func get_contained_audio(method: int) -> Dictionary:
	# Get all the audio ids contained in the tree.
	# If `method` = EXTRACTION_MODE.SELECTED, then we will only get the selected audio ids,
	# otherwise get all of them.
	# We'll need to split this up into a list of included and embedded audio files, as they need to
	# be handled differently.
	var data: Dictionary = {
		bnkXmlParser.AUDIO_TYPE.INCLUDED: [],
		bnkXmlParser.AUDIO_TYPE.REFERENCED: [],
	}

	var curr_selected
	# Loop over the selected objects and sort them based on location.
	if method == EXTRACTION_MODE.SELECTED:
		curr_selected = self.get_next_selected(null)
	else:
		curr_selected = self.root.get_children()
	var meta
	var audio_id
	var audio_loc
	while curr_selected:
		meta = curr_selected.get_metadata(0)
		if meta == null:
			# If there is no associated meta, then we have selected a group.
			var children = self.get_all_children(curr_selected)
			for child in children:
				meta = child.get_metadata(0)
				audio_id = meta["audio_id"]
				audio_loc = meta["location"]
				if not audio_id in data[audio_loc]:
					data[audio_loc].append(audio_id)
			curr_selected = self.get_next_selected(curr_selected)
			continue
		audio_id = meta["audio_id"]
		audio_loc = meta["location"]
		if not audio_id in data[audio_loc]:
			data[audio_loc].append(audio_id)
		if method == EXTRACTION_MODE.SELECTED:
			curr_selected = self.get_next_selected(curr_selected)
		else:
			curr_selected = self.root.get_next()
	return data


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
			sub_child.set_tooltip(0, "ID: %s" % v[1])
			sub_child.set_metadata(0, {"audio_id": v[1], "location": v[2]})
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
		var audio_id = meta["audio_id"]
		var audio_loc = meta["location"]
		if audio_loc == bnkXmlParser.AUDIO_TYPE.INCLUDED:
			var wem_data: PoolByteArray = self._bnkFile.get_wem(int(audio_id))
			var wem = wemFile.new()
			wem.from_bytes(wem_data)
			play_wem("%s.wem" % audio_id, wem)
		elif audio_loc == bnkXmlParser.AUDIO_TYPE.REFERENCED:
			# Load the wem file from disk. Look in the root directory.
			var wem_fullpath = self.get_audio_path(audio_id)
			if wem_fullpath != "":
				var wem = wemFile.new()
				if wem.open(wem_fullpath) == OK:
					play_wem(item.get_text(0).get_file(), wem)
		else:
			# In this case the event has no associated audio, so do nothing (if we got here
			# somehow...)
			return


func get_audio_path(audio_id: int) -> String:
	# Get the full path to the audio file from the provided audio ID.
	# This will search through the possible paths we could expect the audio to be and return the
	# first path it is found to exist at.
	var possible_paths = Utils.filepath_iter(
				self.program_settings["data_dir"],
				self.bnk_fullpath.get_base_dir()
			)
	for path in possible_paths:
		var wem_fullpath: String = path + "/%s.wem" % audio_id
		if File.new().file_exists(wem_fullpath):
			return wem_fullpath
	# If we got here and the audio file wasn't found, then return an empty string.
	return ""


func _on_AudioListTree_item_activated():
	# When we double click on an item, if we can find an associated sound sfx swap to it.
	var selected_item: TreeItem = self.get_selected()
	var meta = selected_item.get_metadata(0)
	if meta != null:
		var audio_id = meta.get("audio_id")
		if audio_id != null:
			if audio_id in HIRCTree.audio_mapping:
				BNKTabs.change_tab("hirc")
				HIRCTree.select_sfx(audio_id)
