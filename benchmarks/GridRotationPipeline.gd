# ABOUTME: Per-frame pipeline that rotates the entire cube grid as a unit.
# ABOUTME: Matches the GridRoot entity and applies slow Y-axis rotation.

class_name GridRotationPipeline extends DefaultPipeline

const GridRootComp = preload("res://benchmarks/GridRoot.gd")

static func _requires(): return [GridRootComp]

static func _stage_rotate(context):
	var node = context._node
	var speed = context.ReadOnlyGridRoot.rotation_speed
	var delta = context.world.delta
	node.rotate_y(speed * delta)
