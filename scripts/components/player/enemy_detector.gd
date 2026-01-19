# Component for detecting enemies via cone-shaped detection (flashlight beam)
# Can be attached to any CharacterBody3D that needs enemy detection
class_name EnemyDetector
extends RefCounted

# Collision layer constants
const LAYER_PLAYER: int = 1
const LAYER_ENEMY: int = 2

# Configuration - can be overridden when creating instance
var detection_range: float = 60.0
var detection_height: float = 0.5
var cone_angle_rad: float = 1.047  # 60 degrees

# Collision configuration
var collision_mask: int = LAYER_PLAYER | LAYER_ENEMY

# Pre-calculated values for performance
var _range_sq: float
var _cos_cone_angle: float

# State
var was_facing_enemy := false

# Signals
signal enemy_detected(enemy: Node, distance: float)
signal enemy_lost


func _init(
	p_detection_range: float = 60.0,
	p_detection_height: float = 0.5,
	p_cone_angle_rad: float = 1.047,
	p_collision_mask: int = LAYER_PLAYER | LAYER_ENEMY
) -> void:
	detection_range = p_detection_range
	detection_height = p_detection_height
	cone_angle_rad = p_cone_angle_rad
	collision_mask = p_collision_mask
	_update_cached_values()


func _update_cached_values() -> void:
	_range_sq = detection_range * detection_range
	_cos_cone_angle = cos(cone_angle_rad)




func check_facing_enemy(character: CharacterBody3D, facing_dir: Vector3) -> void:
	# Main detection function - checks for enemies within cone area
	var space_state: PhysicsDirectSpaceState3D = character.get_world_3d().direct_space_state
	if space_state == null:
		return
	
	var origin: Vector3 = character.global_position + Vector3.UP * detection_height
	var facing_normalized: Vector3 = facing_dir.normalized()
	
	# Find closest enemy in cone
	var closest_enemy: Node = _find_closest_enemy_in_cone(
		space_state, character, origin, facing_normalized
	)
	
	# Update state and emit signals
	if closest_enemy != null:
		var enemy_pos: Vector3 = (closest_enemy as Node3D).global_position
		var distance: float = origin.distance_to(enemy_pos)
		_set_facing(true, closest_enemy, distance)
	else:
		_set_facing(false, null, 0.0)


func _find_closest_enemy_in_cone(
	space_state: PhysicsDirectSpaceState3D,
	character: CharacterBody3D,
	origin: Vector3,
	facing: Vector3
) -> Node:
	# Creating an array of enemies is more efficient than calling
	# get_tree().get_nodes_in_group() multiple times.
	# But still we will need to be more careful with the performance of this function.
	# Scanning the entire scene for enemies every frame is not efficient
	# especially if there are a lot of enemies.
	var enemies: Array[Node] = character.get_tree().get_nodes_in_group("enemies")
	var char_pos: Vector3 = character.global_position
	var char_rid: RID = character.get_rid()
	
	var closest_enemy: Node = null
	var closest_distance_sq: float = _range_sq
	
	for enemy_node in enemies:
		if not enemy_node is Node3D:
			continue
		
		var enemy_pos: Vector3 = (enemy_node as Node3D).global_position
		var to_enemy: Vector3 = enemy_pos - char_pos
		to_enemy.y = 0.0
		
		# Early exit: distance check (squared to avoid sqrt)
		var enemy_dist_sq: float = to_enemy.length_squared()
		if enemy_dist_sq > _range_sq:
			continue
		
		# Skip if enemy is at exact same position (prevents division by zero)
		if enemy_dist_sq < 0.0001:  # Very small threshold for floating point
			continue
		
		# Check if within cone angle
		var enemy_dist: float = sqrt(enemy_dist_sq)
		var dir_to_enemy: Vector3 = to_enemy / enemy_dist
		if facing.dot(dir_to_enemy) < _cos_cone_angle:
			continue
		
		# Check line of sight
		if not _has_line_of_sight(space_state, origin, enemy_pos, char_rid, enemy_node):
			continue
		
		# Found valid enemy - check if closer
		if enemy_dist_sq < closest_distance_sq:
			closest_distance_sq = enemy_dist_sq
			closest_enemy = enemy_node
	
	return closest_enemy


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


func _set_facing(is_facing: bool, enemy_node: Node, distance: float) -> void:
	if is_facing and not was_facing_enemy:
		if enemy_node != null:
			_log_detection(enemy_node, distance)
			enemy_detected.emit(enemy_node, distance)
	elif not is_facing and was_facing_enemy:
		print("NO LONGER FACING ENEMY")
		enemy_lost.emit()
	
	was_facing_enemy = is_facing


func _log_detection(enemy_node: Node, distance: float) -> void:
	var dist_str: String = "%.1f" % distance
	var log_msg: String = "NOW FACING ENEMY: " + enemy_node.name + " (distance: " + dist_str
	
	if "current_health" in enemy_node:
		log_msg += ", health: " + str(enemy_node.get("current_health"))
	
	if enemy_node is BaseEnemy:
		log_msg += ", frequency: " + "%.0f" % (enemy_node as BaseEnemy).frequency_hz + " Hz"
	
	print(log_msg + ")")
