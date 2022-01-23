extends FileDialog

onready var main = get_node('..');

enum FUNCTION {NONE, LOAD_FOLDER, SELECT_EXPORT_FOLDER, SELECT_WW2OGG};
var current_function = FUNCTION.NONE;


func _init():
	# Set the access as the local file system.
	access = ACCESS_FILESYSTEM;


func _on_SelectFileDialog_dir_selected(dir):
	# If we are selecting a directory, branch depending on what mode we are in.
	match current_function:
		FUNCTION.LOAD_FOLDER:
			# In this function state, we are loading a folder into the file tree.
			main.program_settings["data_dir"] = dir;
			main.load_current_directory();
		FUNCTION.SELECT_EXPORT_FOLDER:
			print("Setting the export path as: ", dir);
			main.program_settings["export_path"] = dir;
	# Finally, write the settings file.
	main.write_settings();


func _on_SelectFileDialog_file_selected(path):
	# If we are selecting a file, branch depending on what mode we are in.
	match current_function:
		FUNCTION.SELECT_WW2OGG:
			main.program_settings["ww2ogg_path"] = path;
	# Finally, write the settings file.
	main.write_settings();
