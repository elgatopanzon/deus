# ABOUTME: Marker component identifying the root Node3D of the rotating cube grid.
# ABOUTME: Used by SpawnCubeGridPipeline and GridRotationPipeline to target the grid parent.

class_name GridRoot extends DefaultComponent
@export var rotation_speed: float = 0.3
