# ABOUTME: Benchmarks PipelineScheduler dispatch overhead -- run_tasks, priority sort, frequency check, deferred queues.
# ABOUTME: Measures per-frame cost of scheduler dispatch at varying task counts (10, 50, 100).

extends Node

const BenchPipeline = preload("res://benchmarks/BenchmarkPipeline.gd")

var _results: Array = []

func _ready():
	print("=== Scheduler Benchmark ===")
	print("")

	# ensure the benchmark pipeline is registered with the pipeline manager
	Deus.register_pipeline(BenchPipeline)

	# attach one entity so global pipeline dispatch has work
	var node = Node.new()
	var h = Health.new()
	h.value = 1
	Deus.set_component(node, Health, h)

	_run_all()

	# cleanup
	Deus.remove_component(node, Health)
	node.free()

	_print_report()
	get_tree().quit()


func _run_all():
	for task_count in [10, 50, 100]:
		_bench_run_tasks(task_count)
		_bench_run_tasks_with_frequency(task_count)
		_bench_deferred_registration(task_count)
		# deregistration skipped: PipelineScheduler._immediate_deregister_task
		# uses Array.remove() which was renamed to remove_at() in Godot 4.x
		_bench_priority_sort(task_count)


# -- benchmark: run_tasks dispatch with N tasks in one phase --
# Directly populates the task list to bypass registration dedup (one pipeline per phase).

func _bench_run_tasks(task_count: int):
	var scheduler = PipelineScheduler.new(Deus)
	PipelineSchedulerDefaults.init_default_environment(scheduler)
	scheduler._process_registrations()

	# directly populate task list to get N entries for the same pipeline
	var phase = PipelineSchedulerDefaults.OnUpdate
	scheduler.tasks[phase] = _make_task_list(task_count)

	var group = PipelineSchedulerDefaults.DefaultPhase
	_bench("run_tasks %d tasks" % task_count, func():
		scheduler.run_tasks(group, 0.016)
	, 1000)

	scheduler.free()


# -- benchmark: run_tasks with frequency gating (all tasks skip due to frequency) --

func _bench_run_tasks_with_frequency(task_count: int):
	var scheduler = PipelineScheduler.new(Deus)
	PipelineSchedulerDefaults.init_default_environment(scheduler)
	scheduler._process_registrations()

	var phase = PipelineSchedulerDefaults.OnUpdate
	scheduler.tasks[phase] = _make_task_list(task_count, 1.0)
	# set last_run to now so frequency gate skips every task
	var now = Time.get_ticks_msec() / 1000.0
	for task in scheduler.tasks[phase]:
		task.last_run = now

	var group = PipelineSchedulerDefaults.DefaultPhase
	_bench("run_tasks freq-gated %d tasks" % task_count, func():
		scheduler.run_tasks(group, 0.016)
	, 1000)

	scheduler.free()


# -- benchmark: deferred registration throughput --
# Measures queue + flush cost for N task registrations (including dedup check and sort).

func _bench_deferred_registration(task_count: int):
	var phase = PipelineSchedulerDefaults.OnUpdate
	var scheduler = PipelineScheduler.new(Deus)
	PipelineSchedulerDefaults.init_default_environment(scheduler)
	scheduler._process_registrations()

	_bench("deferred_register %d tasks" % task_count, func():
		# queue N task registrations (all same pipeline, so dedup keeps only the first)
		for i in range(task_count):
			scheduler.register_task(phase, BenchPipeline, 0.0, null, null, i)
		scheduler._process_registrations()
		# clear registered task so next iteration can re-register
		scheduler.tasks.erase(phase)
	, 100)

	scheduler.free()


# -- benchmark: priority sort with N tasks --
# Uses correct Godot 4.x boolean comparator. The existing _sort_priority in
# PipelineScheduler returns -1/1/0 which triggers "bad comparison function" errors.

func _bench_priority_sort(task_count: int):
	var task_list: Array = _make_task_list(task_count)
	# randomize priorities so sort does real work
	for task in task_list:
		task.priority = randi() % 100

	_bench("priority_sort %d tasks" % task_count, func():
		var copy = task_list.duplicate()
		copy.sort_custom(func(a, b): return a.priority > b.priority)
	, 1000)


# -- helpers --

func _make_task_list(count: int, frequency: float = 0.0) -> Array:
	var list: Array = []
	for i in range(count):
		list.append(PipelineScheduler.PipelineTask.new(BenchPipeline, frequency, i))
	return list


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
