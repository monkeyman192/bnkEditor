extends Tree

# Icons
const included_audio_texture = preload("res://icons/icon_included.svg")
const referenced_audio_texture = preload("res://icons/icon_ref.svg")
const play_unconverted_texture = preload("res://icons/icon_play.svg")
const play_converted_texture = preload("res://icons/icon_play_green.svg")
const edit_texture = preload("res://icons/icon_edit.svg")
const reload_texture = preload("res://icons/icon_reload.svg")

const wemFile = preload("res://addons/bnk_handler/WEM.gd")
const bnkXmlParser = preload("res://addons/bnk_handler/META/bnk_xml.gd")
const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

onready var audioController = get_tree().get_root().get_node("main/VBoxContainer/NowPlayingBox")
onready var extractionRow = get_node("../ExtractRow")
onready var HIRCTree = get_node("../../HIRCExplorer")
onready var BNKTabs = get_node("../..")
onready var selectFileDialog = get_tree().get_root().get_node("main/SelectFileDialog")

enum EXTRACTION_MODE {SELECTED, ALL}
enum BUTTON_ENUM {PLAY, REPLACE, RELOAD}

var audio_text_data: Dictionary = {}
var audio_mapping: Dictionary = {}
var bnk_fullpath: String = ""
var _bnkFile
var root: TreeItem
var program_settings: Dictionary
var total_count: int = 0
var filtered_count: int = 0
var current_replacing_wem


func _ready():
	self.set_column_titles_visible(true)
	self.set_column_title(0, "File")


func play_wem(file_name: String, wem: WEM):
	audioController.play_audio(file_name, wem)


func _extract_all(to_ogg: bool = false):
	self.extract(EXTRACTION_MODE.ALL, to_ogg)


func _extract_selected(to_ogg: bool = false):
	self.extract(EXTRACTION_MODE.SELECTED, to_ogg)


func update_metadata(item: TreeItem, column: int, meta: Dictionary):
	# Update the current meta dictionary with the provided one, in the same way that python
	# provides an `update` method on dictionaries.
	var curr_meta = item.get_metadata(column)
	for key in meta:
		curr_meta[key] = meta[key]


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


func get_next_row(after: TreeItem, loop: bool = true) -> TreeItem:
	# Return the next item in the tree including parent items etc.
	# If the item has children, then we should return the first one.
	var child = after.get_children()
	if child:
		return child
	# If no children, then see if there is a next item and return this.
	var next = after.get_next()
	if next:
		return next
	# If no next one then we may be at the bottom of a set of children nodes. Get the parent and
	# then get the next.
	var parent = after.get_parent()
	if parent:
		next = parent.get_next()
		if next:
			return next
		else:
			# In this case I think we have probably hit the bottom. If we want to loop back to the
			# top, do so.
			if loop:
				return self.get_root().get_children()
	return null


func _get_last_child(node: TreeItem) -> TreeItem:
	# Return the last child node of the given node.
	var child = node.get_children()
	while child:
		var _child = child.get_next()
		# Check to see if the next child is null or not. If it isn't then we want to continue.
		# If it is null, then we return the last non-null child.
		if not _child:
			return child
		child = _child
	return null


func get_prev_row(before: TreeItem, loop: bool = true) -> TreeItem:
	# Return the next item in the tree including parent items etc.
	# If the item has children, then we should return the first one.
	var prev = before.get_prev()
	if prev:
		# If the prev value has children, then we need to go through the children and find the last
		# one.
		if prev.get_children() != null:
			return self._get_last_child(prev)
		else:
			return prev
	# If there is no previous one we are either at the start of a child node set, or a the very
	# start of the tree.
	var parent = before.get_parent()
	if parent && parent != self.get_root():
		# In this case, `before` was the first element of a child, so return the parent.
		return parent
	else:
		# In this case we are at the very first row of the tree.
		if loop:
			var last = self._get_last_child(self.get_root())
			if last.get_children() != null:
				return self._get_last_child(last)
			else:
				return last
	return null


func go_to_next_filtered():
	var curr_selected = self.get_selected()
	if curr_selected == null:
		# If nothing is selected, then select the first child of the root and then move forward to
		# find the first selected object.
		curr_selected = self.get_root().get_children()
	var next = self.get_next_row(curr_selected)
	# We can "safely" have an endless loop like this because we know that there must be another
	# row which is green because the option of there being 0 or 1 rows has already been covered
	while next.get_custom_color(0) != Color.green:
		next = self.get_next_row(next)
	# Once have the next one, deselect the old one, scroll to the next one then select it.
	curr_selected.deselect(0)
	next.select(0)
	var next_parent = next.get_parent()
	if next_parent && next_parent != self.get_root():
		next_parent.collapsed = false
	self.scroll_to_item(next)


func go_to_prev_filtered():
	var curr_selected = self.get_selected()
	if curr_selected == null:
		curr_selected = self.get_root().get_children()
	var prev = self.get_prev_row(curr_selected)
	# We can "safely" have an endless loop like this because we know that there must be another
	# row which is green because the option of there being 0 or 1 rows has already been covered
	while prev.get_custom_color(0) != Color.green:
		prev = self.get_prev_row(prev)
	curr_selected.deselect(0)
	prev.select(0)
	var prev_parent = prev.get_parent()
	if prev_parent && prev_parent != self.get_root():
		prev_parent.collapsed = false
	self.scroll_to_item(prev)


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
	var req_treeItem = self.audio_mapping.get(audio_id)
	if req_treeItem != null:
		self.deselect_all()
		req_treeItem.select(0)
		req_treeItem.get_parent().collapsed = false
		self.scroll_to_item(req_treeItem)
		return OK
	else:
		return FAILED


func replace_audio(path: String):
	# Replace the current replacing wem with the given path.
	if current_replacing_wem:
		var f = File.new()
		var wem_data: PoolByteArray
		var wem_length: int
		var err: int = f.open(path, f.READ)
		if err != OK:
			print("There was an error: %s" % err)
			return err
		wem_length = f.get_len()
		wem_data = f.get_buffer(wem_length)
		f.close()
		# First, replace the wem in the bnk file
		var replacing_audio_id: int = int(current_replacing_wem.get_metadata(0)["audio_id"])
		self._bnkFile.modify_wem(replacing_audio_id, wem_data)
		# Then, get the associated SFX HIRC chunk and update the file length.
		var associated_SFX = HIRCTree.audio_mapping.get(replacing_audio_id)
		var hirc_obj = associated_SFX.get_metadata(0)["_data"]
		hirc_obj.change_count += 1
		hirc_obj.audio_size.value = wem_length
		# Get the 3rd child of the TreeItem
		var child = associated_SFX.get_children()
		child.get_next().get_next().set_text(1, "%s bytes" % wem_length)
		self._bnkFile.modified_hirc_chunks += 1
		var orig_text = current_replacing_wem.get_text(0).split(" -> ")[0]
		current_replacing_wem.set_text(0, "%s -> %s" % [orig_text, path])
		current_replacing_wem.add_button(0, reload_texture, BUTTON_ENUM.RELOAD, false, "Revert to original")


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
		self.audio_text_data[key.to_lower()] = current_child
		current_child.collapsed = true
		self.total_count += 1
		# Each event has a number of files within it.
		for v in value:
			var sub_child: TreeItem = self.create_item(current_child)
			sub_child.set_text(0, v[0])
			sub_child.set_metadata(0, {"audio_id": v[1], "location": v[2]})
			sub_child.add_button(0, play_unconverted_texture, BUTTON_ENUM.PLAY, false, "Play")
			sub_child.add_button(0, edit_texture, BUTTON_ENUM.REPLACE, false, "Replace")
			if v[2] == bnkXmlParser.AUDIO_TYPE.INCLUDED:
				sub_child.set_icon(0, included_audio_texture)
				sub_child.set_tooltip(0, "ID: %s (Embedded)" % v[1])
			else:
				sub_child.set_icon(0, referenced_audio_texture)
				sub_child.set_tooltip(0, "ID: %s (Referenced)" % v[1])
			self.audio_mapping[v[1]] = sub_child
			self.audio_text_data[v[0].to_lower()] = sub_child
			self.total_count += 1


func _on_AudioListTree_button_pressed(item: TreeItem, column: int, id: int):
	if id == BUTTON_ENUM.PLAY:
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
	elif id == BUTTON_ENUM.REPLACE:
		# Assign the item as the current replacing wem line.
		current_replacing_wem = item
		selectFileDialog.window_title = "Select a wem to replace"
		selectFileDialog.current_function = selectFileDialog.FUNCTION.SELECT_WEM
		selectFileDialog.mode = FileDialog.MODE_OPEN_FILE
		selectFileDialog.set_filters(PoolStringArray(["*.wem ; WEM files"]))
		selectFileDialog.show()
	elif id == BUTTON_ENUM.RELOAD:
		current_replacing_wem.erase_button(1, BUTTON_ENUM.RELOAD)
		var orig_text = current_replacing_wem.get_text(0).split(" -> ")[0]
		current_replacing_wem.set_text(0, orig_text)
		self._bnkFile.remove_modified_wem(int(current_replacing_wem.get_metadata(0)["audio_id"]))

		# Reset the changes to the byte size in the associated SFX
		var replacing_audio_id: int = int(current_replacing_wem.get_metadata(0)["audio_id"])
		# Then, get the associated SFX HIRC chunk and update the file length.
		var associated_SFX = HIRCTree.audio_mapping.get(replacing_audio_id)
		var hirc_obj = associated_SFX.get_metadata(0)["_data"]
		hirc_obj.change_count -= 1
		hirc_obj.audio_size.reset()
		# Get the 3rd child of the TreeItem
		var child = associated_SFX.get_children()
		child.get_next().get_next().set_text(1, "%s bytes" % hirc_obj.audio_size.value)
		self._bnkFile.modified_hirc_chunks -= 1


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
