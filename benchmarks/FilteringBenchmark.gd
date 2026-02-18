# ABOUTME: Benchmarks components_match() and filter matching with varying require/exclude combinations.
# ABOUTME: Tests 1, 3, and 5-component filter sets against entity pools of 100, 1000, and 10000 nodes.

extends Node

const BenchCompA = preload("res://benchmarks/BenchComponentA.gd")
const BenchCompB = preload("res://benchmarks/BenchComponentB.gd")
const BenchCompC = preload("res://benchmarks/BenchComponentC.gd")
const BenchCompD = preload("res://benchmarks/BenchComponentD.gd")
const BenchCompE = preload("res://benchmarks/BenchComponentE.gd")

var _results: Array = []

func _ready():
	print("=== Filtering Benchmark ===")
	print("")

	_run_all()
	_print_report()

	get_tree().quit()


func _run_all():
	for count in [100, 1000, 10000]:
		var nodes = _make_nodes(count)
		_attach_components(nodes)
		var reg = Deus.component_registry

		# per-node iterations: fixed pass count over entity pool
		var match_iters = count * 10
		# bulk query iterations: scale down for large entity counts
		var bulk_iters: int = max(10, 1000 / max(1, int(count / 100)))

		# --- components_match: per-node filter check ---

		# 1-component require (matches all nodes)
		var counter = [0]
		_bench("components_match 1req x%d" % count, func():
			reg.components_match(nodes[counter[0] % count], [BenchCompA], [])
			counter[0] += 1
		, match_iters)

		# 3-component require (matches all nodes)
		counter = [0]
		_bench("components_match 3req x%d" % count, func():
			reg.components_match(nodes[counter[0] % count], [BenchCompA, BenchCompB, BenchCompC], [])
			counter[0] += 1
		, match_iters)

		# 5-component require (matches all nodes)
		counter = [0]
		_bench("components_match 5req x%d" % count, func():
			reg.components_match(nodes[counter[0] % count], [BenchCompA, BenchCompB, BenchCompC, BenchCompD, BenchCompE], [])
			counter[0] += 1
		, match_iters)

		# 1-component require + 1 exclude (A required, E excluded on second half)
		counter = [0]
		_bench("components_match 1req+1exc x%d" % count, func():
			reg.components_match(nodes[counter[0] % count], [BenchCompA], [BenchCompE])
			counter[0] += 1
		, match_iters)

		# 3-component require + 2 exclude
		counter = [0]
		_bench("components_match 3req+2exc x%d" % count, func():
			reg.components_match(nodes[counter[0] % count], [BenchCompA, BenchCompB, BenchCompC], [BenchCompD, BenchCompE])
			counter[0] += 1
		, match_iters)

		# miss case: require component not present (should return false fast)
		var half = int(count / 2)
		counter = [0]
		_bench("components_match miss x%d" % count, func():
			# second half of nodes lack D and E, so 5req fails on those
			var idx = half + (counter[0] % half)
			reg.components_match(nodes[idx], [BenchCompA, BenchCompB, BenchCompC, BenchCompD, BenchCompE], [])
			counter[0] += 1
		, match_iters)

		# --- get_matching_nodes: bulk filter ---

		# 1-component filter
		_bench("get_matching_nodes 1req x%d" % count, func():
			reg._invalidate_matching_cache()
			reg.get_matching_nodes([BenchCompA], [])
		, bulk_iters)

		# 3-component filter
		_bench("get_matching_nodes 3req x%d" % count, func():
			reg._invalidate_matching_cache()
			reg.get_matching_nodes([BenchCompA, BenchCompB, BenchCompC], [])
		, bulk_iters)

		# 5-component filter (matches first half only)
		_bench("get_matching_nodes 5req x%d" % count, func():
			reg._invalidate_matching_cache()
			reg.get_matching_nodes([BenchCompA, BenchCompB, BenchCompC, BenchCompD, BenchCompE], [])
		, bulk_iters)

		# 3-component require + 2 exclude
		_bench("get_matching_nodes 3req+2exc x%d" % count, func():
			reg._invalidate_matching_cache()
			reg.get_matching_nodes([BenchCompA, BenchCompB, BenchCompC], [BenchCompD, BenchCompE])
		, bulk_iters)

		# cached: 5-component filter, no invalidation between calls
		reg._invalidate_matching_cache()
		_bench("get_matching_nodes cached 5req x%d" % count, func():
			reg.get_matching_nodes([BenchCompA, BenchCompB, BenchCompC, BenchCompD, BenchCompE], [])
		, bulk_iters * 10)

		_cleanup_nodes(nodes)


# -- helpers --

func _make_nodes(count: int) -> Array:
	var nodes = []
	for _i in range(count):
		nodes.append(Node.new())
	return nodes


# attach A+B+C to all nodes, D+E to first half only
func _attach_components(nodes: Array):
	for i in range(nodes.size()):
		var node = nodes[i]
		Deus.set_component(node, BenchCompA, BenchCompA.new())
		Deus.set_component(node, BenchCompB, BenchCompB.new())
		Deus.set_component(node, BenchCompC, BenchCompC.new())
		if i < int(nodes.size() / 2):
			Deus.set_component(node, BenchCompD, BenchCompD.new())
			Deus.set_component(node, BenchCompE, BenchCompE.new())


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
	print("%-50s %10s %12s %10s" % ["benchmark", "iterations", "total_us", "avg_us"])
	print("-".repeat(85))
	for r in _results:
		print("%-50s %10d %12d %10.2f" % [r.name, r.iterations, r.total_us, r.avg_us])
	print("")
	# machine-parseable lines for before/after diff scripts
	for r in _results:
		print("BENCH|%s|%d|%d|%.2f" % [r.name, r.iterations, r.total_us, r.avg_us])
