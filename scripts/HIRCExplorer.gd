extends Tree

const HIRC_ENUMS = preload("res://addons/bnk_handler/HIRC/HIRC_enums.gd")

var root: TreeItem
var event_items: Dictionary = {}

onready var BNKTabs = get_node("..")
onready var audioTree = get_node("../AudioExplorer/AudioListTree")

const included_audio_texture = preload("res://icons/icon_included.svg")
const referenced_audio_texture = preload("res://icons/icon_ref.svg")

func _ready():
	pass


func select_event(event_id: int):
	# Scroll to and select the event with the specified id.
	self.scroll_to_item(event_items[event_id])
	event_items[event_id].select(0)
	event_items[event_id].collapsed = false


func load_HIRC_data(data: Array):
	# Load an array of HIRC data into the tree.
	# First, clear the tree of any old data.
	self.clear()
	self.root = self.create_item()
	self.set_hide_root(true)
	for hirc_obj in data:
		var current_child = self.create_item(self.root)
		current_child.collapsed = true
		if hirc_obj.hirc_id == HIRC_ENUMS.HIRC_OBJ_TYPES._00_DUMMY:
			current_child.set_text(0, "%s (%s)" % [hirc_obj.hirc_name, hirc_obj.type])
		else:
			current_child.set_text(0, "%s - %s" % [hirc_obj.hirc_name, hirc_obj.id])
			current_child.set_metadata(0, {"ref_id": hirc_obj.id})
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
	_audio_id.set_metadata(1, {"ref_audio_id": data.audio_id})
	var _source_id: TreeItem = self.create_item(treeItem)
	_source_id.set_text(0, "Source ID:")
	_source_id.set_text(1, "%s" % data.source_id)


func process_hirc_03(data: _HIRC_03_EVENT_ACTION, treeItem: TreeItem):
	# Process the Event HIRC object into the provided TreeItem
	var _scope: TreeItem = self.create_item(treeItem)
	_scope.set_text(0, "Scope:")
	_scope.set_text(1, "%s" % data.scope)
	var _action_type: TreeItem = self.create_item(treeItem)
	_action_type.set_text(0, "Action Type:")
	_action_type.set_text(1, "%s" % data.action_type)
	for param in data.additional_parameters:
		var _param: TreeItem = self.create_item(treeItem)
		_param.set_text(0, "%s" % Utils.back_enum(HIRC_ENUMS.HIRC_03_PARAMETER_TYPE, param[0]))
		_param.set_text(1, "%s" % param[1])
		_param.set_editable(1, true)
		if param[0] != HIRC_ENUMS.HIRC_03_PARAMETER_TYPE.PROBABILITY:
			_param.set_suffix(1, "ms")


func process_hirc_04(data: _HIRC_04_EVENT, treeItem: TreeItem):
	# Process the Event HIRC object into the provided TreeItem
	for event in data.events:
		var sub_item: TreeItem = self.create_item(treeItem)
		sub_item.set_text(0, "Linked event: %s" % event)
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
			var audio_selected: bool = audioTree.select_audio(ref_audio_id)
			if audio_selected == true:
				BNKTabs.change_tab("audio")