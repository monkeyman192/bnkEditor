tool
extends EditorPlugin


func _enter_tree( ):
	self.add_custom_type("BNKHandler", "Node", preload("BNKHandler.gd"), preload("res://icon.png"))


func _exit_tree( ):
	self.remove_custom_type("BNKHandler")
