######################################################################
# @author      : ElGatoPanzon
# @class       : DeusConfiguration
# @created     : Thursday Jan 08, 2026 22:48:11 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : entity configuration Node
######################################################################

class_name DeusConfiguration
extends Node

# export node id as a string
@export var node_id: String

# export to hold a single EntityConfig resource
@export var entity_config: EntityConfig

# export array to hold multiple ComponentConfig resources
@export var components: Array[ComponentConfig]

# export array to hold multiple ComponentConfig resources
@export var resources: Array[ResourceConfig]

# export array to hold multiple SignalToPipelineConfig resources
@export var signals_to_pipelines: Array[SignalToPipelineConfig]

func _enter_tree():
	var parent = get_parent()

	if node_id.length() > 0:
		Deus.set_node_id(parent, node_id)

	_init_components()
	_init_resources()

func _ready():
	_init_signals_to_pipelines()

func _init_components():
	var parent = get_parent()

	for comp in components:
		var comp_value = comp.component
		if comp.duplicate_component:
			comp_value = comp.component.duplicate(comp.duplicate_component_deep)

		Deus.set_component(parent, comp.component.get_script(), comp_value)

func _init_resources():
	var parent = get_parent()

	for res in resources:
		if res.resource_id.length() > 0 and res.resource:
			var res_value = res.resource
			if res.duplicate_resource:
				res_value = res.resource.duplicate(res.duplicate_resource_deep)

			Deus.register_resource(parent, res.resource, res.resource_id)



func _init_signals_to_pipelines():
	var parent = get_parent()

	for sig in signals_to_pipelines:
		var connect_node = parent

		if sig.execute_global:
			Deus.signal_to_global_pipeline(connect_node, sig.signal_name, sig.pipeline.get_script())
			return

		var target_node = Deus
		if sig.execution_node_path:
			target_node = parent.get_node(sig.execution_node_path)
		elif sig.execution_node_id.length() > 0:
			target_node = sig.execution_node_id

		Deus.signal_to_pipeline(connect_node, sig.signal_name, target_node, sig.pipeline.get_script())
