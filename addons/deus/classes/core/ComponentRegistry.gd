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
signal component_set(node, entity_id, component_name, component)
signal component_removed(node, entity_id, component_name)
signal component_removed_all(node, entity_id, component_name)

var _world: DeusWorld
var _pipeline_set_component = SetComponentPipeline
var _pipeline_get_component = GetComponentPipeline

var component_sets = {}
var next_entity_id: int = 0
var node_components = {} # keeps track of nodes and their components (by name)
var _matching_nodes_cache = {} # cache for get_matching_nodes results
var _cache_generation: int = 0 # incremented when component topology changes
var _script_property_cache = {} # cached script-variable property names per class

func _init(world: DeusWorld):
	_world = world

	_world.register_pipeline(_pipeline_set_component)
	_world.register_pipeline(_pipeline_get_component)

func _ensure_entity_id(node: Node) -> int:
	if not node.has_meta("entity_id"):
		node.set_meta("entity_id", next_entity_id)
		next_entity_id += 1
	return node.get_meta("entity_id")

func _get_sparse_set(component_name: String) -> SparseSet:
	if not component_sets.has(component_name):
		component_sets[component_name] = SparseSet.new()
	return component_sets[component_name]

# initializes the node's component list if it doesn't have one
func _initialize_node_components(node: Node) -> void:
	if not node_components.has(node):
		node_components[node] = []

# checks if the component is new for the node
func _is_new_component(node: Node, component_name: String) -> bool:
	return component_name not in node_components[node]

# adds a new component and emits the appropriate signal
func _add_new_component(node: Node, entity_id: int, component_name: String, component: DefaultComponent) -> void:
	node_components[node].append(component_name)
	_invalidate_matching_cache()
	component_added.emit(node, entity_id, component_name, component)

# updates an existing component if there are changes, and emits signal if necessary
func _update_existing_component(node: Node, entity_id: int, component_name: String, component: DefaultComponent) -> void:
	var components = _get_sparse_set(component_name)
	var existing_component = components.get_value(entity_id)
	if not _deep_compare_component(existing_component, component):
		component_set.emit(node, entity_id, component_name, component)

# adds the component to the sparse set
func _add_component_to_sparse_set(entity_id: int, component_name: String, component: DefaultComponent) -> void:
	var components = _get_sparse_set(component_name)
	components.add(entity_id, component)

# returns cached list of script-variable property names for a Resource class
func _get_script_properties(res: Resource) -> Array:
	var script = res.get_script()
	if script and _script_property_cache.has(script):
		return _script_property_cache[script]
	var props = []
	for property in res.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props.append(property.name)
	if script:
		_script_property_cache[script] = props
	return props

# does a deep comparison of each property
func _deep_compare_component(a: Resource, b: Resource) -> bool:
	if a == null or b == null:
		return a == b
	if a == b:
		return true
	for prop_name in _get_script_properties(a):
		var a_val = a.get(prop_name)
		var b_val = b.get(prop_name)
		if a_val is Resource and b_val is Resource:
			if not _deep_compare_component(a_val, b_val):
				return false
		elif not is_same(a_val, b_val):
			return false
	return true

func set_component(node: Node, component_name: String, component: DefaultComponent) -> void:
	_world.execute_pipeline(_pipeline_set_component, node, {"component_name": component_name, "component": component})
	

func get_component(node: Node, component_name: String) -> DefaultComponent:
	var res = _world.execute_pipeline(_pipeline_get_component, node, {"component_name": component_name})
	if res.result.state == PipelineResult.SUCCESS:
		return res.result.value

	return null

func has_component(node: Node, component_name: String) -> bool:
	var entity_id = _ensure_entity_id(node)
	var components = _get_sparse_set(component_name)
	return components.has(entity_id)

func remove_component(node: Node, component_name: String) -> void:
	var entity_id = _ensure_entity_id(node)
	var components = _get_sparse_set(component_name)
	components.erase(entity_id)
	_invalidate_matching_cache()
	component_removed.emit(node, entity_id, component_name)

	if node_components.has(node):
		node_components[node].erase(component_name)
		if node_components[node].size() == 0:
			node_components.erase(node)
			component_removed_all.emit(node, entity_id, component_name)

func remove_all_components(node: Node) -> void:
	if not node_components.has(node):
		return
	var entity_id = _ensure_entity_id(node)
	var comp_names = node_components[node].duplicate()
	for component_name in comp_names:
		var components = _get_sparse_set(component_name)
		components.erase(entity_id)
		component_removed.emit(node, entity_id, component_name)
	node_components.erase(node)
	_invalidate_matching_cache()
	if comp_names.size() > 0:
		component_removed_all.emit(node, entity_id, comp_names[-1])

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

func _invalidate_matching_cache() -> void:
	_cache_generation += 1
	_matching_nodes_cache.clear()

# returns a list of nodes that have all required components and none of the excluded components
func get_matching_nodes(requires: Array, exclude: Array) -> Array:
	# Build cache key from component names
	var key = str(_cache_generation) + ":"
	for r in requires:
		key += r.get_global_name() + ","
	key += "|"
	for e in exclude:
		key += e.get_global_name() + ","
	if _matching_nodes_cache.has(key):
		return _matching_nodes_cache[key]
	var result = []
	for node in node_components.keys():
		if components_match(node, requires, exclude):
			result.append(node)
	_matching_nodes_cache[key] = result
	return result
