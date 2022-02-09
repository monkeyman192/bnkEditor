extends Node


onready var audioTree = $AudioListTree

var _bnkFile
var export_path: String = ""


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
	print(new_text)


func _on_AllExtractButton_pressed():
	_bnkFile.extract_all(export_path)


func _on_SelectedExtractButton_pressed():
	# Extract all the selected data.
	# If a leaf is selected that isn't an audio file, then all the child rows under it will be
	# extracted.
	var selected_node: TreeItem = audioTree.get_next_selected(null)
	var selected_items: Array = []
	var selected_ids: PoolIntArray = []

	while selected_node:
		selected_items.append(selected_node)
		selected_node = audioTree.get_next_selected(selected_node)
	for item in selected_items:
		var meta = item.get_metadata(0)
		if meta != null:
			selected_ids.append(meta)
	print(selected_ids)
	print(export_path)
	for id in selected_ids:
		_bnkFile.extract_single(id, export_path)
