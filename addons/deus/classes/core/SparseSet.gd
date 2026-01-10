######################################################################
# @author      : ElGatoPanzon
# @class       : SparseSet
# @created     : Wednesday Jan 07, 2026 12:59:10 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : sparse set data structure accepting entity id as index
######################################################################

class_name SparseSet
extends Resource

var dense : Array = []
var sparse : Array = []
var data : Array = []

func add(entity_id: int, value):
	if entity_id >= sparse.size():
		var old_size = sparse.size()
		sparse.resize(entity_id + 1)
		for i in range(old_size, sparse.size()):
			sparse[i] = -1
	if self.has(entity_id):
		data[sparse[entity_id]] = value
		return
	sparse[entity_id] = dense.size()
	dense.append(entity_id)
	data.append(value)

func has(entity_id: int) -> bool:
	return entity_id < sparse.size() and sparse[entity_id] != -1 and sparse[entity_id] < dense.size() and dense[sparse[entity_id]] == entity_id

func get_value(entity_id: int):
	if self.has(entity_id):
		return data[sparse[entity_id]]
	return null

func erase(entity_id: int):
	if not self.has(entity_id):
		return
	var index = sparse[entity_id]
	var last = dense.size() - 1
	var last_entity = dense[last]

	# swap with last
	dense[index] = dense[last]
	data[index] = data[last]
	sparse[last_entity] = index

	# remove last
	dense.resize(last)
	data.resize(last)
	sparse[entity_id] = -1
