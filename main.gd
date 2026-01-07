extends Node2D

# pipeline manager class for handling pipelines and stages
class PipelineManager:
	var pipelines = {}
	var global_context = {}

	# register a new pipeline with its stages and required global keys
	func register_pipeline(name: String, stages: Dictionary, keys: Array) -> void:
		pipelines[name] = {
			"stages": stages.duplicate(true),
			"keys": keys.duplicate()
		}

	# inject a function or pipeline before a given stage in a pipeline
	func inject_before(pipeline_name: String, target_stage: String, injected_fn_or_pipeline, priority: int = 0) -> void:
		if pipelines.has(pipeline_name):
			if not pipelines[pipeline_name]["stages"].has(target_stage):
				pipelines[pipeline_name]["stages"][target_stage] = []
			pipelines[pipeline_name]["stages"][target_stage].insert(priority, injected_fn_or_pipeline)

	# inject a function or pipeline after a given stage in a pipeline
	func inject_after(pipeline_name: String, target_stage: String, injected_fn_or_pipeline) -> void:
		if pipelines.has(pipeline_name):
			if not pipelines[pipeline_name]["stages"].has(target_stage):
				pipelines[pipeline_name]["stages"][target_stage] = []
			pipelines[pipeline_name]["stages"][target_stage].append(injected_fn_or_pipeline)

	# create a context dictionary from the global context and keys
	func _create_context_from_global(keys: Array) -> Dictionary:
		var context := {}
		for key in keys:
			context["original_%s" % key] = global_context[key]
			context["current_%s" % key] = global_context[key]
		return context

	# call a stage or nested pipeline with a given context
	func _call_stage_or_pipeline(stage_or_pipeline, context: Dictionary) -> void:
		if typeof(stage_or_pipeline) == TYPE_CALLABLE:
			stage_or_pipeline.call(context)
		elif typeof(stage_or_pipeline) == TYPE_STRING and pipelines.has(stage_or_pipeline):
			var keys = pipelines[stage_or_pipeline]["keys"]
			var new_context := {}
			for key in keys:
				if context.has("current_%s" % key):
					new_context["original_%s" % key] = context["current_%s" % key]
					new_context["current_%s" % key] = context["current_%s" % key]
			self.run(stage_or_pipeline, new_context)
			for key in keys:
				context["current_%s" % key] = new_context["current_%s" % key]

	# run a pipeline using only global context and pipeline keys (context_override allows nesting)
	func run(pipeline_name: String, context_override = null) -> void:
		if not pipelines.has(pipeline_name):
			return
		var stages = pipelines[pipeline_name]["stages"]
		var keys = pipelines[pipeline_name]["keys"]
		var context = context_override if context_override != null else _create_context_from_global(keys)
		for stage in stages.keys():
			for fn_or_pipe in stages[stage]:
				_call_stage_or_pipeline(fn_or_pipe, context)
		# commit changes after pipeline to global_context
		for key in keys:
			if context.has("current_%s" % key):
				global_context[key] = context["current_%s" % key]

# stages for damage pipeline
func _damage_stage_deduct(context):
	# apply damage to health
	context.current_health -= context.current_damage
	context.current_damage = 0

# stages for reverse pipeline
func _reverse_stage_deduct(context):
	# multiply damage by -1 for reversal
	context.current_damage *= -1

# main ready function to setup and run pipelines
func _ready():
	# set up manager and initial global context
	var manager = PipelineManager.new()
	manager.global_context = {
		"health": 10,
		"damage": 2
	}

	var damage_pipeline = {
		"deduct": [_damage_stage_deduct]
	}
	var reverse_pipeline = {
		"deduct": [_reverse_stage_deduct]
	}

	# register pipelines and their keys
	manager.register_pipeline("damage", damage_pipeline, ["health", "damage"])
	manager.register_pipeline("reverse", reverse_pipeline, ["damage"])
	# inject reverse before deduct in damage
	manager.inject_before("damage", "deduct", "reverse")
	# print before state
	print("before ", manager.global_context)
	# run pipeline
	manager.run("damage")
	# print after state
	print("after ", manager.global_context)
