extends Tree


var root: TreeItem
var loaded_directory: String

# Icons
const bnk_load_texture = preload("res://icons/icon_bnk.svg")
const folder_texture = preload("res://icons/icon_folder.svg")
const play_unconverted_texture = preload("res://icons/icon_play.svg")
const play_converted_texture = preload("res://icons/icon_play_green.svg")

onready var root_node = get_tree().get_root().get_node("main")

const wemFile = preload("res://addons/bnk_handler/WEM.gd")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func create_child(text: String, icon: Texture = null, parent: TreeItem = self.root,
				  idx: int = -1) -> TreeItem:
	# Create a new TreeItem with the provided details.
	# This will return the new node.
	var new_child: TreeItem = self.create_item(parent, idx)
	new_child.collapsed = true
	new_child.set_text(0, text)
	if icon:
		new_child.set_icon(0, icon)
		#new_child.add_button(0, icon)
	return new_child


func _load_directory(path: String, parent: TreeItem) -> bool:
	print("Loading: %s" % path)
	# Load a directory
	var dir = Directory.new()
	# Also check and see if the directory even exists. If not. Load nothing also.
	if not dir.dir_exists(path):
		return false
	if dir.open(path) != OK:
		return false
	if dir.list_dir_begin(true, true) != OK:
		return false
	# Keep track of an index so that we can always insert folders at the top.
	var folder_idx: int = 0
	while true:
		var file = dir.get_next()
		if file == "":
			break
		var full_path = dir.get_current_dir() + "/%s" % file
		# Only list ones which are .bnk's, .wem's, and directories.
		if dir.current_is_dir():
			# For a directory, we want to 
			var dir_node = self.create_child(file, folder_texture, parent, folder_idx)
			folder_idx += 1
			self._load_directory(full_path, dir_node)
		if file.to_lower().ends_with(".bnk"):
			# Add bnk's with the load icon.
			var bnk_node: TreeItem = self.create_child(file, bnk_load_texture, parent)
			bnk_node.set_metadata(0, {"fullpath": full_path})
		elif file.to_lower().ends_with(".wem"):
			# Add wem's with a play icon.
			# If the wem has been converted already, then make the play icon green to indicate
			# this.
			# var wem_ogg_path = is_wem_converted(file)
			# if wem_ogg_path != "":
			# 	self.add_item(file, play_converted_texture, true)
			# 	self.set_item_tooltip(curr_idx, "Play %s" % file)
			# 	self.set_item_metadata(curr_idx, {"extracted_path": wem_ogg_path})
			# else:
			var wem_node: TreeItem = self.create_child(file, play_converted_texture, parent)
			wem_node.set_metadata(0, {"fullpath": full_path})
		else:
			continue
	dir.list_dir_end()
	return true


func load_directory(path: String):
	# Load the specified directory path.
	self.clear()
	self.root = self.create_item()
	self.set_hide_root(true)
	# Go over the files in the folder.
	var loaded = self._load_directory(path, self.root)
	if loaded:
		self.loaded_directory = path


func _on_FileTree_item_activated():
	var selected_item: TreeItem = self.get_selected()
	var meta = selected_item.get_metadata(0)
	if meta:
		var fullpath = meta.get("fullpath")
		if fullpath:
			if fullpath.to_lower().ends_with(".bnk"):
				root_node.audioTree.bnk_fullpath = fullpath
				root_node.load_bnk(fullpath)
			elif fullpath.to_lower().ends_with(".wem"):
				var wem = wemFile.new()
				wem.open(fullpath)
				root_node.play_wem(selected_item.get_text(0), wem)
