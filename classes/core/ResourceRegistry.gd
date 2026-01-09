######################################################################
# @author      : ElGatoPanzon
# @class       : ResourceRegistry
# @created     : Friday Jan 09, 2026 14:37:22 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : store Resource types with friendly IDs on Node instances
######################################################################

class_name ResourceRegistry
extends Node

# this dictionary holds resources for each node, mapped by a string id
var _resources := {}

# registers a resource with a node and a friendly id
func register_resource(node: Node, resource: Resource, resource_id: String) -> void:
	if not _resources.has(node):
		_resources[node] = {}
	_resources[node][resource_id] = resource

# gets a registered resource by node and id, returns null if not found
func get_resource(node: Node, resource_id: String) -> Resource:
	if _resources.has(node):
		return _resources[node].get(resource_id, null)
	return null

# removes a resource
func unregister_resource(node: Node, resource_id: String) -> void:
	if _resources.has(node):
		_resources[node].erase(resource_id)
		if _resources[node].is_empty():
			_resources.erase(node)

# removes all resources for a node
func unregister_all_resources(node: Node) -> void:
	_resources.erase(node)
