######################################################################
# @author      : ElGatoPanzon
# @class       : ComponentConfig
# @created     : Thursday Jan 08, 2026 22:50:30 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : main component config resource
######################################################################

class_name ComponentConfig
extends Resource

@export var component: DefaultComponent
@export var duplicate_component: bool = true
@export var duplicate_component_deep: bool = false
