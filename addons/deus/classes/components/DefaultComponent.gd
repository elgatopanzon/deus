######################################################################
# @author      : ElGatoPanzon
# @class       : Component
# @created     : Thursday Jan 08, 2026 22:46:17 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : base component class
######################################################################

class_name DefaultComponent
extends Resource

# dirty flag -- true when component has been confirmed modified since last commit
var _dirty: bool = false
