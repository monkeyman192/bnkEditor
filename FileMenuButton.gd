extends MenuButton

onready var selectFileDialog = get_node("../../../SelectFileDialog");
var popup;

func _ready():
	popup = get_popup();
	popup.connect("id_pressed", self, "_on_item_pressed");

func _on_item_pressed(ID):
	if ID == 0:
		# Load a folder into the file tree.
		selectFileDialog.window_title = "Load directory into file tree";
		selectFileDialog.current_function = selectFileDialog.FUNCTION.LOAD_FOLDER;
		selectFileDialog.mode = FileDialog.MODE_OPEN_DIR;
		selectFileDialog.show();
