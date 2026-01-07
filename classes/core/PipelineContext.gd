######################################################################
# @author      : ElGatoPanzon
# @class       : PipelineContext
# @created     : Wednesday Jan 07, 2026 12:56:44 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : context object for use with pipeline execution
######################################################################

class_name PipelineContext
extends Resource

var world
var components = {}
var payload
var result

# allows dot-access to components: context.CompName
func _get(property):
	if components.has(property):
		return components[property]
	else:
		return null
