######################################################################
# @author      : ElGatoPanzon
# @class       : NodeRegistry
# @created     : Thursday Jan 08, 2026 20:50:12 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : keeps a global account of all active Nodes
######################################################################

class_name NodeRegistry
extends Node

signal node_registered(node, node_name, meta_id)
signal node_deregistered(node, node_name, meta_id)
signal node_renamed(node, node_name, node_name_new)

# keeps mappings for various node attributes
var nodes_by_name: Dictionary = {}
var nodes_by_type: Dictionary = {}
var nodes_by_group: Dictionary = {}
var nodes_by_meta: Dictionary = {}

func _enter_tree():
	# connect to the scenetree signals once
	var st = get_tree()
	st.connect("node_added", Callable(self, "_on_node_added"))
	st.connect("node_removed", Callable(self, "_on_node_removed"))
	st.connect("node_renamed", Callable(self, "_on_node_renamed"))

# core function to add node to all registries
func _register_node(node: Node):
	# node name
	nodes_by_name[node.name] = node
	# node type
	var t = node.get_class()
	if not nodes_by_type.has(t):
		nodes_by_type[t] = []
	nodes_by_type[t].append(node)
	# node groups
	for group in node.get_groups():
		if not nodes_by_group.has(group):
			nodes_by_group[group] = []
		nodes_by_group[group].append(node)
	# meta id - if defined
	var meta_id = ""
	if node.has_meta("id"):
		meta_id = node.get_meta("id")
		if not nodes_by_meta.has(meta_id):
			nodes_by_meta[meta_id] = node

	node_registered.emit(node, node.name, meta_id)

# remove node from all registries
func _deregister_node(node: Node):
	if nodes_by_name.has(node.name) and nodes_by_name[node.name] == node:
		nodes_by_name.erase(node.name)
	if nodes_by_type.has(node.get_class()):
		nodes_by_type[node.get_class()].erase(node)
		if nodes_by_type[node.get_class()].is_empty():
			nodes_by_type.erase(node.get_class())
	for group in node.get_groups():
		if nodes_by_group.has(group):
			nodes_by_group[group].erase(node)
			if nodes_by_group[group].is_empty():
				nodes_by_group.erase(group)
	var meta_id = ""
	if node.has_meta("id"):
		meta_id = node.get_meta("id")
		if nodes_by_meta.has(meta_id):
			nodes_by_meta[meta_id].erase(node)
			if nodes_by_meta[meta_id].is_empty():
				nodes_by_meta.erase(meta_id)

	node_deregistered.emit(node, node.name, meta_id)

# automatically called by the signals
func _on_node_added(node: Node):
	_register_node(node)

func _on_node_removed(node: Node):
	_deregister_node(node)

func _on_node_renamed(node: Node, old_name: String):
	# update only the name registry for rename
	if nodes_by_name.has(old_name) and nodes_by_name[old_name] == node:
		nodes_by_name.erase(old_name)
	nodes_by_name[node.name] = node

	node_renamed.emit(node, node.name, old_name)

# simple accessors
func get_nodes_by_name(_name: String) -> Node:
	return nodes_by_name.get(_name, null)

func get_node_by_id(meta_id) -> Node:
	return nodes_by_meta.get(meta_id, null)

func get_nodes_by_type(type_name: String) -> Array:
	return nodes_by_type.get(type_name, [])

func get_nodes_by_group(group: String) -> Array:
	return nodes_by_group.get(group, [])
