# Enemy-specific detector that extends ConeDetector
class_name EnemyDetector
extends "res://scripts/components/player/cone_detector.gd"

# Track previous click state to only log once per click
var _was_clicking: bool = false

func _init(
	p_detection_range: float = 60.0,
	p_detection_height: float = 0.5,
	p_cone_angle_rad: float = 1.047,
	p_collision_mask: int = LAYER_PLAYER | LAYER_ENEMY
) -> void:
	super._init(
		p_detection_range,
		p_detection_height,
		p_cone_angle_rad,
		"enemies",  # Set detection group to "enemies"
		p_collision_mask
	)


func check_facing_enemy(character: CharacterBody3D, facing_dir: Vector3) -> void:
	# Update detection state every frame
	check_facing_object(character, facing_dir)
	
	# Query cache and log only on initial left-click (not while held)
	var is_clicking: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
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
	var log_msg: String = "ENEMY DETECTED: " + enemy_node.name
	
	if "current_health" in enemy_node:
		log_msg += ", health: " + str(enemy_node.get("current_health"))
	
	if enemy_node is BaseEnemy:
		log_msg += ", frequency: " + "%.0f" % (enemy_node as BaseEnemy).frequency_hz + " Hz"
	
	print(log_msg)
