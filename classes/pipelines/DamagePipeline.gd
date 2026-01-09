# damage pipeline class
class_name DamagePipeline extends Pipeline
static func _requires(): return [Health, Damage]
static func _require_nodes(): return [[StaticBody2D], ["Area"]]
static func _stage_deduct(context):
	context.Health.value -= context.Damage.value
	context.Damage.value = 0
