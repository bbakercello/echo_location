# Data structure for target scoring in the detection system
# Stores priority score information for a detected target
#
# NOTE: This class is for EXTERNAL USE when detailed score breakdown is needed.
# The internal detection system uses inline scoring in TargetPrioritizer for performance.
# If you modify the scoring algorithm, update both:
#   - TargetPrioritizer._calculate_score_for_node()
#   - TargetScore.create_from_target()
class_name TargetScore
extends RefCounted

var node: Node  # The target node
var score: float  # Combined priority score (higher = better target)
var distance_sq: float  # Squared distance to target
var angle_score: float  # Angle alignment score (0-1, higher = more centered)


func _init(
	p_node: Node,
	p_score: float,
	p_dist_sq: float,
	p_angle: float
) -> void:
	node = p_node
	score = p_score
	distance_sq = p_dist_sq
	angle_score = p_angle


## Creates a TargetScore by calculating priority from target position and detector context
## @param target: The target node to score
## @param detector_pos: Position of the detector owner
## @param facing_dir: Normalized facing direction of the detector
## @param detection_range: Maximum detection range
## @param cos_cone_angle: Cosine of the cone angle (for angle score calculation)
## @param is_current_target: Whether this target is the currently locked target
## @param is_lock_active: Whether target persistence lock is active
## @return: TargetScore or null if target is invalid
static func create_from_target(
	target: Node,
	detector_pos: Vector3,
	facing_dir: Vector3,
	detection_range: float,
	cos_cone_angle: float,
	is_current_target: bool,
	is_lock_active: bool
) -> TargetScore:
	if not is_instance_valid(target) or not target is Node3D:
		return null
	
	var target_pos: Vector3 = (target as Node3D).global_position
	var to_target: Vector3 = target_pos - detector_pos
	to_target.y = 0.0  # Ignore vertical for scoring (2D cone)
	
	var dist_sq: float = to_target.length_squared()
	
	# Very close targets: return max score (avoid division issues)
	if dist_sq < GameConstants.DETECTION_MIN_DISTANCE_SQ:
		return TargetScore.new(target, 1.0, dist_sq, 1.0)  # Max score
	
	# Distance score: 1.0 at distance 0, 0.0 at max range (closer = better)
	var dist: float = sqrt(dist_sq)
	var normalized_dist: float = dist / detection_range
	var distance_score: float = 1.0 - clamp(normalized_dist, 0.0, 1.0)
	
	# Angle score: 1.0 when directly in front, 0.0 at cone edge
	# Use actual normalization to ensure unit vector for correct dot product
	var to_target_normalized: Vector3 = to_target / dist
	var dot: float = facing_dir.dot(to_target_normalized)
	
	# Remap from [cos(cone_angle), 1.0] to [0.0, 1.0]
	# Protect against division by zero when cone_angle is 0 (cos = 1.0)
	var angle_score_val: float = 0.0
	var denominator: float = 1.0 - cos_cone_angle
	if denominator > GameConstants.ANGLE_DENOMINATOR_EPSILON:
		angle_score_val = clamp((dot - cos_cone_angle) / denominator, 0.0, 1.0)
	else:
		# Cone angle is ~0, only direct hits count
		angle_score_val = 1.0 if dot >= GameConstants.ANGLE_DIRECT_HIT_THRESHOLD else 0.0
	
	# Weighted combination
	var dist_weight: float = GameConstants.TARGET_PRIORITY_DISTANCE_WEIGHT
	var angle_weight: float = GameConstants.TARGET_PRIORITY_ANGLE_WEIGHT
	var base_score: float = (distance_score * dist_weight) + (angle_score_val * angle_weight)
	
	# Persistence bonus for current target (prevents flickering)
	var final_score: float = base_score
	if is_current_target and is_lock_active:
		final_score += GameConstants.TARGET_PERSISTENCE_BONUS
	
	return TargetScore.new(target, final_score, dist_sq, angle_score_val)


## Comparison function for sorting (higher score = better, comes first)
## Use with Array.sort_custom(): targets.sort_custom(TargetScore.compare)
static func compare(a: TargetScore, b: TargetScore) -> bool:
	return a.score > b.score
