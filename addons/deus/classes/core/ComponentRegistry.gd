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
var _component_nodes = {} # reverse index: component_name -> Array of nodes that have it
var _matching_nodes_cache = {} # cache for get_matching_nodes results
var _cache_generation: int = 0 # incremented when component topology changes
var _script_property_cache = {} # cached script-variable property names per class

# bitset cache: each component type gets a unique bit, each entity tracks a bitmask
var _component_bit_index = {} # component_name -> int bit position
var _next_bit_index: int = 0
var _entity_bitmask = {} # entity_id -> int bitmask of owned components
var _filter_bitmask_cache = {} # cache key -> [require_mask, exclude_mask]

func _init(world: DeusWorld):
	_world = world

	_world.register_pipeline(_pipeline_set_component)
	_world.register_pipeline(_pipeline_get_component)

# returns the bit index for a component name, assigning one if new
func _get_component_bit(component_name: String) -> int:
	if not _component_bit_index.has(component_name):
		_component_bit_index[component_name] = _next_bit_index
		_next_bit_index += 1
	return _component_bit_index[component_name]

# converts a require or exclude script array into a single bitmask
func _build_filter_bitmask(components: Array) -> int:
	var mask: int = 0
	for comp in components:
		mask |= (1 << _get_component_bit(comp.get_global_name()))
	return mask

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
	if not _component_nodes.has(component_name):
		_component_nodes[component_name] = []
	_component_nodes[component_name].append(node)
	# update entity bitmask
	var bit = _get_component_bit(component_name)
	if not _entity_bitmask.has(entity_id):
		_entity_bitmask[entity_id] = 0
	_entity_bitmask[entity_id] |= (1 << bit)
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

# fast path for component loading -- direct SparseSet access, no pipeline overhead
func get_component_direct(entity_id: int, component_name: String) -> DefaultComponent:
	var ss = component_sets.get(component_name)
	if ss == null:
		return null
	var val = ss.get_value(entity_id)
	if val == null:
		return null
	return val.duplicate(true)

func has_component(node: Node, component_name: String) -> bool:
	var entity_id = _ensure_entity_id(node)
	var components = _get_sparse_set(component_name)
	return components.has(entity_id)

func remove_component(node: Node, component_name: String) -> void:
	var entity_id = _ensure_entity_id(node)
	var components = _get_sparse_set(component_name)
	components.erase(entity_id)
	if _component_nodes.has(component_name):
		_component_nodes[component_name].erase(node)
	# clear entity bitmask bit
	if _component_bit_index.has(component_name) and _entity_bitmask.has(entity_id):
		_entity_bitmask[entity_id] &= ~(1 << _component_bit_index[component_name])
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
		if _component_nodes.has(component_name):
			_component_nodes[component_name].erase(node)
		component_removed.emit(node, entity_id, component_name)
	node_components.erase(node)
	# clear entire entity bitmask
	_entity_bitmask.erase(entity_id)
	_invalidate_matching_cache()
	if comp_names.size() > 0:
		component_removed_all.emit(node, entity_id, comp_names[-1])

func components_match(node: Node, requires: Array, exclude: Array) -> bool:
	var entity_id = _ensure_entity_id(node)
	var entity_mask: int = _entity_bitmask.get(entity_id, 0)
	var req_mask: int = _build_filter_bitmask(requires)
	var exc_mask: int = _build_filter_bitmask(exclude)
	return (entity_mask & req_mask) == req_mask and (entity_mask & exc_mask) == 0

func _invalidate_matching_cache() -> void:
	_cache_generation += 1
	_matching_nodes_cache.clear()
	_filter_bitmask_cache.clear()

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

	# build or retrieve cached filter bitmasks
	var req_mask: int
	var exc_mask: int
	if _filter_bitmask_cache.has(key):
		var cached = _filter_bitmask_cache[key]
		req_mask = cached[0]
		exc_mask = cached[1]
	else:
		req_mask = _build_filter_bitmask(requires)
		exc_mask = _build_filter_bitmask(exclude)
		_filter_bitmask_cache[key] = [req_mask, exc_mask]

	var result: Array
	if requires.size() == 0:
		# no requires: start from all known nodes, filter by exclude only
		if exc_mask == 0:
			result = node_components.keys()
		else:
			result = []
			for node in node_components:
				var eid: int = _ensure_entity_id(node)
				if (_entity_bitmask.get(eid, 0) & exc_mask) == 0:
					result.append(node)
	else:
		# find smallest candidate set from _component_nodes to minimise iterations
		var smallest_name: String = ""
		var smallest_size: int = -1
		for r in requires:
			var rname = r.get_global_name()
			var sz = _component_nodes[rname].size() if _component_nodes.has(rname) else 0
			if smallest_size == -1 or sz < smallest_size:
				smallest_name = rname
				smallest_size = sz
		if smallest_size == 0:
			_matching_nodes_cache[key] = []
			return []
		# iterate smallest set and filter with bitwise check
		result = []
		for node in _component_nodes[smallest_name]:
			var eid: int = _ensure_entity_id(node)
			var emask: int = _entity_bitmask.get(eid, 0)
			if (emask & req_mask) == req_mask and (emask & exc_mask) == 0:
				result.append(node)

	_matching_nodes_cache[key] = result
	return result
