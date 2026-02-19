######################################################################
# @author      : ElGatoPanzon
# @class       : PipelineContext
# @created     : Wednesday Jan 07, 2026 12:56:44 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : context object for use with pipeline execution
######################################################################

class_name PipelineContext
extends Resource

class NodePropertyCache:
	var _node
	var _cache = {}
	var _child_node_caches = {}
	
	func _init(node):
		_node = node
	
	func _get(property):
		# only clone if not already cloned
		if property in _node:
			if not _cache.has(property):
				_cache[property] = {"value": _clone_property(property), "_dirty": false}
			return _cache[property]["value"]
		# resolve child node and create instance
		else:
			var child = _resolve_child_node(property)
			if child != null:
				return _get_child_node_cache(child)

		return null

	func _resolve_child_node(node_string):
		# try name
		var node = _node.get_node_or_null(str(node_string))
		if node:
			return node
		# try type
		for child in _node.get_children():
			if str(child.get_class()) == node_string:
				return child
		return null

	func _get_child_node_cache(child):
		if not _child_node_caches.has(child):
			_child_node_caches[child] = NodePropertyCache.new(child)

		return _child_node_caches[child]
	
	func _set(property, value):
		var original_value = _node.get(property)
		if typeof(original_value) == typeof(value):
			if not _cache.has(property):
				_cache[property] = {"value": value, "_dirty": true}
			else:
				_cache[property]["value"] = value
				_cache[property]["_dirty"] = true
			return

	func _clone_property(property):
		var value = _node.get(property)
		if value != null and typeof(value) == TYPE_OBJECT and value.has_method("duplicate"):
			return value.duplicate()

		# return primitives as-is
		return value
	
	func commit():
		for prop in _cache.keys():
			if _cache[prop]["_dirty"]:
				_node.set(prop, _cache[prop]["value"])
				_cache[prop]["_dirty"] = false

	func reset():
		_node = null
		_cache.clear()
		_child_node_caches.clear()

var _node:
	set(value):
		_node = value
		if node_property_cache:
			node_property_cache._node = value
var world
var components = {}
var payload
var result

# lazy clone support: original_components holds raw refs from SparseSet,
# components is populated lazily on first access with cloned copies
var original_components = {}

var _entity_id: int = -1

var node_property_cache
var _property_dict = {}

func _init():
	result = PipelineResult.new()
	node_property_cache = NodePropertyCache.new(null)

func _get(property):
	# component write buffer hit (2nd+ access) -- hottest path, check first
	if components.has(property):
		return components[property]
	# lazy clone: component in originals but not yet cloned
	if original_components.has(property):
		var clone = original_components[property].smart_duplicate()
		components[property] = clone
		return clone
	# ReadOnly prefix: return original component ref without cloning.
	# This is a foot-gun by design -- mutations go straight to the registry.
	if property is StringName and property.begins_with(&"ReadOnly"):
		var real_name = property.substr(8)
		if original_components.has(real_name):
			return original_components[real_name]
		return null
	# backing dictionary for arbitrary properties set via _set
	if _property_dict.has(property):
		return _property_dict[property]
	# node property or child node resolution
	return node_property_cache._get(property)

func _set(property, value):
	# set property to the backing dictionary 
	_property_dict[property] = value
	return true

func reset():
	_node = null
	world = null
	_entity_id = -1
	components.clear()
	original_components.clear()
	payload = null
	# result is NOT reset here -- callers may still hold a reference to it
	# from the return dict. It gets reset on next acquire in _create_context_from_node.
	node_property_cache.reset()
	_property_dict.clear()

func has_pending_writes() -> bool:
	return components.size() > 0 or node_property_cache._cache.size() > 0

func _commit_node_properties():
	node_property_cache.commit()
