# ABOUTME: Per-frame pipeline that rotates individual cubes around their own origin.
# ABOUTME: Reads RotationSpeed component and applies rotation scaled by delta time.

class_name CubeRotationPipeline extends DefaultPipeline

const RotationSpeedComp = preload("res://classes/components/RotationSpeed.gd")
const GridMemberComp = preload("res://classes/components/GridMember.gd")

static func _requires(): return [RotationSpeedComp, GridMemberComp]

static func _stage_rotate(context):
	var node = context._node
	var speed = context.ReadOnlyRotationSpeed
	var delta = context.world.delta
	node.rotate_x(speed.x * delta)
	node.rotate_y(speed.y * delta)
	node.rotate_z(speed.z * delta)
