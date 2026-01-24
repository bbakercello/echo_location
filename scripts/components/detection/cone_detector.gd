# Generic component for detecting objects via cone-shaped detection (flashlight beam)
# Can be attached to any CharacterBody3D that needs object detection
# Configured via detection_group to detect different types (enemies, items, interactables, etc.)
#
# USAGE EXAMPLE:
#   var detector = ConeDetector.new(
#       GameConstants.LAYER_ENEMY | GameConstants.LAYER_ENVIRONMENT,
#       60.0,  # detection_range
#       0.5,   # detection_height
#       1.047, # cone_angle_rad (60 degrees)
#       "enemies",  # detection_group
#       true,  # update_continuously
#       true,  # enable_spatial_partitioning
#       true   # enable_raycast_optimization
#   )
#   detector.check_facing_object(detector_owner, facing_direction)
#   var detected: Array[Node] = detector.get_detected_objects()
# Some future considerations:
# - get_world_3d() and get_tree() is called multiple times in thsi script. 
#   This could be optimized by caching the values. 
# However, if if the character is moving or the scene is changing etc,
# the cached values will be invalid.
class_name ConeDetector
extends RefCounted

# DetectionError is available as a global class_name, no need to preload

# ============================================================================
# DATA STRUCTURES
# ============================================================================

# Data structure for object detection parameters (reduces function parameter count)
class DetectionParams:
	var char_pos: Vector3
	var facing: Vector3
	var origin: Vector3
	var char_rid: RID
	var space_state: PhysicsDirectSpaceState3D
	var close_range_sq: float
	var mid_range_sq: float
	var should_use_optimizations: bool

# ============================================================================
# CONFIGURATION
# ============================================================================

# Configuration - set via _init() or setter methods
# NOTE: Changing these directly after initialization will NOT update cached values.
# Use setter methods (set_detection_range, etc.) to change configuration safely.
var detection_range: float  # Maximum detection distance in units
var detection_height: float  # Height offset for raycast origin
var cone_angle_rad: float  # Cone angle in radians
var detection_group: String = ""  # Group name to detect (e.g., "enemies", "items", "interactables")
# If true, updates cache every frame. If false, only updates when check_facing_object() is called
# NOTE: This flag is used by subclasses (e.g., EnemyDetector) to control update behavior
var update_continuously: bool = true

# Optimization settings
var enable_spatial_partitioning: bool = true  # Use spatial cells to reduce checks
var enable_raycast_optimization: bool = true  # Skip raycasts for distant objects
# Auto-disable optimizations for small scenes (<20 objects) for better performance
var _auto_disable_optimizations: bool = true

# Collision configuration
# collision_mask determines what layers the raycast can hit for line-of-sight checks
# Pass in any combination of layers using bitwise OR
# Example: GameConstants.LAYER_ENEMY | GameConstants.LAYER_ENVIRONMENT
var collision_mask: int

# Pre-calculated values for performance (updated automatically when config changes)
var _range_sq: float
var _cos_cone_angle: float
var _cos_cone_angle_sq: float  # Cached squared value for cone angle check optimization

# Cached raycast optimization thresholds (only recalculated when range changes)
var _cached_close_range_sq: float
var _cached_mid_range_sq: float

# Cached Vector3 calculations
var _cached_height_offset: Vector3 = Vector3.ZERO

# Constants are now defined in GameConstants autoload for centralized configuration
# Import constants from GameConstants for consistency across the project
var _cached_group_members: Array[Node] = []
var _cache_frame_counter: int = 0

# Spatial partitioning cache
var _spatial_cells: Dictionary = {}  # Dictionary mapping cell keys (int) to Array[Node]
var _last_partition_pos: Vector3 = Vector3.ZERO
var _partition_dirty: bool = true
var _last_rebuild_frame: int = -1
var _spatial_cell_size: float = 0.0  # Calculated from detection_range

# Reusable objects to avoid per-frame allocations
var _reusable_detection_params: DetectionParams = null
var _reusable_objects_dict: Dictionary = {}  # Reused for spatial partitioning
var _reusable_objects_array: Array[Node] = []  # Reused for array conversion
var _reusable_exclude_array: Array[RID] = []  # Reused for raycast exclude list

# State - private, access via get_detected_objects()
var _detected_objects: Array[Node] = []

# Error handling
var _last_error: DetectionError = null  # Last error that occurred
# Signal for error communication (RefCounted classes support signals in Godot 4+)
signal error_occurred(error: DetectionError)  # Emitted when a critical error occurs


## Creates a new ConeDetector instance
## @param p_collision_mask: Required - collision layers for line-of-sight (bitwise OR)
##   Example: GameConstants.LAYER_ENEMY | GameConstants.LAYER_ENVIRONMENT
## @param p_detection_range: Maximum detection distance in units (default: 60.0)
## @param p_detection_height: Height offset for raycast origin (default: 0.5)
## @param p_cone_angle_rad: Cone angle in radians (default: 1.047 = 60 degrees)
## @param p_detection_group: Group name to detect (e.g., "enemies", "items")
## @param p_update_continuously: If true, updates every frame. If false, on-demand
## @param p_enable_spatial_partitioning: Enable spatial optimization (auto-disabled <20 objects)
## @param p_enable_raycast_optimization: Enable distance-based raycast skipping
##   (auto-disabled <20 objects)
func _init(
	p_collision_mask: int,  # Required - must be explicitly provided
	p_detection_range: float = GameConstants.DETECTION_DEFAULT_RANGE,
	p_detection_height: float = GameConstants.DETECTION_DEFAULT_HEIGHT,
	p_cone_angle_rad: float = GameConstants.DETECTION_DEFAULT_CONE_ANGLE_RAD,
	p_detection_group: String = "",
	p_update_continuously: bool = true,
	p_enable_spatial_partitioning: bool = true,
	p_enable_raycast_optimization: bool = true
) -> void:
	# Input validation with custom error handling
	# Use helper function to reduce code duplication
	if p_collision_mask <= 0:
		_handle_validation_error(
			DetectionError.ErrorCode.INVALID_COLLISION_MASK,
			"collision_mask must be > 0. Using default value.",
			{"provided": p_collision_mask, "default": 1}
		)
		p_collision_mask = 1  # Default to layer 1
	
	if p_detection_range <= 0.0:
		_handle_validation_error(
			DetectionError.ErrorCode.INVALID_DETECTION_RANGE,
			"detection_range must be > 0. Using default value.",
			{"provided": p_detection_range, "default": GameConstants.DETECTION_DEFAULT_RANGE}
		)
		p_detection_range = GameConstants.DETECTION_DEFAULT_RANGE
	
	if p_detection_height < 0.0:
		_handle_validation_error(
			DetectionError.ErrorCode.INVALID_DETECTION_HEIGHT,
			"detection_height must be >= 0. Using default value.",
			{"provided": p_detection_height, "default": GameConstants.DETECTION_DEFAULT_HEIGHT}
		)
		p_detection_height = GameConstants.DETECTION_DEFAULT_HEIGHT
	
	if p_cone_angle_rad <= 0.0 or p_cone_angle_rad > PI:
		var default_angle: float = GameConstants.DETECTION_DEFAULT_CONE_ANGLE_RAD
		_handle_validation_error(
			DetectionError.ErrorCode.INVALID_CONE_ANGLE,
			"cone_angle_rad must be > 0 and <= PI. Using default value.",
			{"provided": p_cone_angle_rad, "default": default_angle}
		)
		p_cone_angle_rad = GameConstants.DETECTION_DEFAULT_CONE_ANGLE_RAD
	
	collision_mask = p_collision_mask
	detection_range = p_detection_range
	detection_height = p_detection_height
	cone_angle_rad = p_cone_angle_rad
	detection_group = p_detection_group
	update_continuously = p_update_continuously
	enable_spatial_partitioning = p_enable_spatial_partitioning
	enable_raycast_optimization = p_enable_raycast_optimization
	_update_cached_values()


func _update_cached_values() -> void:
	# Use assert for debugging invariants (best practice)
	assert(detection_range > 0.0, "detection_range must be > 0")
	assert(cone_angle_rad > 0.0 and cone_angle_rad <= PI, "cone_angle_rad must be > 0 and <= PI")
	
	_range_sq = detection_range * detection_range
	_cos_cone_angle = cos(cone_angle_rad)
	_cos_cone_angle_sq = _cos_cone_angle * _cos_cone_angle  # Cache squared value for optimization
	# Update spatial cell size based on detection range
	_spatial_cell_size = detection_range * GameConstants.DETECTION_SPATIAL_CELL_SIZE_RATIO
	
	# Update cached raycast optimization thresholds (only recalculated when range changes)
	var close_ratio: float = GameConstants.DETECTION_RAYCAST_OPTIMIZATION_CLOSE_RANGE_RATIO
	var mid_ratio: float = GameConstants.DETECTION_RAYCAST_OPTIMIZATION_MID_RANGE_RATIO
	var close_ratio_sq: float = close_ratio * close_ratio
	var mid_ratio_sq: float = mid_ratio * mid_ratio
	_cached_close_range_sq = _range_sq * close_ratio_sq
	_cached_mid_range_sq = _range_sq * mid_ratio_sq
	
	# Update cached height offset
	_cached_height_offset = Vector3.UP * detection_height


## Main detection function - checks for objects within cone area
## Call this every frame (or on-demand if update_continuously is false)
## @param detector_owner: The CharacterBody3D performing the detection
##   (e.g., player, NPC, enemy)
## @param facing_dir: The direction the detector_owner is facing
##   (normalized or not, will be normalized)
## Results are stored in detected_objects array, query with get_detected_objects()
func check_facing_object(detector_owner: CharacterBody3D, facing_dir: Vector3) -> void:
	# If update_continuously is false, this must be called manually when needed
	
	# Input validation with error handling (using helper functions)
	if not is_instance_valid(detector_owner):
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_CHARACTER,
			"Detector owner node is invalid or null.",
			{"detector_owner": detector_owner}
		)
		_detected_objects.clear()
		return
	
	if detection_group.is_empty():
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_DETECTION_GROUP,
			"detection_group is empty. No objects will be detected.",
			{"group": detection_group},
			false  # Warning, not critical
		)
		_detected_objects.clear()
		return
	
	var world: World3D = detector_owner.get_world_3d()
	if world == null:
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_CHARACTER,
			"Detector owner has no valid world_3d.",
			{"detector_owner": detector_owner}
		)
		_detected_objects.clear()
		return
	
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_SPACE_STATE,
			"Physics space state is null. Cannot perform raycasts.",
			{"detector_owner": detector_owner}
		)
		_detected_objects.clear()
		return
	
	# Normalize facing direction (defensive programming)
	# Check original vector length first to avoid unnecessary normalization
	var facing_length_sq: float = facing_dir.length_squared()
	if facing_length_sq < GameConstants.DETECTION_MIN_FACING_LENGTH_SQ:
		# Zero or near-zero vector - cannot determine direction
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_FACING_DIRECTION,
			"Facing direction is zero or too small. Cannot determine detection direction.",
			{"facing_dir": facing_dir, "length_sq": facing_length_sq},
			false  # Warning, can recover
		)
		_detected_objects.clear()
		return
	
	var facing_normalized: Vector3 = facing_dir.normalized()
	
	# Use cached height offset to avoid Vector3 allocation
	var origin: Vector3 = detector_owner.global_position + _cached_height_offset
	
	# Build new array first, then swap atomically to avoid race conditions
	# Clear and reuse array to avoid allocation
	_detected_objects.clear()
	_find_all_objects_in_cone(
		space_state, detector_owner, origin, facing_normalized, _detected_objects
	)


func _find_all_objects_in_cone(
	space_state: PhysicsDirectSpaceState3D,
	detector_owner: CharacterBody3D,
	origin: Vector3,
	facing: Vector3,
	result_array: Array[Node]
) -> void:
	# Populates result_array with all objects in the detection cone
	# Reuses existing array to avoid allocations
	
	# Validate detector_owner is still valid
	if not is_instance_valid(detector_owner):
		return
	
	var owner_pos: Vector3 = detector_owner.global_position
	var owner_rid: RID = detector_owner.get_rid()
	
	# Get objects to check - use spatial partitioning if enabled and beneficial
	var group_members: Array[Node] = _get_group_members(detector_owner)
	# Determine if optimizations should be used (for raycast optimization and spatial partitioning)
	var should_use_optimizations: bool = _should_use_optimizations(group_members)
	var objects: Array[Node] = _get_objects_to_check(
		detector_owner, owner_pos, group_members, should_use_optimizations
	)
	
	# Reuse DetectionParams object to avoid allocation
	if _reusable_detection_params == null:
		_reusable_detection_params = DetectionParams.new()
	
	var detection_params: DetectionParams = _reusable_detection_params
	detection_params.char_pos = owner_pos
	detection_params.facing = facing
	detection_params.origin = origin
	detection_params.char_rid = owner_rid
	detection_params.space_state = space_state
	# Use cached raycast optimization thresholds (no Dictionary allocation)
	detection_params.close_range_sq = _cached_close_range_sq
	detection_params.mid_range_sq = _cached_mid_range_sq
	detection_params.should_use_optimizations = should_use_optimizations
	
	# Check each object against detection criteria
	for object_node in objects:
		if _is_object_in_cone(object_node, detection_params):
			result_array.append(object_node)


# ============================================================================
# HELPER FUNCTIONS - Object Filtering and Validation
# ============================================================================

func _should_use_optimizations(group_members: Array[Node]) -> bool:
	# Determines if optimizations should be used based on scene size
	# Auto-disable optimizations for small scenes
	var min_objects: int = GameConstants.DETECTION_SPATIAL_MIN_OBJECTS
	var has_enough_objects: bool = group_members.size() >= min_objects
	return not _auto_disable_optimizations or has_enough_objects


func _get_objects_to_check(
	detector_owner: CharacterBody3D,
	owner_pos: Vector3,
	group_members: Array[Node],
	should_use_optimizations: bool
) -> Array[Node]:
	# Returns the list of objects to check, using spatial partitioning if beneficial
	if should_use_optimizations and enable_spatial_partitioning:
		return _get_objects_in_nearby_cells(detector_owner, owner_pos, group_members)
	
	return group_members


# Removed _calculate_raycast_optimization_thresholds() - now using cached values directly
# Raycast optimization thresholds are calculated once in _update_cached_values() and stored in
# _cached_close_range_sq and _cached_mid_range_sq to avoid Dictionary allocation


func _is_object_in_cone(object_node: Node, params: DetectionParams) -> bool:
	# Checks if an object meets all detection criteria (distance, angle, line of sight)
	# Returns true if object should be detected
	
	# Validate object is still valid and is a Node3D
	if not is_instance_valid(object_node) or not object_node is Node3D:
		return false
	
	var object_pos: Vector3 = (object_node as Node3D).global_position
	var to_object: Vector3 = object_pos - params.char_pos
	to_object.y = 0.0  # Ignore vertical distance for horizontal cone
	
	# Check distance (squared to avoid sqrt)
	var object_dist_sq: float = to_object.length_squared()
	if object_dist_sq > _range_sq:
		return false  # Too far
	
	# Skip if object is at exact same position (prevents division by zero)
	if object_dist_sq < GameConstants.DETECTION_MIN_DISTANCE_SQ:
		return false
	
	# Check if within cone angle
	# Optimized: Use squared dot product comparison to avoid sqrt()
	# For cone check: facing.dot(dir_to_object) >= cos(angle)
	# Which is equivalent to: facing.dot(to_object) >= cos(angle) * ||to_object||
	# Squared version: (facing.dot(to_object))^2 >= cos^2(angle) * object_dist_sq
	var facing_dot_to_object: float = params.facing.dot(to_object)
	# If facing_dot_to_object is negative, object is behind us (definitely outside cone)
	if facing_dot_to_object < 0.0:
		return false
	# Check squared version: (facing.dot(to_object))^2 >= cos^2(angle) * object_dist_sq
	if (facing_dot_to_object * facing_dot_to_object) < (_cos_cone_angle_sq * object_dist_sq):
		return false  # Outside cone angle
	
	# Raycast optimization: May skip raycast for distant objects
	var should_check_los: bool = true
	if enable_raycast_optimization and params.should_use_optimizations:
		should_check_los = _should_check_line_of_sight(
			object_dist_sq, params.close_range_sq, params.mid_range_sq, object_node
		)
	
	# Check line of sight (may be skipped for distant objects)
	if should_check_los:
		if not _has_line_of_sight(
			params.space_state, params.origin, object_pos, params.char_rid, object_node
		):
			return false  # Blocked by obstacle
	
	# Object passed all checks
	return true


func _has_line_of_sight(
	space_state: PhysicsDirectSpaceState3D,
	origin: Vector3,
	target: Vector3,
	exclude_rid: RID,
	target_node: Node
) -> bool:
	# Check for clear line of sight to target
	# Validate inputs (defensive programming)
	if space_state == null:
		return false
	
	if not is_instance_valid(target_node):
		return false
	
	# Create raycast query (must create new each time as properties may not be modifiable)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	# Reuse exclude array to avoid allocation
	_reusable_exclude_array.clear()
	_reusable_exclude_array.append(exclude_rid)
	query.exclude = _reusable_exclude_array
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = collision_mask
	
	var hit: Dictionary = space_state.intersect_ray(query)
	
	# Valid if: no hit (clear) OR hit the target directly
	if hit.is_empty():
		return true
	
	var hit_collider: Node = hit.get("collider") as Node
	if not is_instance_valid(hit_collider):
		return false
	
	return hit_collider == target_node


func _get_group_members(detector_owner: CharacterBody3D) -> Array[Node]:
	# Returns cached group members, refreshing cache periodically
	# Input validation
	if not is_instance_valid(detector_owner):
		_cached_group_members.clear()
		return []
	
	var tree: SceneTree = detector_owner.get_tree()
	if tree == null:
		_cached_group_members.clear()
		return []
	
	# Refresh cache periodically or if cache is empty
	# Use modulo to prevent counter overflow on long-running games
	var refresh_interval: int = GameConstants.DETECTION_CACHE_REFRESH_INTERVAL
	_cache_frame_counter = (_cache_frame_counter + 1) % refresh_interval
	if _cached_group_members.is_empty() or _cache_frame_counter == 0:
		_refresh_group_cache(tree)
	
	# Filter out any invalid nodes from cache (defensive cleanup)
	_cleanup_invalid_nodes()
	
	return _cached_group_members


func _refresh_group_cache(tree: SceneTree) -> void:
	# Refreshes the cached group members array
	if detection_group.is_empty():
		_cached_group_members.clear()
		return
	
	_cached_group_members = tree.get_nodes_in_group(detection_group)
	
	# Invalidate spatial partition when group cache is refreshed
	if enable_spatial_partitioning:
		_partition_dirty = true


func _cleanup_invalid_nodes() -> void:
	# Removes invalid/freed nodes from cached array
	# Only creates new array if cleanup is actually needed (optimization)
	var needs_cleanup: bool = false
	for node in _cached_group_members:
		if not is_instance_valid(node):
			needs_cleanup = true
			break
	
	if needs_cleanup:
		# Reuse array to avoid allocation
		_reusable_objects_array.clear()
		for node in _cached_group_members:
			if is_instance_valid(node):
				_reusable_objects_array.append(node)
		# Swap arrays instead of duplicating (more efficient)
		var temp: Array[Node] = _cached_group_members
		_cached_group_members = _reusable_objects_array
		_reusable_objects_array = temp


## Returns array of currently detected objects
## @return: Array[Node] - Copy of detected objects (safe to modify)
## Example:
##   var detected: Array[Node] = detector.get_detected_objects()
##   for obj in detected:
##       print("Detected: ", obj.name)
func get_detected_objects() -> Array[Node]:
	# Returns a copy to prevent external modification of internal state
	# Use assert for debugging invariants
	assert(_detected_objects != null, "_detected_objects should never be null")
	return _detected_objects.duplicate()


## Convenience method to check if any objects are currently detected
## @return: bool - True if at least one object is detected, false otherwise
## Example:
##   if detector.is_detecting_objects():
##       print("Something detected!")
func is_detecting_objects() -> bool:
	return _detected_objects.size() > 0


# ============================================================================
# SPATIAL PARTITIONING FUNCTIONS
# ============================================================================

func _get_objects_in_nearby_cells(
	_detector_owner: CharacterBody3D, owner_pos: Vector3, group_members: Array[Node]
) -> Array[Node]:
	# Returns objects in nearby spatial cells (dynamic grid based on detection_range)
	# Uses O(1) deduplication with Dictionary for performance
	
	# Defensive check: ensure cell size is valid
	if _spatial_cell_size <= 0.0:
		_handle_runtime_error(
			DetectionError.ErrorCode.SPATIAL_PARTITION_ERROR,
			"Spatial cell size is invalid. Falling back to full group scan.",
			{"cell_size": _spatial_cell_size, "detection_range": detection_range},
			false  # Warning, can recover
		)
		return group_members
	
	# Update spatial partition if needed
	_update_spatial_partition_if_needed(owner_pos, group_members)
	
	# Get cell coordinates and calculate search radius
	# Note: _spatial_cell_size is already validated at the start of this function
	var owner_cell_x: int = int(floor(owner_pos.x / _spatial_cell_size))
	var owner_cell_z: int = int(floor(owner_pos.z / _spatial_cell_size))
	var cell_radius: int = _calculate_cell_radius()
	
	# Reuse dictionary to avoid allocation
	_reusable_objects_dict.clear()
	_collect_objects_from_cells(owner_cell_x, owner_cell_z, cell_radius, _reusable_objects_dict)
	
	# Convert dictionary values to array (reuses array)
	return _convert_dict_to_array(_reusable_objects_dict)


func _update_spatial_partition_if_needed(owner_pos: Vector3, group_members: Array[Node]) -> void:
	# Checks if spatial partition needs rebuilding and rebuilds if necessary
	var current_frame: int = Engine.get_process_frames()
	var cell_size_sq: float = _spatial_cell_size * _spatial_cell_size
	var should_rebuild: bool = _partition_dirty
	
	# Check if detector owner moved significantly
	var moved_significantly: bool = (
		owner_pos.distance_squared_to(_last_partition_pos) > cell_size_sq
	)
	if moved_significantly:
		# Only rebuild if cooldown has passed
		var frames_since_rebuild: int = current_frame - _last_rebuild_frame
		var rebuild_cooldown: int = GameConstants.DETECTION_SPATIAL_REBUILD_COOLDOWN
		if frames_since_rebuild >= rebuild_cooldown:
			should_rebuild = true
	
	if should_rebuild:
		_rebuild_spatial_partition(group_members)
		_last_partition_pos = owner_pos
		_partition_dirty = false
		_last_rebuild_frame = current_frame


func _calculate_cell_radius() -> int:
	# Calculates how many cells to check in each direction, capped at maximum
	# Defensive check: prevent division by zero
	if _spatial_cell_size <= 0.0:
		return GameConstants.DETECTION_SPATIAL_MAX_CELL_RADIUS  # Return max as fallback
	
	var cells_to_check: float = ceil(detection_range / _spatial_cell_size)
	var calculated_radius: int = int((cells_to_check + 1.0) / 2.0)  # Round up
	var max_radius: int = GameConstants.DETECTION_SPATIAL_MAX_CELL_RADIUS
	return min(calculated_radius, max_radius)


func _collect_objects_from_cells(
	owner_cell_x: int, owner_cell_z: int, cell_radius: int, objects_dict: Dictionary
) -> void:
	# Collects objects from cells in the search radius around detector owner's cell
	for dx: int in range(-cell_radius, cell_radius + 1):
		for dz: int in range(-cell_radius, cell_radius + 1):
			var cell_key: int = _get_cell_key(owner_cell_x + dx, owner_cell_z + dz)
			if cell_key in _spatial_cells:
				var cell_objects: Array[Node] = _spatial_cells[cell_key] as Array[Node]
				for obj in cell_objects:
					if not is_instance_valid(obj):
						continue
					
					var obj_id: int = obj.get_instance_id()
					if not obj_id in objects_dict:
						objects_dict[obj_id] = obj


func _convert_dict_to_array(objects_dict: Dictionary) -> Array[Node]:
	# Converts dictionary values to typed array
	# Reuses array to avoid allocation
	_reusable_objects_array.clear()
	for obj in objects_dict.values():
		if is_instance_valid(obj) and obj is Node:
			_reusable_objects_array.append(obj as Node)
	# Return a copy to avoid external modification of internal state
	return _reusable_objects_array.duplicate()


func _rebuild_spatial_partition(group_members: Array[Node]) -> void:
	# Rebuilds the spatial partition grid
	# Defensive check: ensure cell size is valid
	if _spatial_cell_size <= 0.0:
		_handle_runtime_error(
			DetectionError.ErrorCode.SPATIAL_PARTITION_ERROR,
			"Cannot rebuild partition with invalid cell size.",
			{"cell_size": _spatial_cell_size, "detection_range": detection_range}
		)
		return
	
	_spatial_cells.clear()
	
	for obj in group_members:
		if not is_instance_valid(obj) or not obj is Node3D:
			continue
		
		var obj_pos: Vector3 = (obj as Node3D).global_position
		# Note: _spatial_cell_size is already validated at the start of this function
		var cell_x: int = int(floor(obj_pos.x / _spatial_cell_size))
		var cell_z: int = int(floor(obj_pos.z / _spatial_cell_size))
		var cell_key: int = _get_cell_key(cell_x, cell_z)
		
		if not cell_key in _spatial_cells:
			_spatial_cells[cell_key] = [] as Array[Node]
		
		var cell_array: Array[Node] = _spatial_cells[cell_key] as Array[Node]
		cell_array.append(obj)


func _get_cell_key(cell_x: int, cell_z: int) -> int:
	# Creates an integer key from cell coordinates
	# Uses a simple hash: x * large_prime + z
	# This is faster than string concatenation
	# Note: Using modulo can cause hash collisions for cells far apart,
	# but this is acceptable for spatial partitioning as long as collisions are rare
	# and the hash prime is large enough to distribute keys well
	var max_coord: int = GameConstants.DETECTION_SPATIAL_MAX_CELL_COORD
	# Use signed modulo to handle negative coordinates correctly
	var safe_x: int = ((cell_x % max_coord) + max_coord) % max_coord
	var safe_z: int = ((cell_z % max_coord) + max_coord) % max_coord
	return safe_x * GameConstants.DETECTION_SPATIAL_HASH_PRIME + safe_z


# ============================================================================
# RAYCAST OPTIMIZATION FUNCTIONS
# ============================================================================

func _should_check_line_of_sight(
	dist_sq: float, close_range_sq: float, mid_range_sq: float, object_node: Node
) -> bool:
	# Determines if we should check line of sight based on distance (raycast optimization)
	# Uses deterministic frame-based approach to avoid flickering
	# Close objects: Always check
	# Mid-range objects: Check every N frames with object-specific offset (staggered)
	if dist_sq <= close_range_sq:
		return true  # Always check close objects
	
	if dist_sq <= mid_range_sq:
		# Mid-range: Check every N frames with object-specific offset
		# This staggers checks across objects to avoid frame spikes
		var current_frame: int = Engine.get_process_frames()
		var check_interval: int = (
			GameConstants.DETECTION_RAYCAST_OPTIMIZATION_MID_RANGE_CHECK_INTERVAL
		)
		var obj_offset: int = object_node.get_instance_id() % check_interval
		return ((current_frame + obj_offset) % check_interval) == 0
	
	# Objects beyond mid-range are already filtered by distance check in _is_object_in_cone()
	# This code path should not be reached, but if it is, we should not check line of sight
	# (objects beyond mid-range don't need frequent LOS checks due to raycast optimization)
	return false


# ============================================================================
# SPATIAL PARTITION MANAGEMENT
# ============================================================================

## Invalidates the spatial partition, forcing a rebuild on next check
## Call this when objects are added/removed/moved to ensure accurate detection
## Useful when objects spawn/despawn dynamically or move between cells
## Note: Partition will also rebuild automatically when character moves or cache refreshes
## Example:
##   detector.invalidate_spatial_partition()  # After spawning enemies
func invalidate_spatial_partition() -> void:
	_partition_dirty = true
	_spatial_cells.clear()


## Sets the detection range and updates cached values
## Use this instead of directly modifying detection_range to ensure cached values stay in sync
## @param new_range: New detection range in units (must be > 0)
func set_detection_range(new_range: float) -> void:
	if new_range <= 0.0:
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_DETECTION_RANGE,
			"detection_range must be > 0. Ignoring change.",
			{"provided": new_range, "current": detection_range},
			false  # Warning, not critical
		)
		return
	detection_range = new_range
	_update_cached_values()
	# Invalidate partition since cell size changed
	invalidate_spatial_partition()


## Sets the detection height offset
## @param new_height: New height offset (must be >= 0)
func set_detection_height(new_height: float) -> void:
	if new_height < 0.0:
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_DETECTION_HEIGHT,
			"detection_height must be >= 0. Ignoring change.",
			{"provided": new_height, "current": detection_height},
			false  # Warning, not critical
		)
		return
	detection_height = new_height
	# Update cached height offset
	_cached_height_offset = Vector3.UP * detection_height


## Sets the cone angle in radians
## @param new_angle_rad: New cone angle in radians (must be > 0 and <= PI)
func set_cone_angle(new_angle_rad: float) -> void:
	if new_angle_rad <= 0.0 or new_angle_rad > PI:
		_handle_runtime_error(
			DetectionError.ErrorCode.INVALID_CONE_ANGLE,
			"cone_angle_rad must be > 0 and <= PI. Ignoring change.",
			{"provided": new_angle_rad, "current": cone_angle_rad, "max": PI},
			false  # Warning, not critical
		)
		return
	cone_angle_rad = new_angle_rad
	_update_cached_values()


## Resets all caches and invalidates spatial partition
## Useful when scene changes or objects are added/removed in bulk
## Example:
##   detector.reset()  # After major scene changes
func reset() -> void:
	_cached_group_members.clear()
	_spatial_cells.clear()
	_detected_objects.clear()
	_reusable_objects_dict.clear()
	_reusable_objects_array.clear()
	_reusable_exclude_array.clear()
	_partition_dirty = true
	_cache_frame_counter = 0
	_last_rebuild_frame = -1
	_last_partition_pos = Vector3.ZERO


## Validates that the current configuration is valid
## @return: bool - True if configuration is valid, false otherwise
func is_configuration_valid() -> bool:
	var range_valid: bool = detection_range > 0.0
	var cell_size_valid: bool = _spatial_cell_size > 0.0
	var angle_valid: bool = cone_angle_rad > 0.0 and cone_angle_rad <= PI
	return range_valid and cell_size_valid and angle_valid


# ============================================================================
# ERROR HANDLING FUNCTIONS
# ============================================================================

func _handle_validation_error(
	error_code: DetectionError.ErrorCode, message: String, context: Dictionary
) -> void:
	# Helper function to create and handle validation errors during initialization
	# Reduces code duplication in _init()
	var error: DetectionError = DetectionError.new(error_code, message, context)
	_handle_error(error)


func _handle_runtime_error(
	error_code: DetectionError.ErrorCode,
	message: String,
	context: Dictionary,
	is_critical: bool = true
) -> void:
	# Helper function to create and handle runtime errors
	# Reduces code duplication in check_facing_object() and other runtime functions
	var error: DetectionError = DetectionError.new(error_code, message, context)
	_handle_error(error, is_critical)


func _handle_error(error: DetectionError, is_critical: bool = true) -> void:
	# Handles errors according to Godot best practices
	# Uses push_error() for critical errors, push_warning() for warnings
	assert(error != null, "Error object cannot be null")
	
	_last_error = error
	
	# Determine if this should be treated as critical
	var should_treat_as_critical: bool = is_critical and error.is_critical()
	
	if should_treat_as_critical:
		push_error(error.get_formatted_message())
		error_occurred.emit(error)
	else:
		push_warning(error.get_formatted_message())


## Returns the last error that occurred, or null if no errors
## @return: DetectionError or null
## Example:
##   var last_error = detector.get_last_error()
##   if last_error != null:
##       print("Last error: ", last_error.get_formatted_message())
func get_last_error() -> DetectionError:
	return _last_error


## Clears the last error
## Useful for resetting error state after handling
func clear_error() -> void:
	_last_error = null
