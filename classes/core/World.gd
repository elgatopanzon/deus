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

static var instance: World

var delta: float
var delta_fixed: float

func _init():
	component_registry = ComponentRegistry.new()
	pipeline_manager = PipelineManager.new()

	# register world pipelines
	register_pipeline(WorldUpdatePipeline)
	register_pipeline(WorldFixedUpdatePipeline)

	instance = self


func _enter_tree():
	# scenetree listeners
	get_tree().connect("node_added", _on_node_added)
	get_tree().connect("node_removed", _on_node_removed)

func _on_node_added(node: Node):
	print("node added to scenetree: %s: %s" % [node.name, node.get_path()])

func _on_node_removed(node: Node):
	print("node removed frome scenetree: %s: %s" % [node.name, node.get_path()])

func _process(_delta):
	delta = _delta
	execute_pipeline(WorldUpdatePipeline, self)

func _physics_process(_delta):
	delta_fixed = _delta
	execute_pipeline(WorldFixedUpdatePipeline, self)

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

func deregister_pipeline(pipeline_class: Script) -> void:
	pipeline_manager.deregister_pipeline(pipeline_class)

func inject_pipeline(injected_fn_or_pipeline, target_callable: Callable, before: bool = false, priority: int = 0) -> void:
	pipeline_manager.inject_pipeline(injected_fn_or_pipeline, target_callable, before, priority)

func uninject_pipeline(injected_fn_or_pipeline, target_callable: Callable) -> void:
	pipeline_manager.uninject_pipeline(injected_fn_or_pipeline, target_callable)

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
