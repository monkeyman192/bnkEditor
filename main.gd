extends Control

const bnkFile = preload("res://addons/bnk_handler/BNK.gd")
const wemFile = preload("res://addons/bnk_handler/WEM.gd")
const bnkXmlParser = preload("res://addons/bnk_handler/META/bnk_xml.gd")
const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

onready var tabContainer = $VBoxContainer/TabContainer
onready var itemlist = $VBoxContainer/TabContainer/FileBrowser/FileList
onready var fileLabel = $VBoxContainer/TabContainer/BNKExplorer/FileSelectRow
onready var audioController = $VBoxContainer/NowPlayingBox
onready var hircExplorer = $VBoxContainer/TabContainer/BNKExplorer/BNKTabs/HIRCExplorer
onready var audioExplorer = $VBoxContainer/TabContainer/BNKExplorer/BNKTabs/AudioExplorer
onready var audioTree = $VBoxContainer/TabContainer/BNKExplorer/BNKTabs/AudioExplorer/AudioListTree
var parser = XMLParser.new()

# Preload popup scenes.
var ProgressPopup = preload("res://scenes/ProgressPopup.tscn")

# Icon variables
var play_unconverted_texture = preload("res://icons/icon_play.svg")
var play_converted_texture = preload("res://icons/icon_play_green.svg")
var bnk_load_texture = preload("res://icons/icon_load.svg")
var included_audio_texture = preload("res://icons/icon_included.svg")
var referenced_audio_texture = preload("res://icons/icon_ref.svg")

# Some paths to keep track of where things go.
const AUDIO_PERSISTENT = "NMS_AUDIO_PERSISTENT.XML"
# Save user settings
const SETTINGS_FILE = "user://settings/settings.json"
const PCB = "packed_codebooks_aoTuV_603.bin"

# A spearate thread to do stuff in.
var thread = Thread.new()


# Dictionary to keep track of all the settings. This will be written when a setting is changed,
# and loaded when the program is opened.
var program_settings = {
	"export_path": "",
	"data_dir": ""
}


func load_settings():
	# Load the program settings file.
	var settings_dir = Directory.new()
	var settings_file = File.new()
	# Check to see if the settings directory exists. If not. Make it.
	if not settings_dir.dir_exists(SETTINGS_FILE.get_base_dir()):
		var err = settings_dir.make_dir(SETTINGS_FILE.get_base_dir())
		if err != OK:
			print("Cannot create a directory :(")
	if not settings_file.file_exists(SETTINGS_FILE):
		settings_file.open(SETTINGS_FILE, File.WRITE)
		settings_file.store_string(JSON.print(program_settings))
		settings_file.close()
	else:
		settings_file.open(SETTINGS_FILE, File.READ)
		var json_parsed := JSON.parse(settings_file.get_as_text())
		if json_parsed.error != OK:
			print("Error: %s" % json_parsed.error_string)
		else:
			program_settings = json_parsed.result
	audioExplorer.export_path = program_settings["export_path"]
	audioTree.program_settings = program_settings


func write_settings():
	# Write the current settings to a file.
	var settings_dir = Directory.new()
	var settings_file = File.new()
	# Check to see if the settings directory exists. If not. Make it.
	if not settings_dir.dir_exists(SETTINGS_FILE.get_base_dir()):
		var err = settings_dir.make_dir(SETTINGS_FILE.get_base_dir())
		if err != OK:
			print("Cannot create a directory :(")
	print("Writing settings to %s" % SETTINGS_FILE)
	settings_file.open(SETTINGS_FILE, File.WRITE)
	var settings_string = JSON.print(program_settings)
	settings_file.store_string(settings_string)
	settings_file.close()


func play_ogg_file(_path: String):
	# Take the path to an .ogg file and play it once.
	# var file := File.new()
	# file.open(path, File.READ)
	# # TODO: read in chunks.
	# var ogg_data = file.get_buffer(file.get_len())
	# var audio_stream := AudioStreamOGGVorbis.new()
	# audio_stream.data = ogg_data
	# audioPlayer.stream = audio_stream
	# audioPlayer.play()
	pass


func play_wem(file_name: String, wem: WEM):
	audioController.play_audio(file_name, wem)


func extract_wem():
	pass


func is_wem_extracted(_filename: String, _bnk_name: String) -> bool:
	# Determine whether the specified filename has been extracted from a .bnk file.
	return true


func is_wem_converted(filename: String) -> String:
	# Determine whether the specified filename has been converted from .wem to .ogg.
	# If so, return the file path so that we don't need to search for it again, and can play it
	# directly.
	var converted_fname = filename.get_file().get_basename() + ".ogg"
	var converted_fpath = program_settings["export_path"] + "/" + converted_fname
	if Directory.new().file_exists(converted_fpath):
		return converted_fpath
	else:
		return ""


func load_current_directory():
	# Load the currently selected directory into the file tree.
	if program_settings["data_dir"] == "":
		# Do an initial check to see if we have an empty directory or not.
		return
	var dir = Directory.new()
	# Also check and see if the directory even exists. If not. Load nothing also.
	if not dir.dir_exists(program_settings["data_dir"]):
		return
	dir.open(program_settings["data_dir"])
	dir.list_dir_begin()
	itemlist.clear()
	var curr_idx := 0
	# Go over the files in the folder.
	while true:
		var file = dir.get_next()
		if file == "":
			break
		# Only list ones which are .bnks.
		elif not file.begins_with("."):
			if file.to_lower().ends_with(".bnk"):
				# Add bnk's with the load icon.
				itemlist.add_item(file, bnk_load_texture, true)
				itemlist.set_item_tooltip(curr_idx, "Load %s in other view" % file)
			elif file.to_lower().ends_with(".wem"):
				# Add wem's with a play icon.
				# If the wem has been converted already, then make the play icon green to indicate
				# this.
				var wem_ogg_path = is_wem_converted(file)
				if wem_ogg_path != "":
					itemlist.add_item(file, play_converted_texture, true)
					itemlist.set_item_tooltip(curr_idx, "Play %s" % file)
					itemlist.set_item_metadata(curr_idx, {"extracted_path": wem_ogg_path})
				else:
					itemlist.add_item(file, play_unconverted_texture, true)
					itemlist.set_item_tooltip(curr_idx, "Convert and play %s" % file)
					itemlist.set_item_metadata(curr_idx, {"extracted_path": ""})
			else:
				continue
			curr_idx += 1
	dir.list_dir_end()
	# Change the tab to the file list.
	tabContainer.current_tab = 1


func parse_xml():
	var _err = parser.open("res://data/test.xml")
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == parser.NODE_ELEMENT:
			if parser.get_node_name() != '':
				print(parser.get_node_name(), " ", parser.get_named_attribute_value_safe("name"))
				for i in range(parser.get_attribute_count()):
					print(parser.get_attribute_name(i), ": ", parser.get_attribute_value(i))


func update_file_label(filename: String):
	# Update the text in the label to indicate the currently selected file.
	fileLabel.text = "Currently loaded file: " + filename


# Called when the node enters the scene tree for the first time.
func _ready():
	# First, load the settings.
	load_settings()

	# Start the directory load in a separate thread to avoid locking the UI.
	thread.start(self, "load_current_directory")


func _exit_tree():
	# Cleanly close the thread.
	thread.wait_to_finish()


func load_bnk(filepath: String):
	# Load the xml associated with a bnk file and fill the audio list box with
	# the files in it.
	var data_dir = program_settings["data_dir"]
	# Parse the xml associated with the bnk.
	var bnk_xml: String = filepath.get_basename() + ".XML"
	var bnk_path = data_dir + "/" + filepath
	bnk_xml = data_dir + "/" + bnk_xml
	print(bnk_xml)
	print(bnk_path)
	# Load the bnk file into memory.
	var _bnkFile
	if File.new().file_exists(bnk_path):
		_bnkFile = bnkFile.new()
		_bnkFile.open(data_dir + "/" + filepath)
	else:
		print("Cannot load %s" % bnk_path)
		return
	print("About to put %s HIRC values in the tree..." % _bnkFile.hirc.data.size())
	hircExplorer.load_HIRC_data(_bnkFile.hirc.data)
	audioExplorer._bnkFile = _bnkFile
	# Load the bnk xml into the tree.
	if File.new().file_exists(bnk_xml):
		var atd = bnkXmlParser.new().parse_bnk_xml(bnk_xml)
		audioTree.populate_audio_tree(atd)
		update_file_label(filepath.get_basename() + ".BNK")
		print("Finished loading the file into the other view...")
		tabContainer.current_tab = 0


func _on_ItemList_item_activated(index):
	var item: String = itemlist.get_item_text(index).to_upper()
	print("You just pressed on the ", item, " item!")
	if item.ends_with(".BNK"):
		# Load the file into the bnk browser.
		audioTree.curr_loaded_bnk = item
		load_bnk(item)
	elif item.ends_with(".WEM"):
		var selected_meta = itemlist.get_item_metadata(index)
		if selected_meta["extracted_path"] != "":
			play_ogg_file(selected_meta["extracted_path"])
		else:
			var wem_fullpath = program_settings["data_dir"] + "/" + item
			var wem = wemFile.new()
			wem.open(wem_fullpath)
			play_wem(item, wem)
