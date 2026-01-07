extends Node2D

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
