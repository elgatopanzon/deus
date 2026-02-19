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

# per-script cache: true when all exported properties are flat (no Object/Array/Dictionary)
# checked once on first duplicate, result cached for all future instances of that script
static var _shallow_safe_cache: Dictionary = {}

# non-primitive Variant types that require deep duplication
const _DEEP_TYPES: Array[int] = [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY]

# returns true if this component's script has only primitive properties
static func _is_shallow_safe(instance: DefaultComponent) -> bool:
	var script = instance.get_script()
	if _shallow_safe_cache.has(script):
		return _shallow_safe_cache[script]
	var safe = true
	for prop in instance.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		# skip internal vars (prefixed with _)
		if prop.name.begins_with("_"):
			continue
		if prop.type in _DEEP_TYPES:
			safe = false
			break
	_shallow_safe_cache[script] = safe
	return safe

# duplicate with automatic shallow/deep selection based on property types
func smart_duplicate() -> DefaultComponent:
	if _is_shallow_safe(self):
		return duplicate(false)
	return duplicate(true)
