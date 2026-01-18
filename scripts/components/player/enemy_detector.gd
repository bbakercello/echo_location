# Component for detecting enemies via raycasting
class_name EnemyDetector
extends RefCounted

# Raycasting constants
const RAY_LENGTH := 60.0
const RAY_HEIGHT := 1.0
const CLOSE_RANGE_DISTANCE := 2.0  # Detect enemy if within this distance
const FAR_RANGE_DISTANCE := 12.0   # Check enemies up to this when wall blocks
const FACE_DOT_THRESHOLD := 0.7    # ~45 degree cone (cos(45°) ≈ 0.707)

# Pre-calculated squared distances for faster comparisons (avoid sqrt)
const CLOSE_RANGE_SQ := CLOSE_RANGE_DISTANCE * CLOSE_RANGE_DISTANCE
const FAR_RANGE_SQ := FAR_RANGE_DISTANCE * FAR_RANGE_DISTANCE

var was_facing_enemy := false
var on_enemy_detected: Callable
var on_enemy_lost: Callable

func check_facing_enemy(character: CharacterBody3D, facing_dir: Vector3) -> void:

	# Set the player mask to 1
	
	# Cast forward ray to detect enemies
	var space_state: PhysicsDirectSpaceState3D = character.get_world_3d().direct_space_state
	if space_state == null:
		return
	
	# Define the origin, facing direction and endpoint as vector constants
	# Vector3.UP is (0, 1, 0)
	var origin: Vector3 = character.global_position + Vector3.UP * RAY_HEIGHT
	var facing_normalized: Vector3 = facing_dir.normalized()
	var end: Vector3 = origin + facing_normalized * RAY_LENGTH
	
	# Create the query for the raycast using the origin, facing direction and endpoint
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	# Exclude the character from the raycast
	query.exclude = [character.get_rid()]
	# Collide with bodies
	query.collide_with_bodies = true
	# Don't collide with areas
	query.collide_with_areas = false
	# Collide with all layers - seems inefficient to collide with all layers
	# TODO: Optimize this to only collide with the layers that are needed
	query.collision_mask = 1 | 2

	# log the player mask, enemy layer and player layer
	

	
	var hit: Dictionary = space_state.intersect_ray(query)
	
	if hit.is_empty():
		_set_facing(false)
		return
	
	# Check if the hit is a Node and if it is, set the facing to true
	var hit_node: Node = hit.get("collider") as Node
	if hit_node == null:
		_set_facing(false)
		return
	
	# If we hit an enemy directly, we're facing it
	# We added the enemies to the "enemies" group in the Enemy scene
	if hit_node.is_in_group("enemies"):
		var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
		var hit_distance: float = hit_pos.distance_to(origin)
		_set_facing(true, hit_node, hit_distance)
		return
	
	# If we hit a wall, check for nearby enemies
	var wall_pos: Vector3 = hit.get("position", Vector3.ZERO)
	var wall_distance: float = wall_pos.distance_to(origin)
	if _check_nearby_enemies(character, facing_normalized, wall_distance):
		return
	
	_set_facing(false)


func _check_nearby_enemies(
	character: CharacterBody3D, 
	facing_normalized: Vector3, 
	max_distance: float
) -> bool:
	# Check for nearby enemies when forward ray is blocked by a wall
	var enemies: Array = character.get_tree().get_nodes_in_group("enemies")
	var char_pos: Vector3 = character.global_position
	var max_dist_sq: float = max_distance * max_distance
	
	for enemy_node in enemies:
		if not enemy_node is Node3D:
			continue
		
		var enemy_pos: Vector3 = (enemy_node as Node3D).global_position
		var to_enemy: Vector3 = enemy_pos - char_pos
		to_enemy.y = 0.0
		
		# Use squared distance to avoid expensive sqrt
		var enemy_dist_sq: float = to_enemy.length_squared()
		
		# Early exit: skip if too far (beyond wall AND beyond far range limit)
		if enemy_dist_sq > max_dist_sq and enemy_dist_sq > FAR_RANGE_SQ:
			continue
		
		# Check if enemy is in front (dot product check)
		# Calculate distance once (needed for both checks)
		var enemy_dist: float = sqrt(enemy_dist_sq)
		var dir_to_enemy: Vector3 = to_enemy / enemy_dist
		if facing_normalized.dot(dir_to_enemy) < FACE_DOT_THRESHOLD:
			continue
		
		# Detect if enemy is very close OR closer than the wall
		if enemy_dist_sq < CLOSE_RANGE_SQ or enemy_dist < max_distance:
			_set_facing(true, enemy_node, enemy_dist)
			return true
	
	return false


func _set_facing(is_facing: bool, enemy_node: Node = null, distance: float = 0.0) -> void:
	# Handle state changes for facing enemy with minimal logging.
	if is_facing and not was_facing_enemy:
		if enemy_node != null:
			# Build log message efficiently
			var dist_str: String = "%.1f" % distance
			var log_msg: String = "NOW FACING ENEMY: " + enemy_node.name + " (distance: " + dist_str
			
			# Log health if available (check property existence)
			if "current_health" in enemy_node:
				log_msg += ", health: " + str(enemy_node.get("current_health"))
			
			# Log frequency if it's a BaseEnemy (combine type check with access)
			if enemy_node is BaseEnemy:
				log_msg += ", frequency: " + "%.0f" % (enemy_node as BaseEnemy).frequency_hz + " Hz"
			
			print(log_msg + ")")
			if on_enemy_detected.is_valid():
				on_enemy_detected.call(enemy_node, distance)
		else:
			print("NOW FACING ENEMY")
			if on_enemy_detected.is_valid():
				on_enemy_detected.call()
	elif not is_facing and was_facing_enemy:
		print("NO LONGER FACING ENEMY")
		if on_enemy_lost.is_valid():
			on_enemy_lost.call()
	
	was_facing_enemy = is_facing
