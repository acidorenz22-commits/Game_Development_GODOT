extends CharacterBody3D

const SPEED     = 1.5
const GRAVITY   = 9.8
const STOP_DIST = 1.2

var player = null

@onready var nav_agent = $NavigationAgent3D
@onready var audio     = $AudioStreamPlayer3D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	print("Player found: ", player)

	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5
	timer.timeout.connect(_update_target)
	timer.start()

func _update_target():
	if player:
		nav_agent.target_position = player.global_position

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if player == null:
		return

	var dist = global_position.distance_to(player.global_position)

	if dist > STOP_DIST:
		var next_pos  = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity.x    = direction.x * SPEED
		velocity.z    = direction.z * SPEED
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
