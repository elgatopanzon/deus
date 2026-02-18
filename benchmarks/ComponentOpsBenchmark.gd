# ABOUTME: Benchmarks low-level component operations: SparseSet add/has/get/erase and ComponentRegistry overhead.
# ABOUTME: Measures deep comparison, entity ID assignment, and full set/get/has/remove at multiple entity scales.

extends Node

const BenchCompA = preload("res://benchmarks/BenchComponentA.gd")
const BenchCompB = preload("res://benchmarks/BenchComponentB.gd")

var _results: Array = []

func _ready():
	print("=== Component Operations Benchmark ===")
	print("")

	_run_all()
	_print_report()

	get_tree().quit()


func _run_all():
	for count in [100, 1000, 10000]:
		_bench_sparse_set_add(count)
		_bench_sparse_set_has(count)
		_bench_sparse_set_get(count)
		_bench_sparse_set_erase(count)
		_bench_ensure_entity_id(count)
		_bench_deep_compare_equal(count)
		_bench_deep_compare_changed(count)
		_bench_set_component(count)
		_bench_get_component(count)
		_bench_has_component(count)
		_bench_remove_component(count)
		_bench_remove_all_components(count)


# -- SparseSet direct operations --

func _bench_sparse_set_add(count: int):
	var ss = SparseSet.new()
	var counter = [0]
	_bench("sparse_set.add x%d" % count, func():
		var id = counter[0]
		ss.add(id, id)
		counter[0] += 1
	, count)

func _bench_sparse_set_has(count: int):
	var ss = SparseSet.new()
	for i in range(count):
		ss.add(i, i)
	var counter = [0]
	_bench("sparse_set.has x%d" % count, func():
		ss.has(counter[0] % count)
		counter[0] += 1
	, count)

func _bench_sparse_set_get(count: int):
	var ss = SparseSet.new()
	for i in range(count):
		ss.add(i, i)
	var counter = [0]
	_bench("sparse_set.get_value x%d" % count, func():
		ss.get_value(counter[0] % count)
		counter[0] += 1
	, count)

func _bench_sparse_set_erase(count: int):
	var ss = SparseSet.new()
	for i in range(count):
		ss.add(i, i)
	var counter = [0]
	_bench("sparse_set.erase x%d" % count, func():
		var id = counter[0] % count
		if not ss.has(id):
			ss.add(id, id)
		ss.erase(id)
		counter[0] += 1
	, count)


# -- ComponentRegistry internals --

func _bench_ensure_entity_id(count: int):
	var reg = Deus.component_registry
	var nodes = _make_nodes(count)
	# first pass assigns IDs
	for node in nodes:
		reg._ensure_entity_id(node)
	# bench the cached path (already assigned)
	var counter = [0]
	_bench("ensure_entity_id(cached) x%d" % count, func():
		reg._ensure_entity_id(nodes[counter[0] % count])
		counter[0] += 1
	, count)
	for node in nodes:
		node.free()

func _bench_deep_compare_equal(count: int):
	var reg = Deus.component_registry
	# pre-warm property cache
	var warmA = BenchCompA.new()
	warmA.value = 42
	reg._get_script_properties(warmA)

	var compA = BenchCompA.new()
	compA.value = 42
	var compB = BenchCompA.new()
	compB.value = 42
	_bench("deep_compare(equal) x%d" % count, func():
		reg._deep_compare_component(compA, compB)
	, count)

func _bench_deep_compare_changed(count: int):
	var reg = Deus.component_registry
	var compA = BenchCompA.new()
	compA.value = 1
	var compB = BenchCompA.new()
	compB.value = 2
	_bench("deep_compare(changed) x%d" % count, func():
		reg._deep_compare_component(compA, compB)
	, count)


# -- Full component operations (through Deus) --

func _bench_set_component(count: int):
	var nodes = _make_nodes(count)
	var counter = [0]
	_bench("set_component x%d" % count, func():
		var idx = counter[0] % count
		var c = BenchCompA.new()
		c.value = idx
		Deus.set_component(nodes[idx], BenchCompA, c)
		counter[0] += 1
	, count)
	_cleanup_nodes(nodes)

func _bench_get_component(count: int):
	var nodes = _make_nodes(count)
	_attach_comp_a(nodes)
	var counter = [0]
	_bench("get_component x%d" % count, func():
		Deus.get_component(nodes[counter[0] % count], BenchCompA)
		counter[0] += 1
	, count)
	_cleanup_nodes(nodes)

func _bench_has_component(count: int):
	var nodes = _make_nodes(count)
	_attach_comp_a(nodes)
	var counter = [0]
	_bench("has_component x%d" % count, func():
		Deus.has_component(nodes[counter[0] % count], BenchCompA)
		counter[0] += 1
	, count)
	_cleanup_nodes(nodes)

func _bench_remove_component(count: int):
	var nodes = _make_nodes(count)
	_attach_comp_a(nodes)
	var counter = [0]
	_bench("remove_component x%d" % count, func():
		var idx = counter[0] % count
		if not Deus.has_component(nodes[idx], BenchCompA):
			Deus.set_component(nodes[idx], BenchCompA, BenchCompA.new())
		Deus.remove_component(nodes[idx], BenchCompA)
		counter[0] += 1
	, count)
	_cleanup_nodes(nodes)

func _bench_remove_all_components(count: int):
	var nodes = _make_nodes(count)
	for node in nodes:
		Deus.set_component(node, BenchCompA, BenchCompA.new())
		Deus.set_component(node, BenchCompB, BenchCompB.new())
	var counter = [0]
	_bench("remove_all_components(2c) x%d" % count, func():
		var idx = counter[0] % count
		var node = nodes[idx]
		if not Deus.has_component(node, BenchCompA):
			Deus.set_component(node, BenchCompA, BenchCompA.new())
			Deus.set_component(node, BenchCompB, BenchCompB.new())
		Deus.component_registry.remove_all_components(node)
		counter[0] += 1
	, count)
	for node in nodes:
		Deus.component_registry.remove_all_components(node)
		node.free()


# -- helpers --

func _make_nodes(count: int) -> Array:
	var nodes = []
	for _i in range(count):
		nodes.append(Node.new())
	return nodes

func _attach_comp_a(nodes: Array):
	for node in nodes:
		var c = BenchCompA.new()
		c.value = 100
		Deus.set_component(node, BenchCompA, c)

func _cleanup_nodes(nodes: Array):
	for node in nodes:
		Deus.component_registry.remove_all_components(node)
		node.free()

func _bench(label: String, callable: Callable, iterations: int = 1000):
	var start = Time.get_ticks_usec()
	for _i in range(iterations):
		callable.call()
	var elapsed = Time.get_ticks_usec() - start

	var result = {
		"name": label,
		"iterations": iterations,
		"total_us": elapsed,
		"avg_us": float(elapsed) / float(iterations),
	}
	_results.append(result)

func _print_report():
	print("--- Results ---")
	print("%-45s %10s %12s %10s" % ["benchmark", "iterations", "total_us", "avg_us"])
	print("-".repeat(80))
	for r in _results:
		print("%-45s %10d %12d %10.2f" % [r.name, r.iterations, r.total_us, r.avg_us])
	print("")
	# machine-parseable lines for before/after diff scripts
	for r in _results:
		print("BENCH|%s|%d|%d|%.2f" % [r.name, r.iterations, r.total_us, r.avg_us])
