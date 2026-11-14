extends Area2D
class_name RoomExit

signal entered(exit_door: RoomExit)

@export_enum("right", "left", "up", "down") var direction: String = "right"
@export var exit_width: float = 64.0

var locked: bool = true
var _player_nearby: bool = false
var _used: bool = false


# creates a doorway trigger that stays sealed until the room is cleared
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50.0, exit_width) if direction in ["left", "right"] else Vector2(exit_width, 50.0)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


# checks for player interaction while standing beside an unlocked exit
func _unhandled_input(event: InputEvent) -> void:
	if not locked and not _used and _player_nearby and event.is_action_pressed("interact"):
		_used = true
		entered.emit(self)
		get_viewport().set_input_as_handled()


# draws a visible locked or open door in the placeholder layout
func _draw() -> void:
	var color := Color(0.92, 0.26, 0.31) if locked else Color(0.32, 0.94, 0.56)
	var size := Vector2(16.0, exit_width) if direction in ["left", "right"] else Vector2(exit_width, 16.0)
	draw_rect(Rect2(-size / 2.0, size), color)
	draw_rect(Rect2(-size / 2.0, size), Color(0.9, 0.95, 1.0), false, 2.0)


# changes whether the player may proceed through this doorway
func set_locked(value: bool) -> void:
	locked = value
	_used = false
	queue_redraw()


# tracks when the player is close enough to use the exit
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true


# stops accepting input after the player leaves the doorway
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
