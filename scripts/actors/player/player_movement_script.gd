extends CharacterBody3D

const ACCEL := 10.0
const DECEL := 18.0
const MAX_SPEED := 20.0
const JUMP_VELOCITY := 7.5

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Input vector
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Horizontal velocity (XZ only)
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)

	if direction.length() > 0:
		# Accelerate toward desired speed
		var target_speed := direction * MAX_SPEED
		horizontal_velocity = horizontal_velocity.lerp(target_speed, ACCEL * delta)
	else:
		# Decelerate to a stop
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, DECEL * delta)

	# Write back XZ velocity
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
