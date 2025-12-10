extends Node3D

const RAY_LENGTH = 1000

signal raycast_hit(result: Dictionary)

@export var camera_path: NodePath = NodePath("")
var cam: Camera3D = null
var last_raycast_result: Dictionary = {}
var _ray_line: MeshInstance3D
var _ray_marker: MeshInstance3D

func _ready():
	# Resolve camera once at startup. Priority:
	# 1) explicit `camera_path` set in Inspector
	# 2) find a descendant named "Camera3D"
	# 3) fallback to viewport's active camera
	if camera_path != NodePath(""):
		cam = get_node_or_null(camera_path) as Camera3D
	if cam == null:
		cam = find_child("Camera3D", true, false) as Camera3D
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		push_warning("ray_cast_3d: no Camera3D found; raycasts will be skipped")

	# Prepare visualization nodes (Line + Marker). Create them if missing.
	if has_node("RayLine"):
		_ray_line = $RayLine
	else:
		_ray_line = MeshInstance3D.new()
		_ray_line.name = "RayLine"
		_ray_line.mesh = ArrayMesh.new()
		_ray_line.visible = false
		add_child(_ray_line)

	if has_node("RayMarker"):
		_ray_marker = $RayMarker
	else:
		_ray_marker = MeshInstance3D.new()
		_ray_marker.name = "RayMarker"
		var sph = SphereMesh.new()
		sph.radius = 0.08
		_ray_marker.mesh = sph
		_ray_marker.visible = false
		add_child(_ray_marker)

func _physics_process(_delta):
	# Only run the raycast while the left mouse action is pressed
	if not Input.is_action_pressed("LeftClick"):
		# Hide visuals when released
		if _ray_line != null:
			_ray_line.visible = false
		if _ray_marker != null:
			_ray_marker.visible = false
		return

	var space_state = get_world_3d().direct_space_state
	if cam == null:
		return

	var mousepos = get_viewport().get_mouse_position()

	# Ray originates from this node (CharacterBody3D) position
	var origin = global_transform.origin
	
	# Ray aims towards mouse position via camera projection
	var cam_ray_origin = cam.project_ray_origin(mousepos)
	var cam_ray_dir = cam.project_ray_normal(mousepos)
	var far_point = cam_ray_origin + cam_ray_dir * 10000.0
	
	# Compute direction from player to the far point on the camera ray
	var direction = (far_point - origin).normalized()
	var end = origin + direction * RAY_LENGTH
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true

	# Exclude self so the player isn't hit by its own ray
	query.exclude = [self]

	var result = space_state.intersect_ray(query)

	# Update visualization using an ArrayMesh (primitive lines)
	var start_point = origin
	var end_point = end
	var hit_pos = null
	if result and result.has("position"):
		hit_pos = result["position"]
		end_point = hit_pos

	# Build mesh arrays for a simple line (two vertices)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([start_point, end_point])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color(1, 0.2, 0.2, 1.0), Color(1, 0.2, 0.2, 1.0)])

	var line_mesh = ArrayMesh.new()
	line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_ray_line.mesh = line_mesh
	_ray_line.visible = true

	if hit_pos != null:
		var new_xform = _ray_marker.global_transform
		new_xform.origin = hit_pos
		_ray_marker.global_transform = new_xform
		_ray_marker.visible = true
		print("Raycast hit at position: ", hit_pos)
		last_raycast_result = result
		raycast_hit.emit(result)
	else:
		_ray_marker.visible = false
