# Custom error types for detection system
# Godot doesn't have traditional exceptions, so we use a Result-like pattern
# with error codes and descriptive messages

class_name DetectionError
extends RefCounted

## Error codes for detection system failures
enum ErrorCode {
	INVALID_CHARACTER,  # Character node is null or invalid
	INVALID_SPACE_STATE,  # Physics space state is null
	INVALID_FACING_DIRECTION,  # Facing direction is zero or invalid
	INVALID_DETECTION_GROUP,  # Detection group is empty or invalid
	INVALID_CONFIGURATION,  # Detector configuration is invalid
	INVALID_COLLISION_MASK,  # Collision mask is invalid
	INVALID_DETECTION_RANGE,  # Detection range is <= 0
	INVALID_DETECTION_HEIGHT,  # Detection height is < 0
	INVALID_CONE_ANGLE,  # Cone angle is <= 0 or > PI
	SPATIAL_PARTITION_ERROR,  # Spatial partitioning failed
	RAYCAST_FAILED  # Raycast query failed
}

var error_code: ErrorCode
var message: String
var context: Dictionary = {}  # Additional context data

## Creates a new DetectionError
## @param p_error_code: The error code
## @param p_message: Human-readable error message
## @param p_context: Optional dictionary with additional context
func _init(p_error_code: ErrorCode, p_message: String, p_context: Dictionary = {}) -> void:
	error_code = p_error_code
	message = p_message
	context = p_context


## Returns a formatted error message with context
func get_formatted_message() -> String:
	var result: String = "DetectionError [%s]: %s" % [ErrorCode.keys()[error_code], message]
	if not context.is_empty():
		var context_str: String = ""
		for key in context.keys():
			context_str += ", %s: %s" % [key, context[key]]
		result += context_str
	return result


## Returns true if this is a critical error that should stop detection
func is_critical() -> bool:
	match error_code:
		ErrorCode.INVALID_CHARACTER, ErrorCode.INVALID_SPACE_STATE, ErrorCode.INVALID_CONFIGURATION:
			return true
		_:
			return false


## Returns true if this is a recoverable error (can continue with degraded functionality)
func is_recoverable() -> bool:
	return not is_critical()
