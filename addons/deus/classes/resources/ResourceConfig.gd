######################################################################
# @author      : ElGatoPanzon
# @class       : ResourceConfig
# @created     : Thursday Jan 08, 2026 23:02:24 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : main resource config resource
######################################################################

class_name ResourceConfig
extends Resource

@export var resource: Resource
@export var resource_id: String
@export var duplicate_resource: bool = true
@export var duplicate_resource_deep: bool = false
