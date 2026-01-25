# Handles target prioritization and persistence for detection systems
# Provides Hades-style "sticky" targeting to prevent flickering between similar targets
#
# USAGE:
#   var prioritizer = TargetPrioritizer.new()
#   prioritizer.update(detected_objects, detector_pos, facing_dir, range, cos_angle)
#   var best = prioritizer.get_best_target()
#   var all_sorted = prioritizer.get_prioritized_targets()
class_name TargetPrioritizer
extends RefCounted

# Target persistence state
var _current_target: Node = null
var _target_lock_frame: int = -1

# Cached context for scoring (updated each frame via update())
var _detected_objects: Array[Node] = []  # Reference to caller's array - do NOT clear
var _detected_set: Dictionary = {}  # O(1) lookup for has() checks - maps instance_id -> true
var _detector_pos: Vector3 = Vector3.ZERO
var _facing_dir: Vector3 = Vector3.FORWARD
var _detection_range: float = 60.0
var _cos_cone_angle: float = 0.5

# Reusable arrays to avoid per-frame allocations
var _reusable_result_array: Array[Node] = []
var _score_cache: Dictionary = {}  # Maps instance_id -> score for sorting

# Signal for target change events
signal target_changed(new_target: Node, old_target: Node)


## Updates the prioritizer with current detection context
## Call this each frame after detection runs
## @param detected_objects: Array of detected nodes from ConeDetector
## @param detector_pos: Position of the detector owner
## @param facing_dir: Normalized facing direction
## @param p_detection_range: Maximum detection range
## @param cos_cone_angle: Cosine of cone angle for angle scoring
func update(
	detected_objects: Array[Node],
	detector_pos: Vector3,
	facing_dir: Vector3,
	p_detection_range: float,
	cos_cone_angle: float
) -> void:
	_detected_objects = detected_objects
	_detector_pos = detector_pos
	_facing_dir = facing_dir
	_detection_range = p_detection_range
	_cos_cone_angle = cos_cone_angle
	
	# Build O(1) lookup set for has() checks
	_detected_set.clear()
	for obj in _detected_objects:
		if is_instance_valid(obj):
			_detected_set[obj.get_instance_id()] = true
	
	_update_target_persistence()


## Returns detected objects sorted by priority score (best target first)
## Note: Returns internal array - do not modify. Call duplicate() if you need to modify.
## @return: Array[Node] sorted by priority (highest score first)
func get_prioritized_targets() -> Array[Node]:
	if _detected_objects.is_empty():
		return []
	
	_reusable_result_array.clear()
	_score_cache.clear()
	
	# Pre-calculate scores O(n) before sorting
	for obj in _detected_objects:
		if not is_instance_valid(obj) or not obj is Node3D:
			continue
		_reusable_result_array.append(obj)
		_score_cache[obj.get_instance_id()] = _calculate_score_for_node(obj)
	
	# Sort using cached scores O(n log n)
	_reusable_result_array.sort_custom(_compare_targets_by_cached_score)
	
	return _reusable_result_array


## Returns the single best target based on priority scoring (O(n), no sorting)
## @return: Node or null if no targets detected
func get_best_target() -> Node:
	return _find_best_target_unsorted()


## Returns the current locked target (may be null)
func get_current_target() -> Node:
	return _current_target


## Clears the current target lock, forcing re-evaluation
func clear_target_lock() -> void:
	var old_target: Node = _current_target
	_current_target = null
	_target_lock_frame = -1
	if old_target != null:
		target_changed.emit(null, old_target)


## Resets all state
func reset() -> void:
	_current_target = null
	_target_lock_frame = -1
	# Don't clear _detected_objects - it's a reference to caller's array
	# Just reset our reference to an empty array
	_detected_objects = []
	_detected_set.clear()
	_detector_pos = Vector3.ZERO
	_facing_dir = Vector3.FORWARD
	_reusable_result_array.clear()
	_score_cache.clear()


## Finds best target in O(n) without sorting
func _find_best_target_unsorted() -> Node:
	if _detected_objects.is_empty():
		return null
	
	var best_target: Node = null
	var best_score: float = -1.0
	
	for obj in _detected_objects:
		if not is_instance_valid(obj) or not obj is Node3D:
			continue
		
		var score: float = _calculate_score_for_node(obj)
		if score > best_score:
			best_score = score
			best_target = obj
	
	return best_target


## Calculates priority score for a single node (inline, no object allocation)
func _calculate_score_for_node(target: Node) -> float:
	if not is_instance_valid(target) or not target is Node3D:
		return -1.0
	
	var target_pos: Vector3 = (target as Node3D).global_position
	var to_target: Vector3 = target_pos - _detector_pos
	to_target.y = 0.0
	
	var dist_sq: float = to_target.length_squared()
	
	# Very close targets: give max score (avoid division issues)
	if dist_sq < GameConstants.DETECTION_MIN_DISTANCE_SQ:
		return 1.0  # Max score for extremely close targets
	
	var dist: float = sqrt(dist_sq)
	
	# Distance score: closer = higher (0.0 to 1.0)
	var distance_score: float = 1.0 - clamp(dist / _detection_range, 0.0, 1.0)
	
	# Angle score: more centered = higher (0.0 to 1.0)
	# Use actual normalization to ensure unit vector for correct dot product
	var to_target_normalized: Vector3 = to_target / dist
	var dot: float = _facing_dir.dot(to_target_normalized)
	
	# Prevent division by zero when cone_angle is 0 (cos = 1.0)
	var angle_score: float = 0.0
	var denominator: float = 1.0 - _cos_cone_angle
	if denominator > GameConstants.ANGLE_DENOMINATOR_EPSILON:
		angle_score = clamp((dot - _cos_cone_angle) / denominator, 0.0, 1.0)
	else:
		# Cone angle is ~0, only direct hits count
		angle_score = 1.0 if dot >= GameConstants.ANGLE_DIRECT_HIT_THRESHOLD else 0.0
	
	# Weighted combination
	var base_score: float = (
		distance_score * GameConstants.TARGET_PRIORITY_DISTANCE_WEIGHT +
		angle_score * GameConstants.TARGET_PRIORITY_ANGLE_WEIGHT
	)
	
	# Persistence bonus
	if target == _current_target and _is_target_lock_active():
		base_score += GameConstants.TARGET_PERSISTENCE_BONUS
	
	return base_score


## Comparison function for sorting targets using pre-calculated cached scores
func _compare_targets_by_cached_score(a: Node, b: Node) -> bool:
	var id_a: int = a.get_instance_id()
	var id_b: int = b.get_instance_id()
	var score_a: float = _score_cache.get(id_a, -1.0)
	var score_b: float = _score_cache.get(id_b, -1.0)
	return score_a > score_b


func _update_target_persistence() -> void:
	var old_target: Node = _current_target
	
	# Check if current target is still valid and detected
	if _current_target != null:
		if not is_instance_valid(_current_target):
			_current_target = null
			_target_lock_frame = -1
		elif not _current_target.get_instance_id() in _detected_set:
			if not _is_target_lock_active():
				_current_target = null
				_target_lock_frame = -1
	
	# If no current target, find best (O(n), no sorting)
	if _current_target == null and not _detected_objects.is_empty():
		var best: Node = _find_best_target_unsorted()
		if best != null:
			_current_target = best
			_target_lock_frame = Engine.get_process_frames()
	
	# Emit signal if target changed
	if _current_target != old_target:
		target_changed.emit(_current_target, old_target)


func _is_target_lock_active() -> bool:
	if _target_lock_frame < 0:
		return false
	
	var current_frame: int = Engine.get_process_frames()
	var frames_since_lock: int = current_frame - _target_lock_frame
	return frames_since_lock < GameConstants.TARGET_PERSISTENCE_FRAMES
