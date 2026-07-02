extends CharacterBody3D

const GRAVITY      = 9.8
const CHASE_SPEED  = 6.0
const STARE_LIMIT  = 3.0
const STOP_DIST    = 1.2

enum State { IDLE, WATCHED, CHASING }

var player      = null
var state       = State.IDLE
var stare_timer = 0.0

@onready var nav_agent = $NavigationAgent3D
@onready var audio     = $AudioStreamPlayer3D

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	print("Watcher found player: ", player)
	audio.volume_db = -40.0

	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5
	timer.timeout.connect(_update_target)
	timer.start()

func being_watched():
	if state == State.CHASING:
		return
	state = State.WATCHED
	if player:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

func stop_watching():
	if state == State.WATCHED:
		state = State.IDLE
		stare_timer = 0.0
		audio.volume_db = -40.0

func _update_target():
	if player and state == State.CHASING:
		nav_agent.target_position = player.global_position

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if player == null:
		return

	match state:
		State.IDLE:
			velocity.x = 0
			velocity.z = 0

		State.WATCHED:
			velocity.x = 0
			velocity.z = 0
			stare_timer += delta
			audio.volume_db = lerp(-40.0, -10.0, stare_timer / STARE_LIMIT)
			if stare_timer >= STARE_LIMIT:
				_trigger_charge()

		State.CHASING:
			var dist = global_position.distance_to(player.global_position)
			var vol_percent = 1.0 - clamp(dist / 15.0, 0.0, 1.0)
			audio.volume_db = lerp(-40.0, 0.0, vol_percent)

			if dist > STOP_DIST:
				var next_pos  = nav_agent.get_next_path_position()
				var direction = (next_pos - global_position).normalized()
				velocity.x    = direction.x * CHASE_SPEED
				velocity.z    = direction.z * CHASE_SPEED
				look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
			else:
				velocity.x = 0
				velocity.z = 0
				_catch_player()

	move_and_slide()

func _trigger_charge():
	state = State.CHASING
	stare_timer = 0.0
	print("WATCHER IS CHARGING!")

func _catch_player():
	print("Watcher caught the player!")
	var game_over = load("res://game_over.tscn").instantiate()
	get_tree().root.add_child(game_over)
	# Freeze the game briefly
	get_tree().paused = true
	game_over.process_mode = Node.PROCESS_MODE_ALWAYS 

func reflect_stun():
	print("Watcher stunned by mirror!")
	state = State.IDLE
	stare_timer = 0.0	
	velocity = Vector3.ZERO
	audio.volume_db = -40.0
	# Stun for 5 seconds then back to normal
	await get_tree().create_timer(5.0).timeout
	print("Watcher recovered!")
