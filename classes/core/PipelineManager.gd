######################################################################
# @author      : ElGatoPanzon
# @class       : PipelineManager
# @created     : Wednesday Jan 07, 2026 13:01:06 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : register, inject and execute pipelines
######################################################################

class_name PipelineManager
extends Resource

var pipelines = {}

# dictionary to hold result handlers for pipelines
var pipeline_result_handlers = {}

# retrieves pipeline components and their types
func _get_pipeline_class_components(pipeline_class: Script) -> Dictionary:
	var result = {
		"requires": [],
		"optional": [],
		"exclude": [],
		"require_nodes": [],
		"exclude_nodes": []
	}
	var method_list = pipeline_class.get_script_method_list()
	for method in method_list:
		match method.name:
			"_requires":
				result["requires"] = pipeline_class._requires()
			"_optional":
				result["optional"] = pipeline_class._optional()
			"_exclude":
				result["exclude"] = pipeline_class._exclude()
			"_require_nodes":
				result["require_nodes"] = _class_type_array_to_string_array(pipeline_class._require_nodes())
			"_exclude_nodes":
				result["exclude_nodes"] = _class_type_array_to_string_array(pipeline_class._exclude_nodes())
	return result

# converts an array of types/classes to array of strings
func _class_type_array_to_string_array(arr: Array) -> Array:
	var result = []
	for item in arr:
		var iset = []
		if typeof(item) != TYPE_ARRAY:
			iset.append(_type_to_string(item))
		else:
			for set_item in item:
				iset.append(_type_to_string(set_item))
		result.append(iset)
	return result

# converts a type or class object to a string
func _type_to_string(item):
	if typeof(item) == TYPE_OBJECT and item is Script:
		return item.get_global_name()
	elif typeof(item) == TYPE_OBJECT:
		return item.new().get_class()
	else:
		return str(item)

# registers the pipeline and its stage methods
func register_pipeline(pipeline_class: Script) -> void:
	var name = pipeline_class.get_global_name()
	var stages = {}

	if pipeline_class.has_method("_stages"):
		for stage_method in pipeline_class._stages():
			var stage_name = name + "." + str(stage_method.get_method())
			stages[stage_name] = [stage_method]
	else:
		for m in pipeline_class.get_script_method_list():
			if m.name.begins_with("_stage_"):
				var stage_name = name + "." + m.name
				stages[stage_name] = [Callable(pipeline_class, m.name)]

	var components = _get_pipeline_class_components(pipeline_class)
	pipelines[name] = {
		"stages": stages.duplicate(true),
		"requires": components["requires"].duplicate(),
		"optional": components["optional"].duplicate(),
		"exclude": components["exclude"].duplicate(),
		"require_nodes": components["require_nodes"].duplicate(),
		"exclude_nodes": components["exclude_nodes"].duplicate(),
	}

# injects a function or pipeline before/after a target stage
func inject_pipeline(injected_fn_or_pipeline, target_callable: Callable, before: bool = false, priority: int = 0) -> void:
	for script in [injected_fn_or_pipeline.get_global_name(), target_callable.get_object().get_global_name()]:
		if not pipelines.has(script):
			register_pipeline(injected_fn_or_pipeline if script == injected_fn_or_pipeline.get_global_name() else target_callable.get_object())

	var pipeline_class_name = target_callable.get_object().get_global_name()
	var stage_func = pipeline_class_name + "." + target_callable.get_method()
	if pipelines.has(pipeline_class_name):
		if not pipelines[pipeline_class_name]["stages"].has(stage_func):
			pipelines[pipeline_class_name]["stages"][stage_func] = []
		if before:
			pipelines[pipeline_class_name]["stages"][stage_func].insert(priority, injected_fn_or_pipeline)
		else:
			pipelines[pipeline_class_name]["stages"][stage_func].append(injected_fn_or_pipeline)

# remove a pipeline and its result handlers from the registry
func deregister_pipeline(pipeline_class: Script) -> void:
	var name = pipeline_class.get_global_name()
	pipelines.erase(name)
	pipeline_result_handlers.erase(name)

# removes an injected pipeline/function from a stage
func uninject_pipeline(injected_fn_or_pipeline, target_callable: Callable) -> void:
	var pipeline_class_name = target_callable.get_object().get_global_name()
	var stage_func = pipeline_class_name + "." + target_callable.get_method()
	if pipelines.has(pipeline_class_name):
		pipelines[pipeline_class_name]["stages"].get(stage_func, []).erase(injected_fn_or_pipeline)

# nodes matching helpers
func _matches_node_type_or_name(node: Node, sets: Array) -> bool:
	for i in sets.size():
		var entry = sets[i]
		var found = false
		for set_entry in entry:
			if i == 0:
				if typeof(set_entry) == TYPE_STRING and (node.name == set_entry or node.get_class() == set_entry):
					found = true
			else:
				for child in node.get_children():
					if typeof(set_entry) == TYPE_STRING and (child.name == set_entry or child.get_class() == set_entry):
						found = true
						break
		if not found:
			return false
	return true

func _nodes_match(node: Node, require: Array, exclude: Array) -> bool:
	if require.size() > 0 and not _matches_node_type_or_name(node, require):
		return false
	if exclude.size() > 0 and _matches_node_type_or_name(node, exclude):
		return false
	return true

# deep duplicates a component if possible
func _duplicate_component(component):
	if component is Resource:
		return component.duplicate()
	elif component.has_method("duplicate"):
		return component.duplicate()
	else:
		return component

# applies buffered components to a node via registry
func _commit_buffered_components(context: PipelineContext, node: Node, component_registry: ComponentRegistry):
	for key in context.components.keys():
		component_registry.set_component(node, key, context.components[key])

# calls function or runs pipeline during stage execution
func _call_stage_or_pipeline(stage_or_pipeline, node: Node, context: PipelineContext, component_registry: ComponentRegistry, world: Object) -> void:
	if typeof(stage_or_pipeline) == TYPE_CALLABLE:
		stage_or_pipeline.call(context)
	elif typeof(stage_or_pipeline) == TYPE_OBJECT and stage_or_pipeline is Script:
		var pipeline_name = stage_or_pipeline.get_global_name()
		var data = pipelines[pipeline_name]
		if not component_registry.components_match(node, data["requires"], data["exclude"]) or not _nodes_match(node, data["require_nodes"], data["exclude_nodes"]):
			context.result.noop("Components or nodes missing/excluded")
			return
		var sub_result = self.run(stage_or_pipeline, node, component_registry, world, context.payload, context)
		if sub_result.result.state != PipelineResult.SUCCESS:
			context.result = sub_result.result
			return
		for key in sub_result.context.components.keys():
			context.components[key] = sub_result.context.components[key]

# creates processing context for a node and its components
func _create_context_from_node(world: Object, node: Node, components: Array, component_registry: ComponentRegistry) -> PipelineContext:
	var context := PipelineContext.new()
	context.world = world
	for comp in components:
		var instance = component_registry.get_component(node, comp.get_global_name())
		if instance != null:
			context.components[comp.get_global_name()] = _duplicate_component(instance)
	context.payload = null
	context.result = PipelineResult.new()
	context.result.reset()
	context._node = node
	return context

# attach a handler pipeline for particular result states in a parent pipeline
func inject_pipeline_result_handler(parent_pipeline: Script, handler_pipeline: Script, result_states: Array) -> void:
	for pipeline in [parent_pipeline, handler_pipeline]:
		if not pipelines.has(pipeline.get_global_name()):
			register_pipeline(pipeline)
	var parent_name = parent_pipeline.get_global_name()
	if not pipeline_result_handlers.has(parent_name):
		pipeline_result_handlers[parent_name] = []
	pipeline_result_handlers[parent_name].append({
		"handler_pipeline": handler_pipeline,
		"result_states": result_states.duplicate()
	})

# run all result handler pipelines associated with a given result state
func _run_result_handlers(pipeline_class: Script, node: Node, component_registry: ComponentRegistry, world: Object, context: PipelineContext, result_state) -> void:
	var name = pipeline_class.get_global_name()
	if pipeline_result_handlers.has(name):
		for handler in pipeline_result_handlers[name]:
			if handler.result_states.has(result_state):
				self.run(handler.handler_pipeline, node, component_registry, world, context.payload, context)

# main pipeline run logic
func run(pipeline_class: Script, node: Node, component_registry: ComponentRegistry, world: Object, payload = null, context_override = null) -> Dictionary:
	var pipeline_name = pipeline_class.get_global_name()
	if not pipelines.has(pipeline_name):
		return {"context": null, "result": PipelineResult.new()}
	var data = pipelines[pipeline_name]
	if not component_registry.components_match(node, data["requires"], data["exclude"]) or not _nodes_match(node, data["require_nodes"], data["exclude_nodes"]):
		var result_fail = PipelineResult.new()
		result_fail.noop("Components or nodes missing/excluded")
		_run_result_handlers(pipeline_class, node, component_registry, world, null, result_fail.state)
		return {"context": null, "result": result_fail}

	var context = context_override
	var is_root_pipeline = false
	if context_override == null:
		context = _create_context_from_node(world, node, data["requires"] + data["optional"], component_registry)
		is_root_pipeline = true
	context.result.reset()
	if payload != null:
		context.payload = payload

	for stage in data["stages"].keys():
		if context.result.state != PipelineResult.SUCCESS:
			break
		for fn_or_pipe in data["stages"][stage]:
			_call_stage_or_pipeline(fn_or_pipe, node, context, component_registry, world)
			if context.result.state != PipelineResult.SUCCESS:
				break
		if context.result.state != PipelineResult.SUCCESS:
			break

	if is_root_pipeline and context.result.state == PipelineResult.SUCCESS:
		_commit_buffered_components(context, node, component_registry)
		context._commit_node_properties()

	_run_result_handlers(pipeline_class, node, component_registry, world, context, context.result.state)

	return {"context": context, "result": context.result}
