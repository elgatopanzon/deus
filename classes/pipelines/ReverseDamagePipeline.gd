# reverse pipeline class
class_name ReverseDamagePipeline extends DefaultPipeline
static func _requires(): return [Damage]
static func _stage_reverse(context):
	context.Damage.value *= -1
