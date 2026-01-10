class_name ButtonPressedPipeline extends DefaultPipeline
static func _stage_pressed(context):
	print("button was pressed! ", context.payload)
