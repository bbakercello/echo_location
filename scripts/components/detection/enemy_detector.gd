# Enemy-specific detector that extends ConeDetector
# Provides prioritized enemy targeting with persistence (Hades-style targeting)
#
# USAGE:
#   var detector = EnemyDetector.new()
#   detector.check_facing_object(player, facing_dir)  # Call each frame
#   var best = detector.get_best_enemy()  # Get best target
#
# Note: This class handles detection only. Input handling belongs in the player script.
class_name EnemyDetector
extends ConeDetector


func _init(
	p_collision_mask: int = GameConstants.LAYER_ENEMY | GameConstants.LAYER_ENVIRONMENT,
	p_detection_range: float = GameConstants.DETECTION_DEFAULT_RANGE,
	p_detection_height: float = GameConstants.DETECTION_DEFAULT_HEIGHT,
	p_cone_angle_rad: float = GameConstants.DETECTION_DEFAULT_CONE_ANGLE_RAD,
	p_update_continuously: bool = true
) -> void:
	super._init(
		p_collision_mask,
		p_detection_range,
		p_detection_height,
		p_cone_angle_rad,
		"enemies",
		p_update_continuously
	)


## Returns all detected enemies (unsorted)
func get_detected_enemies() -> Array[Node]:
	return get_detected_objects()


## Returns detected enemies sorted by priority (best target first)
func get_prioritized_enemies() -> Array[Node]:
	return get_prioritized_targets()


## Returns the single best enemy target (O(n), efficient)
func get_best_enemy() -> Node:
	return get_best_target()


## Returns the currently locked enemy target (may be null)
func get_current_enemy() -> Node:
	return get_current_target()


## Clears the current enemy target lock
func clear_enemy_lock() -> void:
	clear_target_lock()
