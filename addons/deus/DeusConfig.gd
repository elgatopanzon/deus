######################################################################
# @author      : ElGatoPanzon
# @class       : DeusConfig
# @created     : Friday Jan 09, 2026 21:40:02 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : setup and init Deus project config
######################################################################

class_name DeusConfig

static var project_config_options: Array[Dictionary] = [
    {"name": "addons/deus/components/enable_component_lifecycle_pipelines", "default": true, "type": TYPE_BOOL, "hint": PROPERTY_HINT_NONE},
]

static func init_project_config():
	# add plugin project config options
	for config in project_config_options:
		if not ProjectSettings.has_setting(config.name):
			ProjectSettings.set_setting(config.name, config.default)
			ProjectSettings.set_initial_value(config.name, config.default)
			ProjectSettings.add_property_info(config)
