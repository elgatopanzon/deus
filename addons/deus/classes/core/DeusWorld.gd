######################################################################
# @author      : ElGatoPanzon
# @class       : DeusWorld
# @created     : Wednesday Jan 07, 2026 13:02:21 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : main DeusWorld object holding pipelines and components
######################################################################

class_name DeusWorld
extends Node

var component_registry
var pipeline_manager
var node_registry
var resource_registry

static var instance: DeusWorld

var delta: float
var delta_fixed: float

func _init():
	DeusConfig.init_project_config()

	component_registry = ComponentRegistry.new()
	pipeline_manager = PipelineManager.new()
	node_registry = NodeRegistry.new()
	resource_registry = ResourceRegistry.new()

	add_child(node_registry)

	# register world pipelines
	register_pipeline(WorldUpdatePipeline)
	register_pipeline(WorldFixedUpdatePipeline)
	register_pipeline(SetComponentPipeline)
	register_pipeline(GetComponentPipeline)

	instance = self


func _enter_tree():
	node_registry.connect("node_deregistered", _on_node_removed)

func _on_node_removed(node: Node, _node_name: String, _node_id: String):
	component_registry.remove_all_components(node)
	resource_registry.unregister_all_resources(node)

func _process(_delta):
	delta = _delta
	execute_pipeline(WorldUpdatePipeline, self)

func _physics_process(_delta):
	delta_fixed = _delta
	execute_pipeline(WorldFixedUpdatePipeline, self)

# node methods
func _get(property):
	return try_get_node(property)

# search helper functions remain unchanged
func get_node_by_name(_name):
	return node_registry.get_nodes_by_name(_name)

func get_nodes_by_type(_type) -> Array:
	return node_registry.get_nodes_by_type(_type)

func get_nodes_by_group(_group) -> Array:
	return node_registry.get_nodes_by_group(_group)

func get_node_by_id(_id) -> Node:
	return node_registry.get_node_by_id(_id)

func try_get_node(id):
	return node_registry.try_get_node(id)

func set_node_id(node: Node, id: String):
	node_registry.set_node_id(node, id)

# component methods
func set_component(node: Node, comp: Script, component: DefaultComponent) -> void:
	execute_pipeline(SetComponentPipeline, node, {"component_name": comp.get_global_name(), "component": component})
	

func get_component(node: Node, component_class: Script) -> DefaultComponent:
	var res = execute_pipeline(GetComponentPipeline, node, {"component_name": component_class.get_global_name()})
	if res.result.state == PipelineResult.SUCCESS:
		return res.result.value

	return null

func has_component(node: Node, component_class: Script) -> bool:
	return component_registry.has_component(node, component_class.get_global_name())

func remove_component(node: Node, component_class: Script) -> void:
	component_registry.remove_component(node, component_class.get_global_name())

# resource methods
func register_resource(node: Node, resource: Resource, resource_id: String) -> void:
	resource_registry.register_resource(node, resource, resource_id)

func get_resource(node: Node, resource_id: String) -> Resource:
	return resource_registry.get_resource(node, resource_id)

func unregister_resource(node: Node, resource_id: String) -> void:
	resource_registry.unregister_resource(node, resource_id)

func unregister_all_resources(node: Node) -> void:
	resource_registry.unregister_all_resources(node)

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

func signal_to_pipeline(connect_node, signal_name: String, target_node, pipeline_class: Script, flags: int = 0) -> void:
	register_pipeline(pipeline_class)

	node_registry.connect_signal_deferred(connect_node, signal_name,
		Callable(func(...args):
			var target_ = DeusWorld.instance.try_get_node(target_node)
			var connect_ = DeusWorld.instance.try_get_node(connect_node)
			if target_ and connect_:
				execute_pipeline(pipeline_class, target_, [connect_] + args)
				)
	, flags)

func signal_to_global_pipeline(connect_node, signal_name: String, pipeline_class: Script, flags: int = 0) -> void:
	register_pipeline(pipeline_class)

	node_registry.connect_signal_deferred(connect_node, "", signal_name,
		Callable(func(...args):
			var connect_ = DeusWorld.instance.try_get_node(connect_node)
			if connect_:
				execute_global_pipeline(pipeline_class, [connect_] + args)
				)
	, flags)
