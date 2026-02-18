# ABOUTME: Complex benchmark pipeline with 2 components and 5 stages.
# ABOUTME: Used to measure pipeline execution overhead as stage count grows.

class_name BenchmarkPipelineComplex extends DefaultPipeline

static func _requires(): return [Health, Damage]

static func _stage_validate(context):
	var _v = context.Health.value >= 0

static func _stage_read_health(context):
	var _v = context.Health.value

static func _stage_read_damage(context):
	var _v = context.Damage.value

static func _stage_compute(context):
	var _v = context.Health.value - context.Damage.value

static func _stage_finalize(context):
	var _v = context.Damage.value
