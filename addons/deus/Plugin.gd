######################################################################
# @author      : ElGatoPanzon
# @class       : Plugin
# @created     : Friday Jan 09, 2026 18:44:26 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : Deus plugin entrypoint
######################################################################

@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("Deus", "res://addons/deus/classes/core/DeusWorld.gd")

func _exit_tree():
	remove_autoload_singleton("Deus")
