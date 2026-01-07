# damage pipeline class
class_name DamagePipeline
static func _requires(): return [Health, Damage]
static func _stage_deduct(context):
	context.Health.value -= context.Damage.value
	context.Damage.value = 0
