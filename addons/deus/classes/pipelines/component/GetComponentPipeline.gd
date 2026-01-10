######################################################################
# @author      : ElGatoPanzon
# @class       : GetComponentPipeline
# @created     : Friday Jan 09, 2026 22:40:33 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : handles getting component values
######################################################################

class_name GetComponentPipeline
extends DefaultPipeline
static func _stage_get(ctx):
	var entity_id = ctx.world.component_registry._ensure_entity_id(ctx._node)
	var components = ctx.world.component_registry._get_sparse_set(ctx.payload.component_name)
	ctx.result.value = components.get_value(entity_id).duplicate(true)
