# Generic component for detecting objects via cone-shaped detection (flashlight beam)
# Can be attached to any CharacterBody3D that needs object detection
# Configured via detection_group to detect different types (enemies, items, interactables, etc.)
class_name ConeDetector
extends RefCounted

# Collision layer constants
const LAYER_PLAYER: int = 1
const LAYER_ENEMY: int = 2

# Configuration - can be overridden when creating instance
var detection_range: float = 60.0
var detection_height: float = 0.5
var cone_angle_rad: float = 1.047  # 60 degrees
var detection_group: String = ""  # Group name to detect (e.g., "enemies", "items", "interactables")

# Collision configuration
var collision_mask: int = LAYER_PLAYER | LAYER_ENEMY

# Pre-calculated values for performance
var _range_sq: float
var _cos_cone_angle: float

# State - query this directly instead of using signals
var detected_objects: Array[Node] = []


func _init(
	p_detection_range: float = 60.0,
	p_detection_height: float = 0.5,
	p_cone_angle_rad: float = 1.047,
	p_detection_group: String = "",
	p_collision_mask: int = LAYER_PLAYER | LAYER_ENEMY
) -> void:
	detection_range = p_detection_range
	detection_height = p_detection_height
	cone_angle_rad = p_cone_angle_rad
	detection_group = p_detection_group
	collision_mask = p_collision_mask
	_update_cached_values()


func _update_cached_values() -> void:
	_range_sq = detection_range * detection_range
	_cos_cone_angle = cos(cone_angle_rad)


func check_facing_object(character: CharacterBody3D, facing_dir: Vector3) -> void:
	# Main detection function - checks for objects within cone area
	if detection_group.is_empty():
		detected_objects.clear()
		return
	
	var space_state: PhysicsDirectSpaceState3D = character.get_world_3d().direct_space_state
	if space_state == null:
		detected_objects.clear()
		return
	
	var origin: Vector3 = character.global_position + Vector3.UP * detection_height
	
	# Build new array first, then swap atomically to avoid race conditions
	var new_detected: Array[Node] = []
	_find_all_objects_in_cone(space_state, character, origin, facing_dir, new_detected)
	detected_objects = new_detected


func _find_all_objects_in_cone(
	space_state: PhysicsDirectSpaceState3D,
	character: CharacterBody3D,
	origin: Vector3,
	facing: Vector3,
	result_array: Array[Node]
) -> void:
	# Populates result_array with all objects in the detection cone
	# Reuses existing array to avoid allocations
	var objects: Array[Node] = character.get_tree().get_nodes_in_group(detection_group)
	var char_pos: Vector3 = character.global_position
	var char_rid: RID = character.get_rid()
	
	for object_node in objects:
		if not object_node is Node3D:
			continue
		
		var object_pos: Vector3 = (object_node as Node3D).global_position
		var to_object: Vector3 = object_pos - char_pos
		to_object.y = 0.0
		
		# Early exit: distance check (squared to avoid sqrt)
		var object_dist_sq: float = to_object.length_squared()
		if object_dist_sq > _range_sq:
			continue
		
		# Skip if object is at exact same position (prevents division by zero)
		if object_dist_sq < 0.0001:
			continue
		
		# Check if within cone angle
		var object_dist: float = sqrt(object_dist_sq)
		var dir_to_object: Vector3 = to_object / object_dist
		if facing.dot(dir_to_object) < _cos_cone_angle:
			continue
		
		# Check line of sight
		if not _has_line_of_sight(space_state, origin, object_pos, char_rid, object_node):
			continue
		
		# Found valid object - add to result array
		result_array.append(object_node)


func _has_line_of_sight(
	space_state: PhysicsDirectSpaceState3D,
	origin: Vector3,
	target: Vector3,
	exclude_rid: RID,
	target_node: Node
) -> bool:
	# Check for clear line of sight to target
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [exclude_rid]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = collision_mask
	
	var hit: Dictionary = space_state.intersect_ray(query)
	
	# Valid if: no hit (clear) OR hit the target directly
	if hit.is_empty():
		return true
	
	var hit_collider: Node = hit.get("collider") as Node
	return hit_collider == target_node


func get_detected_objects() -> Array[Node]:
	# Public getter for current detected objects
	return detected_objects


func is_detecting_objects() -> bool:
	# Convenience method to check if any objects are detected
	return detected_objects.size() > 0
