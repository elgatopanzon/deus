extends Node2D

# custom context object for pipeline stages
class PipelineContext:
	var world
	var components = {}
	var payload
	var result

	# allows dot-access to components: context.CompName
	func _get(property):
		if components.has(property):
			return components[property]
		else:
			return null

# pipeline result state
class PipelineResult:
	const SUCCESS = "success"
	const FAILED = "failed"
	const CANCELLED = "cancelled"
	
	var state: String = SUCCESS
	var error_code: int = 0
	var error_message: String = ""
	
	func reset():
		state = SUCCESS
		error_code = 0
		error_message = ""

	func noop():
		state = SUCCESS

	func fail(code = 1, msg = ""):
		state = FAILED
		error_code = code
		error_message = msg

	func cancel(msg = ""):
		state = CANCELLED
		error_message = msg

class SparseSet:
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

class ComponentRegistry:
	var component_sets = {}
	var next_entity_id: int = 0
	var node_components = {} # keeps track of nodes and their components (by name)

	func _ensure_entity_id(node: Node) -> int:
		if not node.has_meta("entity_id"):
			node.set_meta("entity_id", next_entity_id)
			next_entity_id += 1
		return node.get_meta("entity_id")

	func _get_sparse_set(component_name: String) -> SparseSet:
		if not component_sets.has(component_name):
			component_sets[component_name] = SparseSet.new()
		return component_sets[component_name]

	func set_component(node: Node, component_name: String, component: Resource) -> void:
		var entity_id = _ensure_entity_id(node)
		var components = _get_sparse_set(component_name)
		components.add(entity_id, component)
		if not node_components.has(node):
			node_components[node] = []
		if component_name not in node_components[node]:
			node_components[node].append(component_name)

	func get_component(node: Node, component_name: String) -> Resource:
		var entity_id = _ensure_entity_id(node)
		var components = _get_sparse_set(component_name)
		return components.get_value(entity_id)

	func has_component(node: Node, component_name: String) -> bool:
		var entity_id = _ensure_entity_id(node)
		var components = _get_sparse_set(component_name)
		return components.has(entity_id)

	func remove_component(node: Node, component_name: String) -> void:
		var entity_id = _ensure_entity_id(node)
		var components = _get_sparse_set(component_name)
		components.erase(entity_id)
		if node_components.has(node):
			node_components[node].erase(component_name)
			if node_components[node].size() == 0:
				node_components.erase(node)

	func components_match(node: Node, requires: Array, exclude: Array) -> bool:
		if requires.size() > 0:
			for comp_name in requires:
				if not has_component(node, comp_name.get_global_name()):
					return false
		if exclude.size() > 0:
			for comp_name in exclude:
				if has_component(node, comp_name.get_global_name()):
					return false
		return true

	# returns a list of nodes that have all required components and none of the excluded components
	func get_matching_nodes(requires: Array, exclude: Array) -> Array:
		var result = []
		for node in node_components.keys():
			if components_match(node, requires, exclude):
				result.append(node)
		return result

class PipelineManager:
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

class World extends Node:
	var component_registry
	var pipeline_manager

	func _init():
		component_registry = ComponentRegistry.new()
		pipeline_manager = PipelineManager.new()

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

func _ready():
	var world = World.new()

	world.register_pipeline(DamagePipeline)
	world.register_pipeline(ReverseDamagePipeline)

	world.inject_pipeline(ReverseDamagePipeline, DamagePipeline._stage_deduct, true)

	# create nodes to stress test pipelines and components
	const N = 100
	var nodes = []
	for i in range(N):
		var node = Node.new()
		var health = Health.new()
		health.value = 100 + i
		var damage = Damage.new()
		damage.value = 10 + i
		world.set_component(node, Health, health)
		world.set_component(node, Damage, damage)
		nodes.append(node)

	# validate before running pipelines
	for i in range(N):
		assert(world.get_component(nodes[i], Health).value == 100 + i, "Health value incorrect before pipeline, node %d: expected %d, got %d" % [i, 100 + i, world.get_component(nodes[i], Health).value])
		assert(world.get_component(nodes[i], Damage).value == 10 + i, "Damage value incorrect before pipeline, node %d: expected %d, got %d" % [i, 10 + i, world.get_component(nodes[i], Damage).value])

	# run DamagePipeline on all nodes with components
	var global_results = world.execute_global_pipeline(DamagePipeline)

	# validate results
	for i in range(N):
		# ReverseDamagePipeline sets Damage * -1, so value is now negative, and Deduct applies it to health making it positive
		var expected_damage = 0
		var expected_health = (100 + i) + (i + 10) + expected_damage
		assert(world.get_component(nodes[i], Damage).value == expected_damage, "Damage value incorrect after pipeline, node %d: expected %d, got %d" % [i, expected_damage, world.get_component(nodes[i], Damage).value])
		assert(world.get_component(nodes[i], Health).value == expected_health, "Health value incorrect after pipeline, node %d: expected %d, got %d" % [i, expected_health, world.get_component(nodes[i], Health).value])
		assert(global_results.has(nodes[i]))
		assert(global_results[nodes[i]].state == global_results[nodes[i]].SUCCESS, "Pipeline result for node %d: expected success, got %s" % [i, global_results[nodes[i]].state])

	# test removal
	for i in range(N):
		world.remove_component(nodes[i], Damage)
		assert(world.has_component(nodes[i], Damage) == false, "Damage component was not removed for node %d" % i)
	
	# test that adding and erasing works repeatedly
	for i in range(N):
		var damage = Damage.new()
		damage.value = 20 + i
		world.set_component(nodes[i], Damage, damage)
		assert(world.get_component(nodes[i], Damage).value == 20 + i, "Damage value incorrect after adding, node %d: expected %d, got %d" % [i, 20 + i, world.get_component(nodes[i], Damage).value])
		world.remove_component(nodes[i], Damage)
		assert(world.has_component(nodes[i], Damage) == false, "Damage component was not removed for node %d (repeat test)" % i)
	
	print("All component and pipeline stress tests passed")

	# check singleton example
	var h = Health.new()
	h.value = 999
	world.set_component(world, Health, h)
	assert(world.get_component(world, Health).value == 999, "Singleton health set/get failed: expected 999, got %d" % world.get_component(world, Health).value)
	world.remove_component(world, Health)
	assert(world.has_component(world, Health) == false, "Singleton health removal failed")
	print("Singleton health removal passed")
