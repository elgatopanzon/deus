# ABOUTME: Bootstrap script for the 3D rotating cube grid benchmark scene.
# ABOUTME: Registers pipelines with the scheduler and attaches components to the grid root.

extends Node3D

const GridRootComp = preload("res://benchmarks/GridRoot.gd")
const RotationSpeedComp = preload("res://benchmarks/RotationSpeed.gd")
const GridMemberComp = preload("res://benchmarks/GridMember.gd")
const SpawnCubeGrid = preload("res://benchmarks/SpawnCubeGridPipeline.gd")
const CubeRotation = preload("res://benchmarks/CubeRotationPipeline.gd")
const GridRotation = preload("res://benchmarks/GridRotationPipeline.gd")

@onready var grid_root: Node3D = $GridRoot

func _ready():
	# attach GridRoot component to the grid parent node
	var root_comp = GridRootComp.new()
	root_comp.rotation_speed = 0.3
	Deus.set_component(grid_root, GridRootComp, root_comp)

	# register pipelines
	Deus.register_pipeline(SpawnCubeGrid)
	Deus.register_pipeline(CubeRotation)
	Deus.register_pipeline(GridRotation)

	# run spawn pipeline directly (startup phase fires before scene loads)
	Deus.execute_pipeline(SpawnCubeGrid, grid_root)

	# schedule per-frame pipelines
	Deus.pipeline_scheduler.register_task(
		PipelineSchedulerDefaults.OnUpdate,
		CubeRotation
	)
	Deus.pipeline_scheduler.register_task(
		PipelineSchedulerDefaults.OnUpdate,
		GridRotation
	)
