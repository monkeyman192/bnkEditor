extends Control

onready var tabContainer = $VBoxContainer/TabContainer;
onready var tree = $VBoxContainer/TabContainer/AudioListBox/AudioListTree;
onready var itemlist = $VBoxContainer/TabContainer/FileList;
onready var audioPlayer = $AudioStreamPlayer;
onready var filterField = $VBoxContainer/TabContainer/AudioListBox/FilterByRow/filterField;
onready var fileLabel = $VBoxContainer/TabContainer/AudioListBox/FileSelectRow;
var parser = XMLParser.new();
var bnkFile: BNKCompiler = null;

# Preload popup scenes.
var ProgressPopup = preload("res://ProgressPopup.tscn");

# Icon variables;
var play_unconverted_texture = preload("res://icons/icon_play.svg");
var play_converted_texture = preload("res://icons/icon_play_green.svg");
var bnk_load_texture = preload("res://icons/icon_load.svg");

# Some global variables
var audio_tree_data = Dictionary();
var curr_loaded_bnk: String = "";

# Some paths to keep track of where things go.
const AUDIO_PERSISTENT = "NMS_AUDIO_PERSISTENT.XML";
# Save user settings
const SETTINGS_FILE = "user://settings/settings.json";
const PCB = "packed_codebooks_aoTuV_603.bin";


# Dictionary to keep track of all the settings. This will be written when a setting is changed,
# and loaded when the program is opened.
var program_settings = {
	"export_path": "",
	"ww2ogg_path": "",
	"data_dir": ""
};


func load_settings():
	# Load the program settings file.
	var settings_dir = Directory.new();
	var settings_file = File.new();
	# Check to see if the settings directory exists. If not. Make it.
	if not settings_dir.dir_exists(SETTINGS_FILE.get_base_dir()):
		var err = settings_dir.make_dir(SETTINGS_FILE.get_base_dir());
		if err != OK:
			print("Cannot create a directory :(");
	if not settings_file.file_exists(SETTINGS_FILE):
		settings_file.open(SETTINGS_FILE, File.WRITE);
		settings_file.store_string(JSON.print(program_settings));
		settings_file.close();
	else:
		settings_file.open(SETTINGS_FILE, File.READ);
		var json_parsed := JSON.parse(settings_file.get_as_text());
		if json_parsed.error != OK:
			print("Error: %s" % json_parsed.error_string);
		else:
			program_settings = json_parsed.result;


func write_settings():
	# Write the current settings to a file.
	var settings_dir = Directory.new();
	var settings_file = File.new();
	# Check to see if the settings directory exists. If not. Make it.
	if not settings_dir.dir_exists(SETTINGS_FILE.get_base_dir()):
		var err = settings_dir.make_dir(SETTINGS_FILE.get_base_dir());
		if err != OK:
			print("Cannot create a directory :(");
	print("Writing settings to %s" % SETTINGS_FILE)
	settings_file.open(SETTINGS_FILE, File.WRITE);
	var settings_string = JSON.print(program_settings)
	settings_file.store_string(settings_string);
	settings_file.close();


func play_ogg(path: String):
	# Take the path to an .ogg file and play it once.
	var file := File.new();
	file.open(path, File.READ);
	# TODO: read in chunks.
	var ogg_data = file.get_buffer(file.get_len());
	var audio_stream := AudioStreamOGGVorbis.new();
	audio_stream.data = ogg_data;
	audioPlayer.stream = audio_stream;
	audioPlayer.play();


func extract_wem():
	pass;


func convert_wem_to_ogg(path: String) -> String:
	# Convert a .wem to a .ogg.
	# If this process works correctly, return the path to the produced .ogg file.
	# If it fails it will return an empty path.
	print(path);
	var output = []
	if program_settings["export_path"] == "":
		print("Export path required!");
		return "";
	var out_path = program_settings["export_path"] + "/" + path.get_file().get_basename() + ".ogg";
	var pcb_path = program_settings["ww2ogg_path"].get_base_dir() + "/" + PCB;
	# TODO: Check that export_path exists.
	OS.execute(
		program_settings["ww2ogg_path"],
		[path, "-o", out_path, "--pcb", pcb_path],
		true,
		output
	);
	print(output);
	return out_path;
	# If something goes wrong, return an empty path.


func is_wem_extracted(filename: String, bnk_name: String) -> bool:
	# Determine whether the specified filename has been extracted from a .bnk file.
	return true;


func is_wem_converted(filename: String) -> String:
	# Determine whether the specified filename has been converted from .wem to .ogg.
	# If so, return the file path so that we don't need to search for it again, and can play it
	# directly.
	var converted_fname = filename.get_file().get_basename() + ".ogg";
	var converted_fpath = program_settings["export_path"] + "/" + converted_fname;
	if Directory.new().file_exists(converted_fpath):
		return converted_fpath;
	else:
		return ""


func load_current_directory():
	# Load the currently selected directory into the file tree.
	if program_settings["data_dir"] == "":
		# Do an initial check to see if we have an empty directory or not.
		return;
	var dir = Directory.new();
	# Also check and see if the directory even exists. If not. Load nothing also.
	if not dir.dir_exists(program_settings["data_dir"]):
		return;
	dir.open(program_settings["data_dir"]);
	dir.list_dir_begin();
	itemlist.clear();
	var curr_idx := 0;
	# Go over the files in the folder.
	while true:
		var file = dir.get_next();
		if file == "":
			break;
		# Only list ones which are .bnks.
		elif not file.begins_with("."):
			if file.to_lower().ends_with(".bnk"):
				# Add bnk's with the load icon.
				itemlist.add_item(file, bnk_load_texture, true);
				itemlist.set_item_tooltip(curr_idx, "Load %s in other view" % file);
			elif file.to_lower().ends_with(".wem"):
				# Add wem's with a play icon.
				# If the wem has been converted already, then make the play icon green to indicate
				# this.
				var wem_ogg_path = is_wem_converted(file);
				if wem_ogg_path != "":
					itemlist.add_item(file, play_converted_texture, true);
					itemlist.set_item_tooltip(curr_idx, "Play %s" % file);
					itemlist.set_item_metadata(curr_idx, {"extracted_path": wem_ogg_path});
				else:
					itemlist.add_item(file, play_unconverted_texture, true);
					itemlist.set_item_tooltip(curr_idx, "Convert and play %s" % file);
					itemlist.set_item_metadata(curr_idx, {"extracted_path": ""});
			else:
				continue
			curr_idx += 1;
	dir.list_dir_end();
	# Change the tab to the file list.
	tabContainer.current_tab = 1;


func parse_xml():
	var _err = parser.open("res://data/test.xml");
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == parser.NODE_ELEMENT:
			if parser.get_node_name() != '':
				print(parser.get_node_name(), " ", parser.get_named_attribute_value_safe("name"));
				for i in range(parser.get_attribute_count()):
					print(parser.get_attribute_name(i), ": ", parser.get_attribute_value(i));


func parse_bnk_xml(filepath: String):
	# Parse the xml file associated with a bnk to get the streamed and included
	# wem files.
	parser.open(filepath);
	var file_subtree = null;
	var _in_shortname := false;
	var _in_event := false;
	var event_name = null;
	var current_id = null;
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == parser.NODE_ELEMENT:
			if parser.get_node_name() == "Event":
				_in_event = true;
				event_name = parser.get_named_attribute_value_safe("Name");
				audio_tree_data[event_name] = []
			if parser.get_node_name() == "Path":
				_in_shortname = true;
			if _in_event:
				if parser.get_node_name() == "File":
					current_id = parser.get_named_attribute_value_safe("Id");
			else:
				current_id = null;
		if parser.get_node_type() == parser.NODE_ELEMENT_END:
			if parser.get_node_name() == "Event":
				_in_event = false;
		if parser.get_node_type() == parser.NODE_TEXT:
			if _in_shortname and _in_event:
				var fpath: String = parser.get_node_data();
				if fpath.strip_edges() != '':
					audio_tree_data[event_name].append([fpath, current_id]);
				_in_shortname = false;


func filter_audio_list(filter: String = "") -> Dictionary:
	# Take a filter string and return just the elements in the audio tree data which match.
	var filtered = Dictionary();
	if filter == "":
		return audio_tree_data;
	for key in audio_tree_data:
		var temp_array = [];
		for v in audio_tree_data[key]:
			if filter in v[0].to_lower():
				temp_array.append(v);
		if temp_array.size() != 0 or filter in key.to_lower():
			filtered[key] = temp_array;
	return filtered;


func clear_audio_tree():
	# Remove everything from the tree so we can redraw it.
	tree.clear();


func populate_audio_tree(data: Dictionary):
	# Populate the audio tree from the dictionary.
	var root: TreeItem = tree.create_item();
	tree.set_hide_root(true);
	for key in data:
		# Create the event "folders" to contain multiple audio files.
		var value = audio_tree_data[key];
		var current_child = tree.create_item(root);
		current_child.set_text(0, key);
		current_child.collapsed = true;
		# Each event has a number of files within it.
		for v in value:
			var sub_child: TreeItem = tree.create_item(current_child);
			sub_child.set_text(0, v[0]);
			sub_child.set_metadata(0, v[1]);
			# sub_child.set_text(1, v[1]);
			sub_child.add_button(0, play_unconverted_texture, -1, false, "PLAY");


func update_file_label(filename: String):
	# Update the text in the label to indicate the currently selected file.
	fileLabel.text = "Currently loaded file: " + filename;


# Called when the node enters the scene tree for the first time.
func _ready():
	# First, load the settings.
	load_settings();
	
	# Configure the audio file tree.
	# TODO: The audio tree should have it's own attached script this is handled in.
	tree.set_column_titles_visible(true);
	tree.set_column_title(0, "File");

	load_current_directory();

	# var ss = BNKCompiler.new();
	# var loaded = ss.load("./NMS_AUDIO_PERSISTENT.BNK");
	# if loaded:
	#	ss.extract_all("export");


func load_bnk(filepath: String):
	# Load the xml associated with a bnk file and fill the audio list box with
	# the files in it.
	var data_dir = program_settings["data_dir"];
	# Parse the xml associated with the bnk.
	var bnk_xml := (filepath.get_basename() + ".XML");
	var bnk_path = data_dir + "/" + filepath;
	bnk_xml = data_dir + "/" + bnk_xml;
	print(bnk_xml);
	print(bnk_path);
	# Load the bnk file into memory.
	if File.new().file_exists(bnk_path):
		bnkFile = BNKCompiler.new();
		var loaded = bnkFile.load(data_dir + filepath);
		if loaded:
			print("loaded file");
		else:
			print("oh no...");
	else:
		print("Cannot load %s" % bnk_path);

	# Load the bnk xml into the tree.
	if File.new().file_exists(bnk_xml):
		# Only clear the tree if it actually exists.
		clear_audio_tree();
		parse_bnk_xml(bnk_xml);
		populate_audio_tree(audio_tree_data);
		update_file_label(filepath.get_basename() + ".BNK");
		print("Finished loading the file into the other view...");
		tabContainer.current_tab = 0;


func _on_ItemList_item_activated(index):
	var item: String = itemlist.get_item_text(index).to_upper();
	print("You just pressed on the ", item, " item!");
	if item.ends_with(".BNK"):
		# Load the file into the bnk browser.
		curr_loaded_bnk = item;
		load_bnk(item);
	elif item.ends_with(".WEM"):
		var selected_meta = itemlist.get_item_metadata(index);
		if selected_meta["extracted_path"] != "":
			play_ogg(selected_meta["extracted_path"]);
		else:
			var wem_fullpath = program_settings["data_dir"] + "/" + item;
			var ogg_fullpath = convert_wem_to_ogg(wem_fullpath);
			if ogg_fullpath != "":
				# Now that it is converted, we need to update the tree to show the correct icon and
				# update the meta so that it doesn't get re-converted.
				itemlist.set_item_tooltip(index, "Play %s" % item);
				itemlist.set_item_icon(index, play_converted_texture);
				itemlist.set_item_metadata(index, {"extracted_path": ogg_fullpath});
				play_ogg(ogg_fullpath);
			else:
				print("Failed to convert %s" % item);


func _on_filterButton_toggled(_button_pressed):
	# TODO: make work...
	print(filterField.text);


func _on_filterField_text_entered(new_text):
	# First, clear the tree.
	clear_audio_tree();
	# Then create a new filtered list.
	var filtered_results = filter_audio_list(new_text);
	# Then redraw the tree.
	populate_audio_tree(filtered_results)
	print(new_text);

# TODO: Have it so that when you click play it checks to see if the wem has
# been extracted already. If so, play it. If not, extract then play.


func _on_AudioListTree_button_pressed(item: TreeItem, column: int, id: int):
	if id == 0:
		# Instance the popups (TODO: This will move later...)
		var pp_instance = ProgressPopup.instance();
		add_child(pp_instance);
		print(pp_instance);
		pp_instance.popup();
		# Play button has id 0.
		print("Play "+ item.get_metadata(column));


func _on_AllExtractButton_pressed():
	print("AAAA");
	bnkFile.extract_all(program_settings["export_path"]);


func _on_SelectedExtractButton_pressed():
	# Extract all the selected data.
	# If a leaf is selected that isn't an audio file, then all the child rows under it will be
	# extracted.
	var selected_node: TreeItem = tree.get_next_selected(null);
	var selected_items := [];
	var selected_ids: PoolIntArray = [];

	while selected_node:
		selected_items.append(selected_node);
		selected_node = tree.get_next_selected(selected_node);
	for item in selected_items:
		var meta = item.get_metadata(0);
		if meta != null:
			selected_ids.append(meta);
	print(selected_ids);
	print(program_settings["export_path"]);
	for id in selected_ids:
		bnkFile.extract_single(id, program_settings["export_path"]);
