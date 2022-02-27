extends Node

const bnkFile = preload("res://addons/bnk_handler/BNK.gd")
const bnkXmlParser = preload("res://addons/bnk_handler/META/bnk_xml.gd")

onready var audioTree = $AudioListTree
onready var extractRow = $ExtractRow
onready var convertToOggToggle = $ExtractRow/ConvertToOggToggle
onready var main = get_tree().get_root().get_node("main")


func filter_audio_list(audio_tree_data: Dictionary, filter: String = "") -> Dictionary:
	# Take a filter string and return just the elements in the audio tree data which match.
	var filtered = Dictionary()
	if filter == "":
		return audio_tree_data
	for key in audio_tree_data:
		var temp_array = []
		for v in audio_tree_data[key]:
			if filter in v[0].to_lower():
				temp_array.append(v)
		if temp_array.size() != 0 or filter in key.to_lower():
			filtered[key] = temp_array
	return filtered


func _on_filterField_text_entered(new_text):
	# Then create a new filtered list.
	var filtered_results = filter_audio_list(audioTree.audio_tree_data, new_text)
	# Then redraw the tree.
	audioTree.populate_audio_tree(filtered_results)


func _on_AllExtractButton_pressed():
	if not main.thread.is_alive():
		# If the main thread isn't in use any more, we'll overwrite it and get something else going
		# This is kind of like faking a thread pool with a single thread.
		main.thread.wait_to_finish()
		main.thread = Thread.new()
		extractRow.extraction_state = extractRow.STATE.EXTRACTING
		extractRow.reset()
		main.thread.start(audioTree, "_extract_all", convertToOggToggle.pressed)


func _on_SelectedExtractButton_pressed():
	# Extract all the selected data.
	# If a leaf is selected that isn't an audio file, then all the child rows under it will be
	# extracted.
	if not main.thread.is_alive():
		# If the main thread isn't in use any more, we'll overwrite it and get something else going
		# This is kind of like faking a thread pool with a single thread.
		main.thread.wait_to_finish()
		main.thread = Thread.new()
		extractRow.extraction_state = extractRow.STATE.EXTRACTING
		extractRow.reset()
		main.thread.start(audioTree, "_extract_selected", convertToOggToggle.pressed)
