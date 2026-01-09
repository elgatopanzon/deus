class_name ButtonPressedPipeline extends Pipeline
static func _stage_pressed(context):
	print("button was pressed! ", context.payload)
