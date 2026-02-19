# ABOUTME: Startup pipeline that spawns a 10x10x10 grid of rotating cubes.
# ABOUTME: Runs once on the GridRoot entity, creating 1000 MeshInstance3D children with components.

class_name SpawnCubeGridPipeline extends DefaultPipeline

const GridRootComp = preload("res://classes/components/GridRoot.gd")
const RotationSpeedComp = preload("res://classes/components/RotationSpeed.gd")
const GridMemberComp = preload("res://classes/components/GridMember.gd")

static func _requires(): return [GridRootComp]

static func _stage_spawn(context):
	var grid_node = context._node
	var cube_size := 0.8
	var spacing := 2.0
	var grid_dim := 10
	var offset := (grid_dim - 1) * spacing * 0.5

	# shared mesh resource for all cubes
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(cube_size, cube_size, cube_size)

	for x in range(grid_dim):
		for y in range(grid_dim):
			for z in range(grid_dim):
				var cube = MeshInstance3D.new()
				cube.mesh = box_mesh
				cube.name = "Cube_%d_%d_%d" % [x, y, z]
				cube.position = Vector3(
					x * spacing - offset,
					y * spacing - offset,
					z * spacing - offset
				)

				# per-cube material with color variation based on grid position
				var mat = StandardMaterial3D.new()
				var hue = fmod(float(x) / grid_dim + float(y) / grid_dim * 0.33 + float(z) / grid_dim * 0.66, 1.0)
				mat.albedo_color = Color.from_hsv(hue, 0.7, 0.9)
				mat.metallic = 0.3
				mat.roughness = 0.6
				cube.material_override = mat

				grid_node.add_child(cube)

				# attach ECS components
				var rot_speed = RotationSpeedComp.new()
				rot_speed.x = randf_range(0.5, 2.5)
				rot_speed.y = randf_range(0.5, 2.5)
				rot_speed.z = randf_range(0.3, 1.5)
				Deus.set_component(cube, RotationSpeedComp, rot_speed)

				var member = GridMemberComp.new()
				member.index = x * 100 + y * 10 + z
				Deus.set_component(cube, GridMemberComp, member)
