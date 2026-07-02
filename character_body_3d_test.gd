extends CharacterBody3D

const WALK_SPEED        = 5.0
const SPRINT_SPEED      = 8.0
const JUMP_VELOCITY     = 4.5
const GRAVITY           = 9.8
const MOUSE_SENSITIVITY = 0.003
const BOB_FREQ          = 2.0
const BOB_AMOUNT        = 0.05
const FOOTSTEP_INTERVAL = 0.5
const MIRROR_COOLDOWN   = 5.0

var bob_time        = 0.0
var has_flashlight  = false
var flashlight_on   = false
var footstep_timer  = 0.0
var has_mirror      = false
var mirror_raised   = false
var mirror_cooldown = 0.0

@onready var head            = $Head
@onready var camera          = $Head/Camera3D
@onready var flashlight      = $Head/Camera3D/SpotLight3D
@onready var hand_flashlight = $Head/Camera3D/HandsRig/HandFlashlight
@onready var mirror_mesh     = $Head/Camera3D/HandsRig/MirrorMesh
@onready var footstep_player = $FootstepPlayer
@onready var flashlight_ray  = $Head/Camera3D/FlashlightRay

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("toggle_flashlight") and has_flashlight:
		flashlight_on = !flashlight_on
		flashlight.visible = flashlight_on

	# Raise mirror
	if event.is_action_pressed("use_mirror") and has_mirror and mirror_cooldown <= 0.0:
		mirror_raised = true
		mirror_mesh.visible = true

	# Lower mirror
	if event.is_action_released("use_mirror"):
		mirror_raised = false
		mirror_mesh.visible = false

func _physics_process(delta):
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_head_bob(delta)
	_handle_footsteps(delta)
	_check_pickup()
	_check_flashlight_ray()
	_handle_mirror_cooldown(delta)
	move_and_slide()

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_jump():
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _handle_movement(_delta):
	var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func _head_bob(delta):
	var is_moving = velocity.length() > 0.5 and is_on_floor()
	if is_moving:
		bob_time += delta * BOB_FREQ
		camera.transform.origin.y = sin(bob_time) * BOB_AMOUNT
	else:
		camera.transform.origin.y = lerp(camera.transform.origin.y, 0.0, delta * 10)

func _handle_footsteps(delta):
	var is_moving = velocity.length() > 0.5 and is_on_floor()
	if is_moving:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_player.play()
			var interval = FOOTSTEP_INTERVAL / 1.6 if Input.is_action_pressed("sprint") else FOOTSTEP_INTERVAL
			footstep_timer = interval
	else:
		footstep_timer = 0.0

func _handle_mirror_cooldown(delta):
	if mirror_cooldown > 0.0:
		mirror_cooldown -= delta

func _check_pickup():
	if not has_flashlight:
		var flashlight_node = get_tree().get_first_node_in_group("flashlight")
		if flashlight_node:
			var dist = global_position.distance_to(flashlight_node.global_position)
			if Input.is_action_just_pressed("interact") and dist < 2.0:
				_pickup_flashlight(flashlight_node)

	if not has_mirror:
		var mirror_node = get_tree().get_first_node_in_group("mirror")
		if mirror_node:
			var dist = global_position.distance_to(mirror_node.global_position)
			if Input.is_action_just_pressed("interact") and dist < 2.0:
				_pickup_mirror(mirror_node)

func _pickup_flashlight(node):
	has_flashlight = true
	flashlight_on  = true
	flashlight.visible = true
	hand_flashlight.visible = true
	node.queue_free()
	print("Flashlight picked up!")

func _pickup_mirror(node):
	has_mirror = true
	node.queue_free()
	print("Mirror picked up!")

func _check_flashlight_ray():
	var watcher = get_tree().get_first_node_in_group("watcher")

	if not flashlight_on:
		if watcher:
			watcher.stop_watching()
		return

	if flashlight_ray.is_colliding():
		var hit = flashlight_ray.get_collider()
		if hit:
			if hit.is_in_group("mourning_daughter"):
				hit.trigger_chase()
			if hit.is_in_group("watcher"):
				# Mirror raised = reflect gaze = stun it!
				if mirror_raised and mirror_cooldown <= 0.0:
					hit.reflect_stun()
					mirror_cooldown = MIRROR_COOLDOWN
					print("Mirror reflected! Watcher stunned!")
				else:
					hit.being_watched()
	else:
		if watcher:
			watcher.stop_watching()
