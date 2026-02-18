# ABOUTME: Minimal pipeline used by the benchmark harness to measure pipeline execution overhead.
# ABOUTME: Requires only Health component and does a trivial read to exercise the pipeline machinery.

class_name BenchmarkPipeline extends DefaultPipeline

static func _requires(): return [Health]

static func _stage_noop(context):
	# read the value to ensure the pipeline runs but do nothing costly
	var _v = context.Health.value
