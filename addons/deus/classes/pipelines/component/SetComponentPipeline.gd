######################################################################
# @author      : ElGatoPanzon
# @class       : SetComponentPipeline
# @created     : Friday Jan 09, 2026 22:27:42 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : handles setting and updating components
######################################################################

class_name SetComponentPipeline
extends DefaultPipeline

static func _stage_init_node_components(ctx):
	ctx.world.component_registry._initialize_node_components(ctx._node)

static func _stage_ensure_entity_id(ctx):
	ctx._entity_id = ctx.world.component_registry._ensure_entity_id(ctx._node)

static func _stage_add_or_update_component(ctx):
	if ctx.world.component_registry._is_new_component(ctx._node, ctx.payload.component_name):
		ctx.world.component_registry._add_new_component(ctx._node, ctx._entity_id, ctx.payload.component_name, ctx.payload.component)
	else:
		ctx.world.component_registry._update_existing_component(ctx._node, ctx._entity_id, ctx.payload.component_name, ctx.payload.component)

static func _stage_commit_component(ctx):
	ctx.world.component_registry._add_component_to_sparse_set(ctx._entity_id, ctx.payload.component_name, ctx.payload.component)
