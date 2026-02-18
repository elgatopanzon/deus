# ABOUTME: Benchmark harness for Godot Deus ECS -- measures operation timing with configurable entity counts.
# ABOUTME: Run headless to print results. Format: BENCH|name|iterations|total_us|avg_us.

extends Node

const BenchPipeline = preload("res://benchmarks/BenchmarkPipeline.gd")

# entity count used by benchmarks that scale with entity size
@export var entity_count: int = 1000

var _results: Array = []

func _ready():
	print("=== Deus ECS Benchmark Suite ===")
	print("entity_count=%d" % entity_count)
	print("")

	_run_all()
	_print_report()

	get_tree().quit()

# run a named callable n times and record timing
# callable receives no arguments
func bench(label: String, callable: Callable, iterations: int = 1000) -> Dictionary:
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
	return result

func _run_all():
	_bench_set_component()
	_bench_get_component()
	_bench_has_component()
	_bench_remove_component()
	_bench_execute_pipeline()
	_bench_execute_global_pipeline()

# -- individual benchmarks --

func _bench_set_component():
	var nodes = _make_nodes(entity_count)
	var counter = [0]
	bench("set_component x%d" % entity_count, func():
		var idx = counter[0] % entity_count
		var h = Health.new()
		h.value = idx
		Deus.set_component(nodes[idx], Health, h)
		counter[0] += 1
	, entity_count)
	_cleanup_nodes(nodes)

func _bench_get_component():
	var nodes = _make_nodes(entity_count)
	_attach_health(nodes)
	var counter = [0]
	bench("get_component x%d" % entity_count, func():
		Deus.get_component(nodes[counter[0] % entity_count], Health)
		counter[0] += 1
	, entity_count)
	_cleanup_nodes(nodes)

func _bench_has_component():
	var nodes = _make_nodes(entity_count)
	_attach_health(nodes)
	var counter = [0]
	bench("has_component x%d" % entity_count, func():
		Deus.has_component(nodes[counter[0] % entity_count], Health)
		counter[0] += 1
	, entity_count)
	_cleanup_nodes(nodes)

func _bench_remove_component():
	var nodes = _make_nodes(entity_count)
	_attach_health(nodes)
	var counter = [0]
	bench("remove_component x%d" % entity_count, func():
		var idx = counter[0] % entity_count
		if not Deus.has_component(nodes[idx], Health):
			Deus.set_component(nodes[idx], Health, Health.new())
		Deus.remove_component(nodes[idx], Health)
		counter[0] += 1
	, entity_count)
	_cleanup_nodes(nodes)

func _bench_execute_pipeline():
	Deus.register_pipeline(BenchPipeline)
	var nodes = _make_nodes(entity_count)
	_attach_health(nodes)
	var counter = [0]
	bench("execute_pipeline x%d" % entity_count, func():
		Deus.execute_pipeline(BenchPipeline, nodes[counter[0] % entity_count])
		counter[0] += 1
	, entity_count)
	_cleanup_nodes(nodes)

func _bench_execute_global_pipeline():
	Deus.register_pipeline(BenchPipeline)
	var nodes = _make_nodes(entity_count)
	_attach_health(nodes)
	bench("execute_global_pipeline x%d" % entity_count, func():
		Deus.execute_global_pipeline(BenchPipeline)
	, 10)
	_cleanup_nodes(nodes)

# -- helpers --

func _make_nodes(count: int) -> Array:
	var nodes = []
	for _i in range(count):
		nodes.append(Node.new())
	return nodes

func _attach_health(nodes: Array):
	for node in nodes:
		var h = Health.new()
		h.value = 100
		Deus.set_component(node, Health, h)

func _cleanup_nodes(nodes: Array):
	for node in nodes:
		if Deus.has_component(node, Health):
			Deus.remove_component(node, Health)
		node.free()

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
