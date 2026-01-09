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
	
	func _init(node):
		_node = node
	
	func _get(property):
		# only clone if not already cloned
		if not _cache.has(property):
			_cache[property] = {"value": _clone_property(property), "_dirty": false}
		return _cache[property]["value"]
	
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

var _node
var world
var components = {}
var payload
var result

var node_property_cache

func _init():
	node_property_cache = NodePropertyCache.new(_node)

func _get(property):
	node_property_cache._node = _node
	if property in _node:
		return node_property_cache._get(property)
	elif components.has(property):
		return components[property]
	else:
		return null

func commit_node_properties():
	node_property_cache.commit()
