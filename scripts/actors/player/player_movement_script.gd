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
	# Initialize facing direction from camera if available
	# Vector3.FORWARD is (0, 0, -1)
	if facing_dir == Vector3.FORWARD:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			facing_dir = -camera.global_transform.basis.z
			facing_dir.y = 0.0
			facing_dir = facing_dir.normalized()
	
	# Initialize components
	enemy_detector = EnemyDetector.new()
	
	# Connect signals for enemy detection events
	enemy_detector.enemy_detected.connect(_on_enemy_detected)
	enemy_detector.enemy_lost.connect(_on_enemy_lost)

func _physics_process(delta: float) -> void:
	# Player movement script.
	# Handles player movement, facing, and enemy detection.
	# Args: delta: float - The time since the last physics update.
	
	# Gravity only apply if not on floor
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Input vector from keyboard
	# Example: W: (0, -1, 0)
	# Example: A: (-1, 0, 0)
	# Example: S: (0, 1, 0)
	# Example: D: (1, 0, 0)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	# Update facing based on last movement direction
	if move_dir.length() > 0.0:
		# Update facing direction based on last movement direction 
		# This is used for enemy detection and to determine if the player is facing an enemy
		facing_dir = move_dir.normalized()

	# Horizontal velocity (XZ only)
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if move_dir.length() > 0.0:
		var target_velocity := move_dir * MAX_SPEED
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, ACCEL * delta)
	else:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, DECEL * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
	
	# Check if facing an enemy
	enemy_detector.check_facing_enemy(self, facing_dir)


func _on_enemy_detected(_enemy: Node = null, _distance: float = 0.0) -> void:
	# Called when enemy is detected - can be used for UI updates, audio, etc.
	pass


func _on_enemy_lost() -> void:
	# Called when enemy is no longer detected
	pass
