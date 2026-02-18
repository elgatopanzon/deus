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
signal node_id_set(node, meta_id)
signal node_signal_connected(node, target, signal_name, callable, flags)
signal node_signal_connection_request(node, target, signal_name, callable, flags)

# keeps mappings for various node attributes
var nodes_by_name: Dictionary = {}
var nodes_by_type: Dictionary = {}
var nodes_by_meta: Dictionary = {}

# deferred signal connection request queue
# items are dictionaries: {
#    "target": <node_name, node_id, node_type, or node_group>,
#    "signal": <signal_name>,
#    "callable": <Callable>
# }
var deferred_signal_queue: Array = []
# dirty flag for lazy queue processing -- coalesces multiple tree_changed
# signals per frame into a single flush
var _deferred_queue_dirty: bool = false

func _enter_tree():
	var st = get_tree()
	st.connect("node_added", Callable(self, "_on_node_added"))
	st.connect("node_removed", Callable(self, "_on_node_removed"))
	st.connect("node_renamed", Callable(self, "_on_node_renamed"))
	st.connect("tree_changed", Callable(self, "_on_tree_changed"))

# core function to add node to all registries
func _register_node(node: Node):
	nodes_by_name[node.name] = node
	var t = node.get_class()
	if not nodes_by_type.has(t):
		nodes_by_type[t] = []
	nodes_by_type[t].append(node)
	var meta_id = ""
	if node.has_meta("id"):
		meta_id = node.get_meta("id")
		if not nodes_by_meta.has(meta_id):
			nodes_by_meta[meta_id] = node
	node_registered.emit(node, node.name, meta_id)

func _deregister_node(node: Node):
	if nodes_by_name.has(node.name) and nodes_by_name[node.name] == node:
		nodes_by_name.erase(node.name)
	if nodes_by_type.has(node.get_class()):
		nodes_by_type[node.get_class()].erase(node)
		if nodes_by_type[node.get_class()].is_empty():
			nodes_by_type.erase(node.get_class())
	var meta_id = ""
	if node.has_meta("id"):
		meta_id = node.get_meta("id")
		if nodes_by_meta.has(meta_id):
			nodes_by_meta.erase(meta_id)
	node_deregistered.emit(node, node.name, meta_id)

func set_node_id(node: Node, id: String):
	node.set_meta("id", id)
	nodes_by_meta[id] = node

	node_id_set.emit(node, id)

func _on_node_added(node: Node):
	_register_node(node)

func _on_node_removed(node: Node):
	_deregister_node(node)

func _on_node_renamed(node: Node, old_name: String):
	if nodes_by_name.has(old_name) and nodes_by_name[old_name] == node:
		nodes_by_name.erase(old_name)
	nodes_by_name[node.name] = node

	node_renamed.emit(node, node.name, old_name)

# helper for deferred
func try_get_node(target) -> Node:
	if target is Node:
		return target
	var n = get_nodes_by_name(target)
	if n != null:
		return n
	n = get_node_by_id(target)
	if n != null:
		return n
	return null

# process deferred signal connection queue on tree_changed
func _try_connect_signal(target, signal_name: String, callable: Callable, flags: int = 0) -> bool:
	var connected := false
	var found_node = try_get_node(target)

	# if direct node found, try to connect
	if found_node and found_node.has_signal(signal_name):
		if not found_node.is_connected(signal_name, callable):
			found_node.connect(signal_name, callable, flags)
			node_signal_connected.emit(found_node, target, signal_name, callable, flags)
		return true

	# try by type or group
	# note: keep connected as false to keep this as a persistent deferred connection
	var nodes = get_nodes_by_type(target) + get_nodes_by_group(target)
	if nodes.size() > 1:
		for node in nodes:
			if node.has_signal(signal_name) and not node.is_connected(signal_name, callable):
				node.connect(signal_name, callable, flags)

				node_signal_connected.emit(node, target, signal_name, callable, flags)

	return connected

func _on_tree_changed():
	if deferred_signal_queue.size() > 0:
		_deferred_queue_dirty = true

func _process(_delta):
	if not _deferred_queue_dirty:
		return
	_deferred_queue_dirty = false
	var still_deferred : Array = []
	for request in deferred_signal_queue:
		if not _try_connect_signal(request.target, request.signal, request.callable):
			still_deferred.append(request)
	deferred_signal_queue = still_deferred

# user API for deferred signal connection
func connect_signal_deferred(target, signal_name: String, callable: Callable, flags: int):
	var request = {"target": target, "signal": signal_name, "callable": callable, "flags": flags}

	node_signal_connection_request.emit(target, signal_name, callable, flags)

	if not _try_connect_signal(target, signal_name, callable, flags):
		deferred_signal_queue.append(request)

func get_nodes_by_name(_name: String) -> Node:
	return nodes_by_name.get(_name, null)

func get_node_by_id(meta_id) -> Node:
	return nodes_by_meta.get(meta_id, null)

func get_nodes_by_type(type_name: String) -> Array:
	return nodes_by_type.get(type_name, [])

func get_nodes_by_group(group: String) -> Array:
	return get_tree().get_nodes_in_group(group)
