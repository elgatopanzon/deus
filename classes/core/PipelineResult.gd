######################################################################
# @author      : ElGatoPanzon
# @class       : PipelineResult
# @created     : Wednesday Jan 07, 2026 12:58:07 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : result object returned after pipeline execution
######################################################################

class_name PipelineResult
extends Resource

const SUCCESS = "success"
const FAILED = "failed"
const CANCELLED = "cancelled"

var state: String = SUCCESS
var error_code: int = 0
var error_message: String = ""

func reset():
	state = SUCCESS
	error_code = 0
	error_message = ""

func noop(msg = ""):
	state = CANCELLED
	error_message = msg

func fail(code = 1, msg = ""):
	state = FAILED
	error_code = code
	error_message = msg

func cancel(msg = ""):
	state = CANCELLED
	error_message = msg
