# ABOUTME: Component storing per-entity rotation speed in radians/sec per axis.
# ABOUTME: Used by CubeRotationPipeline to spin individual cubes.

class_name RotationSpeed extends DefaultComponent
@export var x: float = 0.0
@export var y: float = 0.0
@export var z: float = 0.0
