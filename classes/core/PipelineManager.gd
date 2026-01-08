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

func _get_pipeline_class_components(pipeline_class: Script) -> Dictionary:
	var result = {
		"requires": [],
		"optional": [],
		"exclude": []
	}
	var method_list = pipeline_class.get_script_method_list()
	for method in method_list:
		if method.name == "_requires":
			result["requires"] = pipeline_class._requires()
		elif method.name == "_optional":
			result["optional"] = pipeline_class._optional()
		elif method.name == "_exclude":
			result["exclude"] = pipeline_class._exclude()
	return result

func register_pipeline(pipeline_class: Script) -> void:
	var name = pipeline_class.get_global_name()
	var stages = {}

	# first try to get explicit stage list
	if pipeline_class.has_method("_stages"):
		var stage_methods = pipeline_class._stages()
		for stage_method in stage_methods:
			var stage_name = name + "." + str(stage_method.get_method())
			stages[stage_name] = [stage_method]
	
	# fallback to magic stage detection
	else:
		for m in pipeline_class.get_script_method_list():
			if m.name.begins_with("_stage_"):
				var stage_name = name + "." + m.name
				stages[stage_name] = [Callable(pipeline_class, m.name)]

	# create pipeline definition
	var components = _get_pipeline_class_components(pipeline_class)
	pipelines[name] = {
		"stages": stages.duplicate(true),
		"requires": components["requires"].duplicate(),
		"optional": components["optional"].duplicate(),
		"exclude": components["exclude"].duplicate(),
	}

func inject_pipeline(injected_fn_or_pipeline, target_callable: Callable, before: bool = false, priority: int = 0) -> void:
	var pipeline_class_name = target_callable.get_object().get_global_name()
	var stage_func = pipeline_class_name + "." + target_callable.get_method()
	if pipelines.has(pipeline_class_name):
		if not pipelines[pipeline_class_name]["stages"].has(stage_func):
			pipelines[pipeline_class_name]["stages"][stage_func] = []
		if before:
			pipelines[pipeline_class_name]["stages"][stage_func].insert(priority, injected_fn_or_pipeline)
		else:
			pipelines[pipeline_class_name]["stages"][stage_func].append(injected_fn_or_pipeline)

func deregister_pipeline(pipeline_class: Script) -> void:
	var name = pipeline_class.get_global_name()
	if pipelines.has(name):
		pipelines.erase(name)

func uninject_pipeline(injected_fn_or_pipeline, target_callable: Callable) -> void:
	var pipeline_class_name = target_callable.get_object().get_global_name()
	var stage_func = pipeline_class_name + "." + target_callable.get_method()
	if pipelines.has(pipeline_class_name):
		if pipelines[pipeline_class_name]["stages"].has(stage_func):
			pipelines[pipeline_class_name]["stages"][stage_func].erase(injected_fn_or_pipeline)

func _create_context_from_node(world: Object, node: Node, components: Array, component_registry: ComponentRegistry) -> PipelineContext:
	var context := PipelineContext.new()
	context.world = world
	for comp in components:
		var instance = component_registry.get_component(node, comp.get_global_name())
		if instance != null:
			context.components[comp.get_global_name()] = instance
	context.payload = null
	context.result = PipelineResult.new()
	context.result.reset()
	return context

func _call_stage_or_pipeline(stage_or_pipeline, node: Node, context: PipelineContext, component_registry: ComponentRegistry, world: Object) -> void:
	if typeof(stage_or_pipeline) == TYPE_CALLABLE:
		stage_or_pipeline.call(context)
	elif typeof(stage_or_pipeline) == TYPE_OBJECT and stage_or_pipeline is Script:
		var pipeline_name = stage_or_pipeline.get_global_name()
		var requires = pipelines[pipeline_name]["requires"]
		var optional = pipelines[pipeline_name]["optional"]
		var exclude = pipelines[pipeline_name]["exclude"]
		if not component_registry.components_match(node, requires, exclude):
			context.result.noop()
			return
		var sub_result = self.run(stage_or_pipeline, node, component_registry, world, context.payload, context)
		if sub_result.result.state != PipelineResult.SUCCESS:
			context.result = sub_result.result
			return
		var add_ctx = _create_context_from_node(world, node, requires + optional, component_registry)
		for key in add_ctx.components.keys():
			context.components[key] = add_ctx.components[key]

func run(pipeline_class: Script, node: Node, component_registry: ComponentRegistry, world: Object, payload = null, context_override = null) -> Dictionary:
	var pipeline_name = pipeline_class.get_global_name()
	if not pipelines.has(pipeline_name):
		return {"context": null, "result": PipelineResult.new()}
	var requires = pipelines[pipeline_name]["requires"]
	var optional = pipelines[pipeline_name]["optional"]
	var exclude = pipelines[pipeline_name]["exclude"]
	if not component_registry.components_match(node, requires, exclude):
		var result_fail = PipelineResult.new()
		result_fail.noop()
		return {"context": null, "result": result_fail}
	var stages = pipelines[pipeline_name]["stages"]
	var context = context_override
	if context_override == null:
		context = _create_context_from_node(world, node, requires + optional, component_registry)
	context.result.reset()
	if payload != null:
		context.payload = payload
	for stage in stages.keys():
		if context.result.state != PipelineResult.SUCCESS:
			break
		for fn_or_pipe in stages[stage]:
			_call_stage_or_pipeline(fn_or_pipe, node, context, component_registry, world)
			if context.result.state != PipelineResult.SUCCESS:
				break
		if context.result.state != PipelineResult.SUCCESS:
			break
	return {"context": context, "result": context.result}
