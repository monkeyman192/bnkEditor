extends Node

const bnkXmlParser = preload("res://addons/bnk_handler/META/bnk_xml.gd")
const bnkFile = preload("res://addons/bnk_handler/BNK.gd")

onready var audioTree = $AudioListTree
onready var extractRow = $ExtractRow
onready var convertToOggToggle = $ExtractRow/ConvertToOggToggle
onready var main = get_tree().get_root().get_node("main")
onready var filterCountLabel = $FilterByRow/filterCountLabel
onready var filterField = $FilterByRow/filterField
onready var exportProgressBar = get_node("../../HBoxContainer/ExportProgressBar")
onready var exportProgressLabel = get_node("../../HBoxContainer/ExportProgressLabel")

var current_export_progress: int = 0

# The text of the currently selected filtered row.
var curr_selected_filtered_row_text: String
const export_mapping: Dictionary = {
	bnkFile.EXPORT_STEPS.NOTHING: "",
	bnkFile.EXPORT_STEPS.BKHD: "Writing BKHD section",
	bnkFile.EXPORT_STEPS.DIDX: "Writing DIDX section",
	bnkFile.EXPORT_STEPS.DATA: "Writing DATA section",
	bnkFile.EXPORT_STEPS.HIRC: "Writing HIRC section",
	bnkFile.EXPORT_STEPS.STID: "Writing STID section",
	bnkFile.EXPORT_STEPS.TO_FILE: "Writing to disk",
	bnkFile.EXPORT_STEPS.COMPLETE: "Complete",
}

func set_filter_count():
	# Set the label in the filter count based on how many elements match.
	var count = audioTree.filtered_count
	var total = audioTree.total_count
	filterCountLabel.text = "(%s/%s)" % [count, total]


func _on_filterField_text_changed(new_text):
	# This is called when the text in the filter field is changed.
	# When this happens we want to see if any of the items in the tree contain the filter text.
	# First, lower the string we want to check so that we don't need to do it for every check.
	var check_text: String = new_text.to_lower()
	if check_text == '':
		# In the case of an empty filter, consider this no filter and show the total count.
		audioTree.filtered_count = audioTree.total_count
		self.set_filter_count()
		for val in audioTree.audio_text_data.values():
			val.clear_custom_color(0)
		return
	# If we have a non-empty filter, then actually find out the objects to filter.
	var filtered_count: int = 0
	for key in audioTree.audio_text_data.keys():
		if check_text in key:
			# Add 1 to the filtered count for when we need to update the list.
			filtered_count += 1
			audioTree.audio_text_data[key].set_custom_color(0, Color.green)
		else:
			audioTree.audio_text_data[key].clear_custom_color(0)
	audioTree.filtered_count = filtered_count
	self.set_filter_count()


func _on_filterField_text_entered(_new_text):
	if audioTree.filtered_count == 0 || filterField.text == "":
		# If there are no values, or an empty filter, do nothing.
		return
	audioTree.go_to_next_filtered()


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


func _on_ExportBNKButton_pressed():
	if not main.thread.is_alive():
		main.thread.wait_to_finish()
		main.thread = Thread.new()
		main.thread.start(audioTree._bnkFile, "write", audioTree.bnk_fullpath + ".MODIFIED")
	#audioTree._bnkFile.write(audioTree.bnk_fullpath + ".MODIFIED")


func _process(_delta):
	if audioTree._bnkFile == null:
		# If there is no loaded bnk file, then we do nothing.
		return
	# If we have the file count changing, set the max value of the progress bar and reset its value
	var bnk_progress = audioTree._bnkFile.export_progress
	if (bnk_progress != self.current_export_progress) || (audioTree._bnkFile.export_progress == bnkFile.EXPORT_STEPS.HIRC):
		# Update the label and progress bar.
		exportProgressLabel.text = "%s" % export_mapping[bnk_progress]
		if audioTree._bnkFile.export_progress == bnkFile.EXPORT_STEPS.HIRC:
			if audioTree._bnkFile.export_subprogress != bnkFile.HIRC_EXPORT_STEPS.NOTHING:
				exportProgressLabel.text = "%s" % export_mapping[bnk_progress] + " (%s / %s)" % [
					audioTree._bnkFile.export_progress_hirc,
					audioTree._bnkFile.hirc.object_count
				]
		exportProgressBar.value = bnk_progress
		# Update the prev variables so that we will see things getting updated progressively.
		self.current_export_progress = bnk_progress


func _on_nextButton_pressed():
	# Select the next filtered result.
	if audioTree.filtered_count == 0 || filterField.text == "":
		# If there are no values, or an empty filter, do nothing.
		return
	audioTree.go_to_next_filtered()


func _on_prevButton_pressed():
	# Select the previous filtered result.
	if audioTree.filtered_count == 0 || filterField.text == "":
		# If there are no values, or an empty filter, do nothing.
		return
	audioTree.go_to_prev_filtered()
