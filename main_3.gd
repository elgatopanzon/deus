extends Node2D

# custom context object for pipeline stages
class PipelineContext:
	var world
	var components = {}
	var payload

    # allows dot-access to components: context.CompName
	func _get(property):
		if components.has(property):
			return components[property]
		else:
			return null

class ComponentRegistry:
	var components = {} # maps node ids to component dictionaries

	func set_component(node: Node, comp: Script, component: Resource) -> void:
		var node_id = node.get_instance_id()
		if not components.has(node_id):
			components[node_id] = {}
		components[node_id][comp.get_global_name()] = component

	func get_component(node: Node, component_class: Script) -> Resource:
		var node_id = node.get_instance_id()
		if components.has(node_id):
			if components[node_id].has(component_class.get_global_name()):
				return components[node_id][component_class.get_global_name()]
		return null

	func has_component(node: Node, component_class: Script) -> bool:
		return get_component(node, component_class) != null

	func remove_component(node: Node, component_class: Script) -> void:
		var node_id = node.get_instance_id()
		if components.has(node_id):
			var comp_name = component_class.get_global_name()
			if components[node_id].has(comp_name):
				components[node_id].erase(comp_name)
				# remove node dictionary if now empty
				if components[node_id].size() == 0:
					components.erase(node_id)

	func components_match(node: Node, requires: Array, exclude: Array) -> bool:
		if requires.size() > 0:
			for comp in requires:
				if not has_component(node, comp):
					return false
		if exclude.size() > 0:
			for comp in exclude:
				if has_component(node, comp):
					return false
		return true

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
			var instance = component_registry.get_component(node, comp)
			if instance != null:
				context.components[comp.get_global_name()] = instance
		# payload is always empty at start
		context.payload = null
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
				return
			self.run(stage_or_pipeline, node, component_registry, world, context.payload, context)
			var add_ctx = _create_context_from_node(world, node, requires + optional, component_registry)
			for key in add_ctx.components.keys():
				context.components[key] = add_ctx.components[key]

	func run(pipeline_class: Script, node: Node, component_registry: ComponentRegistry, world: Object, payload = null, context_override = null) -> void:
		var pipeline_name = pipeline_class.get_global_name()
		if not pipelines.has(pipeline_name):
			return
		var requires = pipelines[pipeline_name]["requires"]
		var optional = pipelines[pipeline_name]["optional"]
		var exclude = pipelines[pipeline_name]["exclude"]
		if not component_registry.components_match(node, requires, exclude):
			return
		var stages = pipelines[pipeline_name]["stages"]
		var context = context_override
		if context_override == null:
			context = _create_context_from_node(world, node, requires + optional, component_registry)
		if payload != null:
			context.payload = payload
		for stage in stages.keys():
			for fn_or_pipe in stages[stage]:
				_call_stage_or_pipeline(fn_or_pipe, node, context, component_registry, world)

class World extends Node:
	var component_registry
	var pipeline_manager

	func _init():
		component_registry = ComponentRegistry.new()
		pipeline_manager = PipelineManager.new()

	# component methods
	func set_component(node: Node, comp: Script, component: Resource) -> void:
		component_registry.set_component(node, comp, component)
	
	func get_component(node: Node, component_class: Script) -> Resource:
		return component_registry.get_component(node, component_class)

	func has_component(node: Node, component_class: Script) -> bool:
		return component_registry.has_component(node, component_class)

	# pipeline methods
	func register_pipeline(pipeline_class: Script) -> void:
		pipeline_manager.register_pipeline(pipeline_class)

	func deregister_pipeline(pipeline_class: Script) -> void:
		pipeline_manager.deregister_pipeline(pipeline_class)

	func inject_pipeline(injected_fn_or_pipeline, target_callable: Callable, before: bool = false, priority: int = 0) -> void:
		pipeline_manager.inject_pipeline(injected_fn_or_pipeline, target_callable, before, priority)

	func uninject_pipeline(injected_fn_or_pipeline, target_callable: Callable) -> void:
		pipeline_manager.uninject_pipeline(injected_fn_or_pipeline, target_callable)

	func execute_pipeline(pipeline_class: Script, node: Node, payload = null, context_override = null) -> void:
		pipeline_manager.run(pipeline_class, node, component_registry, self, payload, context_override)

func _ready():
	var world = World.new()

	world.register_pipeline(DamagePipeline)
	world.register_pipeline(ReverseDamagePipeline)

	world.inject_pipeline(ReverseDamagePipeline, DamagePipeline._stage_deduct, true)

	var node1 = Node.new()
	var health_comp = Health.new()
	health_comp.value = 100
	var damage_comp = Damage.new()
	damage_comp.value = 10

	var node2 = Node.new()

	world.set_component(node1, Health, health_comp)
	world.set_component(node1, Damage, damage_comp)

	print("Node health before: ", world.get_component(node1, Health).value)
	print("Node damage before: ", world.get_component(node1, Damage).value)

	world.execute_pipeline(DamagePipeline, node1)
	world.execute_pipeline(DamagePipeline, node2)

	print("Node health after: ", world.get_component(node1, Health).value)
	print("Node damage after: ", world.get_component(node1, Damage).value)

	var h = Health.new()
	h.value = 123
	world.set_component(world, Health, h)

	print("Singleton health: ", world.get_component(world, Health).value)
