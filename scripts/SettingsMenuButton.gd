extends MenuButton

onready var selectFileDialog = get_node("../../../SelectFileDialog")
var popup

func _ready():
	popup = get_popup()
	popup.connect("id_pressed", self, "_on_item_pressed")

func _on_item_pressed(ID):
	if ID == 0:
		# Select a folder for data export.
		selectFileDialog.window_title = "Select export folder"
		selectFileDialog.current_function = selectFileDialog.FUNCTION.SELECT_EXPORT_FOLDER
		selectFileDialog.mode = FileDialog.MODE_OPEN_DIR
		selectFileDialog.show()
