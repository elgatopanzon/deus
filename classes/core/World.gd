######################################################################
# @author      : ElGatoPanzon
# @class       : World
# @created     : Wednesday Jan 07, 2026 13:02:21 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : main World object holding pipelines and components
######################################################################

class_name World
extends Node

var component_registry
var pipeline_manager
var node_registry

static var instance: World

var delta: float
var delta_fixed: float

func _init():
	component_registry = ComponentRegistry.new()
	pipeline_manager = PipelineManager.new()
	node_registry = NodeRegistry.new()

	add_child(node_registry)

	# register world pipelines
	register_pipeline(WorldUpdatePipeline)
	register_pipeline(WorldFixedUpdatePipeline)

	instance = self


func _enter_tree():
	get_tree().connect("node_removed", _on_node_removed)

func _on_node_removed(node: Node):
	component_registry.remove_all_components(node)

func _process(_delta):
	delta = _delta
	execute_pipeline(WorldUpdatePipeline, self)

func _physics_process(_delta):
	delta_fixed = _delta
	execute_pipeline(WorldFixedUpdatePipeline, self)

# node methods
func _get(property):
	# try by name
	var node = get_node_by_name(property)
	if node:
		return node
	# try by id
	node = get_nodes_by_id(property)
	if node:
		return node

	return null

# search helper functions remain unchanged
func get_node_by_name(_name):
	return node_registry.get_nodes_by_name(_name)

func get_nodes_by_type(_type) -> Array:
	return node_registry.get_nodes_by_type(_type)

func get_nodes_by_group(_group) -> Array:
	return node_registry.get_nodes_by_group(_group)

func get_nodes_by_id(_id) -> Array:
	return node_registry.get_nodes_by_id(_id)

# component methods
func set_component(node: Node, comp: Script, component: Resource) -> void:
	component_registry.set_component(node, comp.get_global_name(), component)

func get_component(node: Node, component_class: Script) -> Resource:
	return component_registry.get_component(node, component_class.get_global_name())

func has_component(node: Node, component_class: Script) -> bool:
	return component_registry.has_component(node, component_class.get_global_name())

func remove_component(node: Node, component_class: Script) -> void:
	component_registry.remove_component(node, component_class.get_global_name())

# pipeline methods
func register_pipeline(pipeline_class: Script) -> void:
	pipeline_manager.register_pipeline(pipeline_class)

func register_oneshot_pipeline(pipeline_class: Script, deregister_on_results: Array[String]) -> void:
	pipeline_manager.register_pipeline(pipeline_class)
	pipeline_manager.set_pipeline_as_oneshot(pipeline_class, deregister_on_results)

func deregister_pipeline(pipeline_class: Script) -> void:
	pipeline_manager.deregister_pipeline(pipeline_class)

func inject_pipeline(injected_fn_or_pipeline, target_callable: Callable, before: bool = false, priority: int = 0) -> void:
	pipeline_manager.inject_pipeline(injected_fn_or_pipeline, target_callable, before, priority)

func inject_pipeline_result_handler(existing_pipeline, target_pipeline, result_states := []) -> void:
	pipeline_manager.inject_pipeline_result_handler(existing_pipeline, target_pipeline, result_states)

func uninject_pipeline(injected_fn_or_pipeline, target_callable: Callable) -> void:
	pipeline_manager.uninject_pipeline(injected_fn_or_pipeline, target_callable)

func pipeline_set_oneshot(pipeline_class: Script, deregister_on_results: Array[String]) -> void:
	pipeline_manager.set_pipeline_as_oneshot(pipeline_class, deregister_on_results)

func execute_pipeline(pipeline_class: Script, node: Node, payload = null, context_override = null) -> Dictionary:
	return pipeline_manager.run(pipeline_class, node, component_registry, self, payload, context_override)

func execute_global_pipeline(pipeline_class: Script, payload = null, context_override = null) -> Dictionary:
	var pipeline_info = pipeline_manager.pipelines.get(pipeline_class.get_global_name())
	if pipeline_info == null:
		return {}
	var requires = pipeline_info["requires"]
	var exclude = pipeline_info["exclude"]
	var nodes = component_registry.get_matching_nodes(requires, exclude)
	var node_results = {}
	for node in nodes:
		var ret = pipeline_manager.run(pipeline_class, node, component_registry, self, payload, context_override)
		node_results[node] = ret.result
	return node_results
