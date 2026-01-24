# Enemy-specific detector that extends ConeDetector
class_name EnemyDetector
extends "res://scripts/components/detection/cone_detector.gd"

# Track previous click state to only log once per click
var _was_clicking: bool = false

func _init(
	p_collision_mask: int = GameConstants.LAYER_ENEMY | GameConstants.LAYER_ENVIRONMENT,
	p_detection_range: float = GameConstants.DETECTION_DEFAULT_RANGE,
	p_detection_height: float = GameConstants.DETECTION_DEFAULT_HEIGHT,
	p_cone_angle_rad: float = GameConstants.DETECTION_DEFAULT_CONE_ANGLE_RAD,
	p_update_continuously: bool = false
) -> void:
	super._init(
		p_collision_mask,
		p_detection_range,
		p_detection_height,
		p_cone_angle_rad,
		"enemies",  # Set detection group to "enemies"
		p_update_continuously
	)


func check_facing_enemy(detector_owner: CharacterBody3D, facing_dir: Vector3) -> void:
	var is_clicking: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Update detection based on update_continuously flag
	if update_continuously:
		# Update cache every frame
		check_facing_object(detector_owner, facing_dir)
	else:
		# Only update on click
		if is_clicking and not _was_clicking:
			check_facing_object(detector_owner, facing_dir)
	
	# Query cache and log only on initial left-click (not while held)
	if is_clicking and not _was_clicking:
		var enemies: Array[Node] = get_detected_objects()
		if enemies.size() > 0:
			_log_detection(enemies[0])
		else:
			print("NO ENEMY DETECTED")
	
	_was_clicking = is_clicking


func get_detected_enemies() -> Array[Node]:
	# Convenience method with enemy-specific naming
	return get_detected_objects()


func _log_detection(enemy_node: Node) -> void:
	# Validate enemy node before accessing properties
	if not is_instance_valid(enemy_node):
		return
	
	# Build message efficiently - print() accepts multiple arguments which is more efficient
	# than string concatenation in GDScript
	var message: String = "ENEMY DETECTED: " + enemy_node.name
	
	if "current_health" in enemy_node:
		var health: int = enemy_node.get("current_health")
		message += ", health: " + str(health)
	
	if enemy_node is BaseEnemy:
		var frequency: float = (enemy_node as BaseEnemy).frequency_hz
		message += ", frequency: " + "%.0f" % frequency + " Hz"
	
	print(message)
