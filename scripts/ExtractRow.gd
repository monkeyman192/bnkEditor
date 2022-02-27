extends HBoxContainer

onready var SelectedExtractButton = $SelectedExtractButton
onready var AllExtractButton = $AllExtractButton
onready var ExtractionProgressLabel = $ExtractionProgressLabel
onready var ExtractionProgressBar = $ExtractionProgressBar
onready var CancelButton = $CancelButton

var file_count: int = 0
var prev_file_count: int = 0
var curr_processing_file: int = 0
var prev_processing_file: int = 0
enum STATE {READY, EXTRACTING, CANCELLED, DONE}
var extraction_state = STATE.READY setget _set_state


func _process(_delta):
	# If we have the file count changing, set the max value of the progress bar and reset its value
	if self.file_count != self.prev_file_count:
		ExtractionProgressBar.max_value = self.file_count
		ExtractionProgressBar.value = 0
	if (self.file_count != self.prev_file_count) || (self.curr_processing_file != self.prev_processing_file):
		# Update the label.
		ExtractionProgressLabel.text = "%s/%s files" % [self.curr_processing_file, self.file_count]
		ExtractionProgressBar.value = self.curr_processing_file
		# Also update the progress bar.
		# Update the prev variables so that we will see things getting updated progressively.
		self.prev_file_count = self.file_count
		self.prev_processing_file = self.curr_processing_file


func _set_state(value):
	extraction_state = value
	if self.extraction_state == STATE.EXTRACTING:
		SelectedExtractButton.disabled = true
		AllExtractButton.disabled = true
		CancelButton.visible = true
	else:
		SelectedExtractButton.disabled = false
		AllExtractButton.disabled = false
		CancelButton.visible = false


func reset():
	# Reset the variables used to their defaults.
	self.file_count = 0
	self.prev_file_count = -1
	self.curr_processing_file = 0
	self.prev_processing_file = -1
	ExtractionProgressBar.value = 0
	ExtractionProgressBar.max_value = 1


func _on_CancelButton_pressed():
	self.extraction_state = STATE.CANCELLED
