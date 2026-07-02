extends CanvasLayer

func _ready():
	await get_tree().create_timer(3.0).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()
