extends Node2D

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D


# updated so that the camera doesn't desync with player on start
# initializes the camera at the player's position
func _ready() -> void:
	camera.global_position = player.global_position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.make_current()
	camera.reset_smoothing()
	queue_redraw()



# keeps the camera centered on the player while fighting
func _process(_delta: float) -> void:
	camera.global_position = player.global_position


# draws a temporary arena underneath the existing level layers
func _draw() -> void:
	draw_rect(Rect2(-650, -365, 1300, 730), Color(0.10, 0.15, 0.18))
	for x in range(-600, 601, 60):
		draw_line(Vector2(x, -345), Vector2(x, 345), Color(0.17, 0.22, 0.26), 1.0)
	for y in range(-300, 301, 60):
		draw_line(Vector2(-630, y), Vector2(630, y), Color(0.17, 0.22, 0.26), 1.0)
	draw_rect(Rect2(-630, -345, 1260, 690), Color(0.31, 0.62, 0.65), false, 5.0)
