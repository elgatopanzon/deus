######################################################################
# @author      : ElGatoPanzon
# @class       : SignalToPipelineConfig
# @created     : Thursday Jan 08, 2026 23:17:02 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : configure signal to pipeline mapping
######################################################################

class_name SignalToPipelineConfig
extends Resource

@export var signal_name: String
@export var pipeline: Pipeline
@export var execution_node_path: NodePath
@export var execution_node_id: String
@export var execute_global: bool = false
