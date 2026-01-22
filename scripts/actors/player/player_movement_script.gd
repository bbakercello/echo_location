extends CharacterBody3D

# Movement constants
const ACCEL := 10.0
const DECEL := 18.0
const MAX_SPEED := 20.0
const JUMP_VELOCITY := 7.5

var facing_dir: Vector3 = Vector3.FORWARD

# Components
var enemy_detector: EnemyDetector

func _ready() -> void:
	enemy_detector = EnemyDetector.new()

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	var is_moving: bool = move_dir.length() > 0.0

	# Update facing direction from movement
	if is_moving:
		facing_dir = move_dir

	# Horizontal velocity (XZ only)
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if is_moving:
		var target_velocity := move_dir * MAX_SPEED
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, ACCEL * delta)
	else:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, DECEL * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
	
	# Enemy detection - runs every frame to keep cache updated
	enemy_detector.check_facing_enemy(self, facing_dir)
	
	# Example: Query detected enemies for audio system, UI, etc.
	# var detected_enemies: Array[Node] = enemy_detector.get_detected_enemies()
	# if detected_enemies.size() > 0:
	#     # Play audio, update UI, etc.
