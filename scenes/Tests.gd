extends Node2D

func _ready():
	Deus.inject_pipeline(ReverseDamagePipeline, DamagePipeline._stage_deduct, true)
	Deus.inject_pipeline_result_handler(DamagePipeline, ResultPipeline, [PipelineResult.SUCCESS])

	Deus.set_component(Deus.RigidBody2D, Health, Health.new())

	# create nodes to stress test pipelines and components
	const N = 100
	var nodes = []
	for i in range(N):
		var node = StaticBody2D.new()
		var area2d = Area2D.new()
		area2d.name = "Area"
		node.add_child(area2d)
		var health = Health.new()
		health.value = 100 + i
		var damage = Damage.new()
		damage.value = 10 + i
		Deus.set_component(node, Health, health)
		Deus.set_component(node, Damage, damage)
		nodes.append(node)

	# validate before running pipelines
	for i in range(N):
		assert(Deus.get_component(nodes[i], Health).value == 100 + i, "Health value incorrect before pipeline, node %d: expected %d, got %d" % [i, 100 + i, Deus.get_component(nodes[i], Health).value])
		assert(Deus.get_component(nodes[i], Damage).value == 10 + i, "Damage value incorrect before pipeline, node %d: expected %d, got %d" % [i, 10 + i, Deus.get_component(nodes[i], Damage).value])

	# run DamagePipeline on all nodes with components
	var global_results = Deus.execute_global_pipeline(DamagePipeline)

	# validate results
	for i in range(N):
		# ReverseDamagePipeline sets Damage * -1, so value is now negative, and Deduct applies it to health making it positive
		var expected_damage = 0
		var expected_health = (100 + i) + (i + 10) + expected_damage
		assert(Deus.get_component(nodes[i], Damage).value == expected_damage, "Damage value incorrect after pipeline, node %d: expected %d, got %d" % [i, expected_damage, Deus.get_component(nodes[i], Damage).value])
		assert(Deus.get_component(nodes[i], Health).value == expected_health, "Health value incorrect after pipeline, node %d: expected %d, got %d" % [i, expected_health, Deus.get_component(nodes[i], Health).value])
		assert(global_results.has(nodes[i]))
		assert(global_results[nodes[i]].state == global_results[nodes[i]].SUCCESS, "Pipeline result for node %d: expected success, got %s" % [i, global_results[nodes[i]].state])

	# test removal
	for i in range(N):
		Deus.remove_component(nodes[i], Damage)
		assert(Deus.has_component(nodes[i], Damage) == false, "Damage component was not removed for node %d" % i)
	
	# test that adding and erasing works repeatedly
	for i in range(N):
		var damage = Damage.new()
		damage.value = 20 + i
		Deus.set_component(nodes[i], Damage, damage)
		assert(Deus.get_component(nodes[i], Damage).value == 20 + i, "Damage value incorrect after adding, node %d: expected %d, got %d" % [i, 20 + i, Deus.get_component(nodes[i], Damage).value])
		Deus.remove_component(nodes[i], Damage)
		assert(Deus.has_component(nodes[i], Damage) == false, "Damage component was not removed for node %d (repeat test)" % i)
	
	print("All component and pipeline stress tests passed")

	# check singleton example
	var h = Health.new()
	h.value = 999
	Deus.set_component(Deus, Health, h)
	assert(Deus.get_component(Deus, Health).value == 999, "Singleton health set/get failed: expected 999, got %d" % Deus.get_component(Deus, Health).value)
	Deus.remove_component(Deus, Health)
	assert(Deus.has_component(Deus, Health) == false, "Singleton health removal failed")
	print("Singleton health removal passed")

	# ReadOnly prefix tests: verify zero-copy access via context
	var ro_node = StaticBody2D.new()
	var ro_health = Health.new()
	ro_health.value = 500
	var ro_damage = Damage.new()
	ro_damage.value = 25
	Deus.set_component(ro_node, Health, ro_health)
	Deus.set_component(ro_node, Damage, ro_damage)

	var ro_ctx = PipelineContext.new()
	ro_ctx._node = ro_node
	var ro_entity_id = Deus.component_registry._ensure_entity_id(ro_node)
	var ro_health_ref = Deus.component_registry.get_component_ref(ro_entity_id, "Health")
	var ro_damage_ref = Deus.component_registry.get_component_ref(ro_entity_id, "Damage")
	ro_ctx.original_components["Health"] = ro_health_ref
	ro_ctx.original_components["Damage"] = ro_damage_ref

	# ReadOnly returns same object as registry original
	assert(ro_ctx.ReadOnlyHealth == ro_health_ref, "ReadOnlyHealth should be same object as registry ref")
	assert(ro_ctx.ReadOnlyDamage == ro_damage_ref, "ReadOnlyDamage should be same object as registry ref")

	# ReadOnly and normal access are different objects (normal triggers clone)
	var cloned_health = ro_ctx.Health
	assert(cloned_health != ro_health_ref, "context.Health should be a clone, not the original ref")
	assert(cloned_health.value == ro_health_ref.value, "cloned Health value should match original")

	# mutating ReadOnly ref affects registry original (foot-gun by design)
	ro_ctx.ReadOnlyDamage.value = 999
	assert(ro_damage_ref.value == 999, "ReadOnly mutation should affect registry original")

	Deus.remove_component(ro_node, Health)
	Deus.remove_component(ro_node, Damage)
	print("ReadOnly prefix tests passed")

	Deus.RigidBody2D.queue_free()

	print(Deus.get_resource(Deus.Button, "test_resource"))

	print(ProjectSettings.get_setting("addons/deus/components/enable_component_lifecycle_pipelines"))

	Deus.component_registry.connect("component_added", func(...args): print("component_added: "); print(args))
	Deus.component_registry.connect("component_set", func(...args): print("component_set: "); print("new:%s" % [args[3].value]))
	Deus.component_registry.connect("component_removed", func(...args): print("component_removed: "); print(args))

	var he = Health.new()

	# should trigger change
	he.value = 321
	Deus.set_component(Deus.Button, Health, he)

	# should trigger change
	he = Deus.get_component(Deus.Button, Health)
	he.value = 456
	Deus.set_component(Deus.Button, Health, he)

	# should not trigger change
	he = Deus.get_component(Deus.Button, Health)
	he.value = 456
	Deus.set_component(Deus.Button, Health, he)
