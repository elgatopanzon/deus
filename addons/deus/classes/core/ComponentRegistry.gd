######################################################################
# @author      : ElGatoPanzon
# @class       : ComponentRegistry
# @created     : Wednesday Jan 07, 2026 13:00:00 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : store components with Node types as the owner
######################################################################

class_name ComponentRegistry
extends Resource

signal component_added(node, entity_id, component_name, component)
signal component_removed(node, entity_id, component_name)
signal component_removed_all(node, entity_id, component_name)

var component_sets = {}
var next_entity_id: int = 0
var node_components = {} # keeps track of nodes and their components (by name)

func _ensure_entity_id(node: Node) -> int:
	if not node.has_meta("entity_id"):
		node.set_meta("entity_id", next_entity_id)
		next_entity_id += 1
	return node.get_meta("entity_id")

func _get_sparse_set(component_name: String) -> SparseSet:
	if not component_sets.has(component_name):
		component_sets[component_name] = SparseSet.new()
	return component_sets[component_name]

func set_component(node: Node, component_name: String, component: Resource) -> void:
	var entity_id = _ensure_entity_id(node)
	if not node_components.has(node):
		node_components[node] = []
	if component_name not in node_components[node]:
		node_components[node].append(component_name)

		component_added.emit(node, entity_id, component_name, component)

	var components = _get_sparse_set(component_name)
	components.add(entity_id, component)

func get_component(node: Node, component_name: String) -> Resource:
	var entity_id = _ensure_entity_id(node)
	var components = _get_sparse_set(component_name)
	return components.get_value(entity_id)

func has_component(node: Node, component_name: String) -> bool:
	var entity_id = _ensure_entity_id(node)
	var components = _get_sparse_set(component_name)
	return components.has(entity_id)

func remove_component(node: Node, component_name: String) -> void:
	var entity_id = _ensure_entity_id(node)
	var components = _get_sparse_set(component_name)
	components.erase(entity_id)
	component_removed.emit(node, entity_id, component_name)

	if node_components.has(node):
		node_components[node].erase(component_name)
		if node_components[node].size() == 0:
			node_components.erase(node)
			component_removed_all.emit(node, entity_id, component_name)

			
func remove_all_components(node: Node) -> void:
	if node_components.has(node):
		for component_name in node_components[node]:
			var components = _get_sparse_set(component_name)
			var entity_id = _ensure_entity_id(node)
			components.erase(entity_id)
		node_components.erase(node)

func components_match(node: Node, requires: Array, exclude: Array) -> bool:
	if requires.size() > 0:
		for comp_name in requires:
			if not has_component(node, comp_name.get_global_name()):
				return false
	if exclude.size() > 0:
		for comp_name in exclude:
			if has_component(node, comp_name.get_global_name()):
				return false
	return true

# returns a list of nodes that have all required components and none of the excluded components
func get_matching_nodes(requires: Array, exclude: Array) -> Array:
	var result = []
	for node in node_components.keys():
		if components_match(node, requires, exclude):
			result.append(node)
	return result
