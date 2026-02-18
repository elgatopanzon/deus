# ABOUTME: Benchmark harness for Godot Deus ECS -- measures operation timing with configurable entity counts.
# ABOUTME: Run headless to print results. Format: BENCH|name|iterations|total_us|avg_us.

extends Node

const BenchPipeline = preload("res://benchmarks/BenchmarkPipeline.gd")
const BenchPipelineMedium = preload("res://benchmarks/BenchmarkPipelineMedium.gd")
const BenchPipelineComplex = preload("res://benchmarks/BenchmarkPipelineComplex.gd")
const BenchCompA = preload("res://benchmarks/BenchComponentA.gd")
const BenchCompB = preload("res://benchmarks/BenchComponentB.gd")
const BenchCompC = preload("res://benchmarks/BenchComponentC.gd")

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
	_bench_execute_pipeline_medium()
	_bench_execute_pipeline_complex()
	_bench_execute_global_pipeline()
	_bench_execute_global_pipeline_medium()
	_bench_execute_global_pipeline_complex()
	_bench_get_matching_nodes()

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

func _bench_execute_pipeline_medium():
	Deus.register_pipeline(BenchPipelineMedium)
	var nodes = _make_nodes(entity_count)
	_attach_health_and_damage(nodes)
	var counter = [0]
	bench("execute_pipeline_medium(2c3s) x%d" % entity_count, func():
		Deus.execute_pipeline(BenchPipelineMedium, nodes[counter[0] % entity_count])
		counter[0] += 1
	, entity_count)
	_cleanup_nodes_all(nodes)

func _bench_execute_pipeline_complex():
	Deus.register_pipeline(BenchPipelineComplex)
	var nodes = _make_nodes(entity_count)
	_attach_health_and_damage(nodes)
	var counter = [0]
	bench("execute_pipeline_complex(2c5s) x%d" % entity_count, func():
		Deus.execute_pipeline(BenchPipelineComplex, nodes[counter[0] % entity_count])
		counter[0] += 1
	, entity_count)
	_cleanup_nodes_all(nodes)

func _bench_execute_global_pipeline_medium():
	Deus.register_pipeline(BenchPipelineMedium)
	var nodes = _make_nodes(entity_count)
	_attach_health_and_damage(nodes)
	bench("execute_global_pipeline_medium(2c3s) x%d" % entity_count, func():
		Deus.execute_global_pipeline(BenchPipelineMedium)
	, 10)
	_cleanup_nodes_all(nodes)

func _bench_execute_global_pipeline_complex():
	Deus.register_pipeline(BenchPipelineComplex)
	var nodes = _make_nodes(entity_count)
	_attach_health_and_damage(nodes)
	bench("execute_global_pipeline_complex(2c5s) x%d" % entity_count, func():
		Deus.execute_global_pipeline(BenchPipelineComplex)
	, 10)
	_cleanup_nodes_all(nodes)

func _bench_get_matching_nodes():
	var counts = [100, 1000, 10000]
	for count in counts:
		# setup: create nodes with components A+B on all, C on first half
		var nodes = _make_nodes(count)
		for node in nodes:
			Deus.set_component(node, BenchCompA, BenchCompA.new())
			Deus.set_component(node, BenchCompB, BenchCompB.new())
		for i in range(count / 2):
			Deus.set_component(nodes[i], BenchCompC, BenchCompC.new())

		var reg = Deus.component_registry
		# scale iterations down for larger entity counts to keep runtime bounded
		var iters = max(10, 1000 / max(1, count / 100))

		# 1-filter: require A (matches all nodes)
		bench("get_matching_nodes 1req x%d" % count, func():
			reg._invalidate_matching_cache()
			reg.get_matching_nodes([BenchCompA], [])
		, iters)

		# 2-filter: require A+B (matches all nodes)
		bench("get_matching_nodes 2req x%d" % count, func():
			reg._invalidate_matching_cache()
			reg.get_matching_nodes([BenchCompA, BenchCompB], [])
		, iters)

		# 1-filter + exclude: require A, exclude C (matches second half)
		bench("get_matching_nodes 1req+1exc x%d" % count, func():
			reg._invalidate_matching_cache()
			reg.get_matching_nodes([BenchCompA], [BenchCompC])
		, iters)

		# cached: require A+B, no invalidation between calls
		reg._invalidate_matching_cache()
		bench("get_matching_nodes cached x%d" % count, func():
			reg.get_matching_nodes([BenchCompA, BenchCompB], [])
		, iters * 10)

		_cleanup_nodes_all(nodes)

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

func _attach_health_and_damage(nodes: Array):
	for node in nodes:
		var h = Health.new()
		h.value = 100
		Deus.set_component(node, Health, h)
		var d = Damage.new()
		d.value = 10
		Deus.set_component(node, Damage, d)

func _cleanup_nodes(nodes: Array):
	for node in nodes:
		if Deus.has_component(node, Health):
			Deus.remove_component(node, Health)
		node.free()

func _cleanup_nodes_all(nodes: Array):
	for node in nodes:
		Deus.component_registry.remove_all_components(node)
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
