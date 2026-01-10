######################################################################
# @author      : ElGatoPanzon
# @class       : EntityConfig
# @created     : Thursday Jan 08, 2026 22:50:11 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : main entity config resource
######################################################################

class_name EntityConfig
extends Resource

@export var purge_components_on_destruction: bool = true
@export var purge_resources_on_destruction: bool = true
