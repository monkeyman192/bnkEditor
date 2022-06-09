extends Tree

const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

var root: TreeItem
var event_items: Dictionary = {}
var audio_mapping: Dictionary = {}

onready var BNKTabs = get_node("..")
onready var audioTree = get_node("../AudioExplorer/AudioListTree")

const included_audio_texture = preload("res://icons/icon_included.svg")
const referenced_audio_texture = preload("res://icons/icon_ref.svg")
const edit_texture = preload("res://icons/icon_edit.svg")
const reload_texture = preload("res://icons/icon_reload.svg")
const add_texture = preload("res://icons/icon_add.svg")

var ACTION_TYPES: String = Utils.stringify_enum(HIRC_ENUMS.HIRC_03_ACTION_TYPE)

enum BUTTON_ENUM {RELOAD, ADD}


func _ready():
	pass


func select_event(event_id: int):
	# Scroll to and select the event with the specified id.
	self.scroll_to_item(event_items[event_id])
	event_items[event_id].select(0)
	event_items[event_id].collapsed = false


func deselect_all():
	# Deselect all the currently selected items in the tree.
	var curr_selected = self.get_next_selected(null)
	if curr_selected != null:
		curr_selected.deselect(0)
	while curr_selected:
		curr_selected = self.get_next_selected(curr_selected)
		if curr_selected != null:
			curr_selected.deselect(0)


func select_sfx(audio_id: int) -> int:
	# Scroll to and select the audio with the specified id.
	var req_treeItem = self.audio_mapping.get(audio_id)
	if req_treeItem != null:
		self.deselect_all()
		req_treeItem.select(0)
		req_treeItem.get_parent().collapsed = false
		self.scroll_to_item(req_treeItem)
		req_treeItem.collapsed = false
		return OK
	else:
		return FAILED


func update_metadata(item: TreeItem, column: int, meta: Dictionary):
	# Update the current meta dictionary with the provided one, in the same way that python
	# provides an `update` method on dictionaries.
	var curr_meta = item.get_metadata(column)
	for key in meta:
		curr_meta[key] = meta[key]


func get_parent_hric_obj(item: TreeItem) -> TreeItem:
	# Return the parent object of the given on that contains the reference to the actual hirc
	# object so that we may edit it.
	var parent = item.get_parent()
	while parent != null:
		var meta = parent.get_metadata(0)
		if meta != null:
			if "_data" in meta:
				return parent
		# If this parent didn't have it, go up another level.
		parent = parent.get_parent()
	return null


func load_HIRC_data(data: Array):
	# Load an array of HIRC data into the tree.
	# First, clear the tree of any old data.
	self.clear()
	self.root = self.create_item()
	self.set_hide_root(true)
	for hirc_obj in data:
		var current_child = self.create_item(self.root)
		current_child.collapsed = true
		# Assign the hirc obj to the meta of the row so that we can more easily write to it.
		current_child.set_metadata(0, {"_data": hirc_obj})
		if hirc_obj.hirc_id == HIRC_ENUMS.HIRC_OBJ_TYPES._00_DUMMY:
			current_child.set_text(0, "%s (0x%X)" % [hirc_obj.hirc_name, hirc_obj.hirc_type])
		else:
			current_child.set_text(0, "%s - 0x%X" % [hirc_obj.hirc_name, hirc_obj.id])
			update_metadata(current_child, 0, {"ref_id": hirc_obj.id})
		match hirc_obj.hirc_id:
			HIRC_ENUMS.HIRC_OBJ_TYPES._02_SOUND_SFX:
				process_hirc_02(hirc_obj, current_child)
			HIRC_ENUMS.HIRC_OBJ_TYPES._03_EVENT_ACTION:
				event_items[hirc_obj.id] = current_child
				process_hirc_03(hirc_obj, current_child)
			HIRC_ENUMS.HIRC_OBJ_TYPES._04_EVENT:
				process_hirc_04(hirc_obj, current_child)


func process_hirc_02(data: _HIRC_02_SOUND_SFX, treeItem: TreeItem):
	var _location: TreeItem = self.create_item(treeItem)
	_location.set_text(0, "Location:")
	_location.set_text(1, data.inc_or_streamed)
	if data._inc_or_streamed == HIRC_ENUMS.HIRC_02_INC_OR_STREAMED.EMBEDDED:
		_location.set_icon(1, included_audio_texture)
	else:
		_location.set_icon(1, referenced_audio_texture)
	var _audio_id: TreeItem = self.create_item(treeItem)
	_audio_id.set_text(0, "Audio ID:")
	_audio_id.set_text(1, "%s" % data.audio_id)
	# Add the audio id to the audio mapping so that we can find this particular sound sfx.
	self.audio_mapping[data.audio_id] = treeItem
	_audio_id.set_metadata(1, {"ref_audio_id": data.audio_id})
	var _audio_size: TreeItem = self.create_item(treeItem)
	_audio_size.set_text(0, "Audio size:")
	_audio_size.set_text(1, "%s bytes" % data.audio_size.value)
	if data.sound_structure.additional_params.size() != 0:
		var _additional_params: TreeItem = self.create_item(treeItem)
		_additional_params.set_text(0, "Additional parameters")
		for d in data.sound_structure.additional_params:
			var _param: TreeItem = self.create_item(_additional_params)
			_param.set_text(0, "%s" % Utils.back_enum(HIRC_ENUMS.SOUND_OBJ_ADDITIONAL_PARAMS, d[0]))
			_param.set_text(1, "%s" % d[1])
			_param.set_editable(1, true)
			_param.set_metadata(1, {"_edited" : false, "_orig_value": d[1], "_ref": d})
			if d[0] == HIRC_ENUMS.SOUND_OBJ_ADDITIONAL_PARAMS.VOLUME:
				_param.set_suffix(1, "db")


func process_hirc_03(data: _HIRC_03_EVENT_ACTION, treeItem: TreeItem):
	# Process the Event HIRC object into the provided TreeItem
	var _scope: TreeItem = self.create_item(treeItem)
	_scope.set_text(0, "Scope:")
	_scope.set_text(1, "%s" % data.scope)
	var _action_type: TreeItem = self.create_item(treeItem)
	_action_type.set_text(0, "Action Type:")
	_action_type.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	_action_type.set_editable(1, true)
	# Set the tooltip as a single space to not show it.
	_action_type.set_tooltip(1, " ")
	_action_type.set_text(1, ACTION_TYPES)
	_action_type.set_range(1, data.action_type)
	_action_type.set_metadata(1,
		{"_edited" : false, "_orig_value": data.action_type, "_ref": data._action_type,
		 "_is_enum": true}
	)
	if data.additional_parameter_count != 0:
		var _additional_params: TreeItem = self.create_item(treeItem)
		_additional_params.set_text(0, "Additional parameters")
		# _additional_params.add_button(1, add_texture, BUTTON_ENUM.ADD, false, "Add additional parameter")
		for param in data.additional_parameters:
			var _param: TreeItem = self.create_item(_additional_params)
			_param.set_text(0, "%s" % Utils.back_enum(HIRC_ENUMS.HIRC_03_PARAMETER_TYPE, param[0]))
			_param.set_text(1, "%s" % param[1])
			_param.set_editable(1, true)
			_param.set_metadata(1, {"_edited" : false, "_orig_value": param[1], "_ref": param})
			if param[0] != HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.PROBABILITY:
				_param.set_suffix(1, "ms")


func process_hirc_04(data: _HIRC_04_EVENT, treeItem: TreeItem):
	# Process the Event HIRC object into the provided TreeItem
	for event in data.events:
		var sub_item: TreeItem = self.create_item(treeItem)
		sub_item.set_text(0, "Linked event: 0x%X" % event)
		sub_item.set_metadata(1, {"ref_event_id": event})


func _on_HIRCExplorer_item_activated():
	# When we double click on an item, if it's a link to another event, then
	# select that event.
	var selected_item: TreeItem = self.get_selected()
	var meta = selected_item.get_metadata(1)
	if meta != null:
		var ref_event_id = meta.get("ref_event_id")
		if ref_event_id != null:
			self.select_event(ref_event_id)
			# We can return since no further code in this loop is appropriate.
			return
		var ref_audio_id = meta.get("ref_audio_id")
		if ref_audio_id != null:
			if ref_audio_id in audioTree.audio_mapping:
				BNKTabs.change_tab("audio")
				audioTree.select_audio(ref_audio_id)


func _on_HIRCExplorer_item_edited():
	# When something is edited, we need to do a few things:
	# 1. Add the "refresh" button to the edited row so that we can reset the value back to what it
	# was originally.
	# 2. Update the icon for the parent hirc obj so that we can see that it was edited.
	# 3. Update the hirc edited count in the associated bnk file.
	var edited = self.get_edited()
	var meta = edited.get_metadata(1)
	var orig_value = meta.get("_orig_value")
	# Track whether the value changes
	var val_changed: bool = false
	# Track whether the value is different from the original
	var val_differs: bool = false
	var new_value
	if meta.get("_is_enum", false):
		new_value = edited.get_range(1)
	else:
		new_value = float(edited.get_text(1))
	if new_value != orig_value:
		if not meta.get("_edited"):
			# Only try and add the button if the field was not already edited.
			edited.add_button(1, reload_texture, BUTTON_ENUM.RELOAD, false, "Revert to original")
			val_changed = true
		update_metadata(edited, 1, {"_edited": true})
		var _ref = meta["_ref"]
		if typeof(_ref) == TYPE_ARRAY:
			_ref[1] = new_value
		else:
			# For now the only other option is that the reference is a dictionary.
			_ref["value"] = new_value
		val_differs = true
	else:
		if meta.get("_edited"):
			edited.erase_button(1, BUTTON_ENUM.RELOAD)
			update_metadata(edited, 1, {"_edited": false})
			val_changed = true
		val_differs = false

	# If the value actually changed, then write it to the underlying HIRC object and update the
	# parent tree item which needs the icon.
	if val_changed:
		var hirc_parent = self.get_parent_hric_obj(edited)
		var parent_meta = hirc_parent.get_metadata(0)
		var hirc_obj = parent_meta["_data"]
		# Get the change count so we may modify it directly.
		var _change_count = hirc_obj.change_count
		if val_differs:
			_change_count += 1
			audioTree._bnkFile.modified_hirc_chunks += 1
		else:
			_change_count -= 1
			audioTree._bnkFile.modified_hirc_chunks -= 1
		# Check to see what the edit count is and update the parent icon appropriately.
		hirc_obj.change_count = _change_count
		if _change_count != 0:
			hirc_parent.set_icon(1, edit_texture)
		else:
			hirc_parent.set_icon(1, null)


func _on_HIRCExplorer_button_pressed(item: TreeItem, column: int, id: int):
	if column == 1 && id == BUTTON_ENUM.RELOAD:
		# The reload button will reset the value in the row back to its original value.
		var meta = item.get_metadata(1)
		var orig_value = meta.get("_orig_value")
		if meta.get("_is_enum", false):
			# Enum fields we want to reset the range, not text
			item.set_range(1, orig_value)
		else:
			item.set_text(1, "%s" % orig_value)
		update_metadata(item, 1, {"_edited": false})
		item.erase_button(1, BUTTON_ENUM.RELOAD)

		# Change the value in the reference back to what it was originally.
		var _ref = meta["_ref"]
		if typeof(_ref) == TYPE_ARRAY:
			_ref[1] = orig_value
		else:
			# For now the only other option is that the reference is a dictionary.
			_ref["value"] = orig_value

		# We also need to update the parent.
		var hirc_parent = self.get_parent_hric_obj(item)
		var parent_meta = hirc_parent.get_metadata(0)
		var hirc_obj = parent_meta["_data"]
		hirc_obj.change_count -= 1
		audioTree._bnkFile.modified_hirc_chunks -= 1
		# Only need to check if the value is 0 because when resetting the value will start non-zero
		# so we can't reset something and have the icon need to appear.
		if hirc_obj.change_count == 0:
			hirc_parent.set_icon(1, null)
	elif column == 1 && id == BUTTON_ENUM.ADD:
		print("Adding something new and exciting!")
