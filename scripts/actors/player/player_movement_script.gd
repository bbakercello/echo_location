extends CharacterBody3D

# Movement constants
const ACCEL := 10.0
const DECEL := 18.0
const MAX_SPEED := 20.0
const JUMP_VELOCITY := 7.5

var facing_dir: Vector3 = Vector3.FORWARD

# Input state for detection queries
var _was_clicking: bool = false

# Components
var enemy_detector: EnemyDetector


func _ready() -> void:
	enemy_detector = EnemyDetector.new()
	enemy_detector.target_changed.connect(_on_target_changed)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_detection()


func _handle_movement(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	var is_moving: bool = move_dir.length_squared() > 0.0

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


func _handle_detection() -> void:
	# Update detection every frame
	enemy_detector.check_facing_object(self, facing_dir)
	
	# Handle click-to-detect interaction
	var is_clicking: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if is_clicking and not _was_clicking:
		_on_detection_query()
	_was_clicking = is_clicking


func _on_detection_query() -> void:
	# Called on left-click - query the current best target
	var best_enemy: Node = enemy_detector.get_best_enemy()
	if best_enemy != null:
		_log_enemy_detection(best_enemy)
	else:
		print("NO ENEMY DETECTED")


func _log_enemy_detection(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node):
		return
	
	var message: String = "ENEMY DETECTED: " + enemy_node.name
	
	if "current_health" in enemy_node:
		var health: int = enemy_node.get("current_health")
		message += ", health: " + str(health)
	
	if enemy_node is BaseEnemy:
		var frequency: float = (enemy_node as BaseEnemy).frequency_hz
		message += ", frequency: " + "%.0f" % frequency + " Hz"
	
	if enemy_node == enemy_detector.get_current_enemy():
		message += " [LOCKED]"
	
	print(message)


func _on_target_changed(new_target: Node, _old_target: Node) -> void:
	if new_target != null:
		print("New target locked: ", new_target.name)
	else:
		print("Target lost")
