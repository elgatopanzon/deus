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

signal pipeline_registered(pipeline_class, pipeline)
signal pipeline_deregistered(pipeline_class)
signal pipeline_injected(pipeline_class, injected_class, injected_stage)
signal pipeline_result_handler_injected(pipeline_class, injected_class, result_states)
signal pipeline_uninjected(pipeline_class, injected_class, injected_stage)
signal pipeline_executing(pipeline_class, target, payload)
signal pipeline_executed(pipeline_class, target, payload)

var pipelines = {}

# dictionary to hold result handlers for pipelines
var pipeline_result_handlers = {}

# pre-resolved Script -> pipeline data cache for injected pipelines
# avoids get_global_name() + dictionary lookups in the hot path
var _resolved_injections: Dictionary = {}

# pre-grouped result handlers: Script -> { state_string -> [handler_pipeline_Script, ...] }
# avoids get_global_name(), string-keyed dict lookup, and per-handler state scan in hot path
var _resolved_result_handlers: Dictionary = {}

# pool of reusable PipelineContext objects to avoid per-run allocation
var _context_pool: Array = []

var _world: DeusWorld

func _init(world: DeusWorld):
	_world = world

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
	if pipelines.has(name):
		return

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
	var stage_data = stages.duplicate(true)
	pipelines[name] = {
		"stages": stage_data,
		"_stage_keys": stage_data.keys(),
		"requires": components["requires"].duplicate(),
		"optional": components["optional"].duplicate(),
		"exclude": components["exclude"].duplicate(),
		"require_nodes": components["require_nodes"].duplicate(),
		"exclude_nodes": components["exclude_nodes"].duplicate(),
	}

	# cache Script -> data for injection pre-resolution
	_resolved_injections[pipeline_class] = pipelines[name]

	pipeline_registered.emit(pipeline_class, pipelines[name])

# injects a function or pipeline before/after a target stage
func inject_pipeline(injected_fn_or_pipeline, target_callable: Callable, before: bool = false, priority: int = 0) -> void:
	for script in [injected_fn_or_pipeline.get_global_name(), target_callable.get_object().get_global_name()]:
		if not pipelines.has(script):
			register_pipeline(injected_fn_or_pipeline if script == injected_fn_or_pipeline.get_global_name() else target_callable.get_object())

	var pipeline_class_name = target_callable.get_object().get_global_name()
	var stage_func = pipeline_class_name + "." + target_callable.get_method()
	if pipelines.has(pipeline_class_name):
		var had_stage = pipelines[pipeline_class_name]["stages"].has(stage_func)
		if not had_stage:
			pipelines[pipeline_class_name]["stages"][stage_func] = []
		# Idempotency guard — prevent duplicate injection on scene reload
		if injected_fn_or_pipeline in pipelines[pipeline_class_name]["stages"][stage_func]:
			return
		if before:
			pipelines[pipeline_class_name]["stages"][stage_func].insert(priority, injected_fn_or_pipeline)
		else:
			pipelines[pipeline_class_name]["stages"][stage_func].append(injected_fn_or_pipeline)
		# rebuild cached stage keys when a new stage was added
		if not had_stage:
			pipelines[pipeline_class_name]["_stage_keys"] = pipelines[pipeline_class_name]["stages"].keys()

		pipeline_injected.emit(injected_fn_or_pipeline, target_callable.get_object(), target_callable)

# remove a pipeline and its result handlers from the registry
func deregister_pipeline(pipeline_class: Script) -> void:
	var name = pipeline_class.get_global_name()
	if pipelines.has(name):
		pipelines.erase(name)
		pipeline_result_handlers.erase(name)
		_resolved_injections.erase(pipeline_class)
		_resolved_result_handlers.erase(pipeline_class)

		pipeline_deregistered.emit(pipeline_class)

# removes an injected pipeline/function from a stage
func uninject_pipeline(injected_fn_or_pipeline, target_callable: Callable) -> void:
	var pipeline_class_name = target_callable.get_object().get_global_name()
	var stage_func = pipeline_class_name + "." + target_callable.get_method()
	if pipelines.has(pipeline_class_name):
		pipelines[pipeline_class_name]["stages"].get(stage_func, []).erase(injected_fn_or_pipeline)

		pipeline_uninjected.emit(injected_fn_or_pipeline, target_callable.get_object(), target_callable)

# enable one-shot mode on a pipeline to deregister it after running once
func set_pipeline_as_oneshot(pipeline_class: Script, deregister_on_results: Array[String]) -> void:
	var name = pipeline_class.get_global_name()
	if pipelines.has(name):
		pipelines[name]["oneshot"] = deregister_on_results.duplicate()

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

# applies buffered components to a node via registry
# Skips set_component pipeline when buffered value matches current SparseSet value
# Uses direct SparseSet access to avoid _get_sparse_set dictionary lookup per key
func _commit_buffered_components(context: PipelineContext, node: Node):
	var registry = _world.component_registry
	var entity_id = registry._ensure_entity_id(node)
	var comp_sets = registry.component_sets
	for key in context.components.keys():
		var ss = comp_sets.get(key)
		var current = ss.get_value(entity_id) if ss != null else null
		if current != null and registry._deep_compare_component(current, context.components[key]):
			continue
		# mark dirty so _update_existing_component skips redundant deep compare
		context.components[key]._dirty = true
		registry.set_component(node, key, context.components[key])

# calls function or runs pipeline during stage execution
# uses _resolved_injections cache to skip get_global_name() and dict lookups
func _call_stage_or_pipeline(stage_or_pipeline, node: Node, context: PipelineContext) -> void:
	if typeof(stage_or_pipeline) == TYPE_CALLABLE:
		var res = stage_or_pipeline.call(context)
		if not null and res == false:
			context.result.cancel("stage %s returned false" % stage_or_pipeline.get_method())

	elif typeof(stage_or_pipeline) == TYPE_OBJECT and stage_or_pipeline is Script:
		var data = _resolved_injections.get(stage_or_pipeline)
		if data == null:
			return
		if not _world.component_registry.components_match(node, data["requires"], data["exclude"]) or not _nodes_match(node, data["require_nodes"], data["exclude_nodes"]):
			context.result.noop("Components or nodes missing/excluded")
			return
		var sub_result = self.run(stage_or_pipeline, node, context.payload, context, data)
		if sub_result.result.state != PipelineResult.SUCCESS:
			context.result = sub_result.result
			return
		for key in sub_result.context.components.keys():
			context.components[key] = sub_result.context.components[key]

# acquires a PipelineContext from the pool or creates a new one
func _acquire_context() -> PipelineContext:
	if _context_pool.size() > 0:
		return _context_pool.pop_back()
	var ctx = PipelineContext.new()
	ctx.result = PipelineResult.new()
	return ctx

# returns a PipelineContext to the pool for reuse
func _release_context(context: PipelineContext) -> void:
	context.reset()
	_context_pool.push_back(context)

# creates processing context for a node and its components
# uses direct SparseSet access to bypass GetComponentPipeline overhead
func _create_context_from_node(node: Node, components: Array) -> PipelineContext:
	var context := _acquire_context()
	context.world = _world
	var registry = _world.component_registry
	var entity_id = registry._ensure_entity_id(node)
	for comp in components:
		var comp_name = comp.get_global_name()
		var comp_value = registry.get_component_direct(entity_id, comp_name)
		if comp_value != null:
			context.components[comp_name] = comp_value
	context.payload = null
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

	# populate pre-grouped Script -> state -> handlers cache
	if not _resolved_result_handlers.has(parent_pipeline):
		_resolved_result_handlers[parent_pipeline] = {}
	var by_state: Dictionary = _resolved_result_handlers[parent_pipeline]
	for state in result_states:
		if not by_state.has(state):
			by_state[state] = []
		by_state[state].append(handler_pipeline)

	pipeline_result_handler_injected.emit(parent_pipeline, handler_pipeline, result_states)

# run all result handler pipelines associated with a given result state
# uses pre-grouped Script -> state -> handlers cache for direct dispatch
func _run_result_handlers(pipeline_class: Script, node: Node, context: PipelineContext, result_state) -> void:
	var by_state: Dictionary = _resolved_result_handlers.get(pipeline_class, {})
	var handlers: Array = by_state.get(result_state, [])
	for handler_pipeline in handlers:
		self.run(handler_pipeline, node, context.payload if context else null, context)

# main pipeline run logic
# _data_override skips get_global_name() + dict lookup when caller already has data;
# when set, component matching was already verified by the caller
func run(pipeline_class: Script, node: Node, payload = null, context_override = null, _data_override = null) -> Dictionary:
	var data = _data_override
	if data == null:
		var pipeline_name = pipeline_class.get_global_name()
		if not pipelines.has(pipeline_name):
			return {"context": null, "result": PipelineResult.new()}
		data = pipelines[pipeline_name]
		if not _world.component_registry.components_match(node, data["requires"], data["exclude"]) or not _nodes_match(node, data["require_nodes"], data["exclude_nodes"]):
			var result_fail = PipelineResult.new()
			result_fail.noop("Components or nodes missing/excluded")
			_run_result_handlers(pipeline_class, node, null, result_fail.state)
			return {"context": null, "result": result_fail}

	pipeline_executing.emit(pipeline_class, node, payload)

	var context = context_override
	var is_root_pipeline = false
	if context_override == null:
		context = _create_context_from_node(node, data["requires"] + data["optional"])
		is_root_pipeline = true
	context.result.reset()
	if payload != null:
		context.payload = payload

	for stage in data["_stage_keys"]:
		if context.result.state != PipelineResult.SUCCESS:
			break
		for fn_or_pipe in data["stages"][stage]:
			_call_stage_or_pipeline(fn_or_pipe, node, context)
			if context.result.state != PipelineResult.SUCCESS:
				break
		if context.result.state != PipelineResult.SUCCESS:
			break

	if is_root_pipeline and context.result.state == PipelineResult.SUCCESS:
		_commit_buffered_components(context, node)
		context._commit_node_properties()

	# handle one-shot pipeline deregistration
	if data.get("oneshot", null) and (context.result.state in data["oneshot"] or data["oneshot"].size() == 0):
		deregister_pipeline(pipeline_class)
		context.result.deregistered()

	_run_result_handlers(pipeline_class, node, context, context.result.state)

	pipeline_executed.emit(pipeline_class, node, payload, context.result)

	# Note: we do NOT release the context to the pool here. The caller holds a
	# reference to the returned context and may access its components/properties.
	# Releasing would reset the context while the caller still holds it, causing
	# nil access errors. Root pipeline contexts are not pooled; only sub-contexts
	# created during nested pipeline runs (which never escape the run() call)
	# would benefit from pooling, but that requires a different pattern.
	return {"context": context, "result": context.result}

# batch-execute a pipeline over multiple pre-matched nodes
# creates a fresh context per entity so lambda captures on context.world remain valid after the loop.
# returns node -> PipelineResult matching the single-node run() contract.
func run_batch(pipeline_class: Script, nodes: Array, data: Dictionary, payload = null) -> Dictionary:
	var registry = _world.component_registry
	var all_comps = data["requires"] + data["optional"]
	var stage_keys = data["_stage_keys"]
	var stages = data["stages"]
	var is_oneshot = data.get("oneshot", null)

	var node_results = {}
	for node in nodes:
		var context := PipelineContext.new()
		context.world = _world
		# populate context for this entity (inline _create_context_from_node)
		var entity_id = registry._ensure_entity_id(node)
		for comp in all_comps:
			var comp_name = comp.get_global_name()
			var comp_value = registry.get_component_direct(entity_id, comp_name)
			if comp_value != null:
				context.components[comp_name] = comp_value
		context.payload = payload
		context._node = node

		pipeline_executing.emit(pipeline_class, node, payload)

		# stage execution loop
		for stage in stage_keys:
			if context.result.state != PipelineResult.SUCCESS:
				break
			for fn_or_pipe in stages[stage]:
				_call_stage_or_pipeline(fn_or_pipe, node, context)
				if context.result.state != PipelineResult.SUCCESS:
					break
			if context.result.state != PipelineResult.SUCCESS:
				break

		# commit buffered components on success
		if context.result.state == PipelineResult.SUCCESS:
			_commit_buffered_components(context, node)
			context._commit_node_properties()

		# oneshot deregistration
		if is_oneshot and (context.result.state in is_oneshot or is_oneshot.size() == 0):
			deregister_pipeline(pipeline_class)
			context.result.deregistered()

		_run_result_handlers(pipeline_class, node, context, context.result.state)

		pipeline_executed.emit(pipeline_class, node, payload, context.result)

		node_results[node] = context.result

	return node_results
