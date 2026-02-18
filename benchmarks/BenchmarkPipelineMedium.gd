# ABOUTME: Medium-complexity benchmark pipeline with 2 components and 3 stages.
# ABOUTME: Used to measure pipeline execution overhead as stage count grows.

class_name BenchmarkPipelineMedium extends DefaultPipeline

static func _requires(): return [Health, Damage]

static func _stage_read_health(context):
	var _v = context.Health.value

static func _stage_read_damage(context):
	var _v = context.Damage.value

static func _stage_compute(context):
	var _v = context.Health.value - context.Damage.value
