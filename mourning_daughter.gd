extends CharacterBody3D

const SPEED_IDLE  = 0.0
const SPEED_CHASE = 1.5
const GRAVITY     = 9.8
const STOP_DIST   = 1.2
const CHASE_MEMORY = 3.0

var player        = null
var is_chasing    = false
var chase_timer   = 0.0
var current_speed = 0.0

@onready var nav_agent = $NavigationAgent3D
@onready var audio     = $AudioStreamPlayer3D

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	print("Player found: ", player)
	audio.volume_db = -40.0

	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5
	timer.timeout.connect(_update_target)
	timer.start()

func trigger_chase():
	is_chasing  = true
	chase_timer = CHASE_MEMORY

func _update_target():
	if player and is_chasing:
		nav_agent.target_position = player.global_position

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if player == null:
		return

	if is_chasing:
		chase_timer -= delta
		if chase_timer <= 0.0:
			is_chasing = false

	var target_speed  = SPEED_CHASE if is_chasing else SPEED_IDLE
	current_speed     = lerp(current_speed, target_speed, delta * 3.0)

	var dist = global_position.distance_to(player.global_position)
	var vol_percent = 1.0 - clamp(dist / 15.0, 0.0, 1.0)
	audio.volume_db = lerp(-40.0, 0.0, vol_percent)

	if is_chasing and dist > STOP_DIST:
		var next_pos  = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity.x    = direction.x * current_speed
		velocity.z    = direction.z * current_speed
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	elif is_chasing and dist <= STOP_DIST:
		velocity.x = 0
		velocity.z = 0
		_catch_player()
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

func _catch_player():
	print("MD caught the player!")
	var game_over = load("res://game_over.tscn").instantiate()
	get_tree().root.add_child(game_over)
	get_tree().paused = true
	game_over.process_mode = Node.PROCESS_MODE_ALWAYS
