extends Node2D

signal exit_requested(exit_door: RoomExit)

@export var room_bounds: Rect2 = Rect2(-610.0, -325.0, 1220.0, 650.0)
@export var player_spawn: Vector2 = Vector2.ZERO
@export var enemy_spawn_points: Array[NodePath] = []
@export var exit_paths: Array[NodePath] = []
@export var show_placeholder_arena: bool = true

@onready var player: PlayerController = get_node_or_null("Player") as PlayerController
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D

var _exits: Array[RoomExit] = []


# initializes room exits and the camera used by the persistent player
func _ready() -> void:
	_setup_exits()
	if camera != null and player != null:
		set_active_player(player)
	queue_redraw()


# keeps the camera centered on the player while fighting
func _process(_delta: float) -> void:
	if camera != null and player != null:
		camera.global_position = player.global_position


# attaches the transferred player to the current room camera
func set_active_player(target: PlayerController) -> void:
	player = target
	if camera != null:
		camera.global_position = player.global_position
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 4.0
		camera.make_current()
		camera.reset_smoothing()


# returns a local position where the player should enter the room
func get_player_spawn_position() -> Vector2:
	return player_spawn


# returns the playable bounds set by the level designer
func get_room_bounds() -> Rect2:
	return room_bounds


# returns a doorway-side entry position rather than the room center
func get_entry_position(from_direction: String) -> Vector2:
	var middle := room_bounds.get_center()
	match from_direction:
		"left":
			return Vector2(room_bounds.end.x - 46.0, middle.y)
		"up":
			return Vector2(middle.x, room_bounds.end.y - 46.0)
		"down":
			return Vector2(middle.x, room_bounds.position.y + 46.0)
	return Vector2(room_bounds.position.x + 46.0, middle.y)


# chooses a spawn point from the room layout or its fallback bounds
func get_enemy_spawn_position(player_position: Vector2) -> Vector2:
	var choices: Array[Vector2] = []
	for path in enemy_spawn_points:
		var marker := get_node_or_null(path) as Node2D
		if marker != null and marker.global_position.distance_to(player_position) >= 150.0:
			choices.append(marker.global_position)
	if not choices.is_empty():
		return choices.pick_random()

	var local_player := to_local(player_position)
	var margin := Vector2(18.0, 18.0)
	var lower := room_bounds.position + margin
	var upper := room_bounds.end - margin
	for _attempt in range(12):
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(250.0, 410.0)
		var point := (local_player + Vector2.RIGHT.rotated(angle) * distance).clamp(lower, upper)
		if point.distance_to(local_player) >= 150.0:
			return to_global(point)
	return to_global(Vector2(lower.x, lower.y))


# connects level designer doors or creates one temporary right-side exit
func _setup_exits() -> void:
	for path in exit_paths:
		var door := get_node_or_null(path) as RoomExit
		if door != null:
			_register_exit(door)
	if _exits.is_empty():
		var door := RoomExit.new()
		door.name = "DefaultExit"
		door.position = Vector2(room_bounds.end.x - 25.0, room_bounds.get_center().y)
		add_child(door)
		_register_exit(door)


# connects a doorway's interaction signal to the room controller
func _register_exit(door: RoomExit) -> void:
	if _exits.has(door):
		return
	_exits.append(door)
	door.entered.connect(_on_exit_entered)


# opens or closes every configured exit in the current room
func set_exits_locked(value: bool) -> void:
	for door in _exits:
		door.set_locked(value)


# forwards the selected doorway to the run controller
func _on_exit_entered(door: RoomExit) -> void:
	exit_requested.emit(door)


# draws a temporary arena underneath the existing level layers
func _draw() -> void:
	if not show_placeholder_arena:
		return
	var area := room_bounds.grow(20.0)
	draw_rect(area, Color(0.10, 0.15, 0.18))
	var x := int(area.position.x)
	while x <= int(area.end.x):
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(0.17, 0.22, 0.26), 1.0)
		x += 60
	var y := int(area.position.y)
	while y <= int(area.end.y):
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.17, 0.22, 0.26), 1.0)
		y += 60
	draw_rect(area, Color(0.31, 0.62, 0.65), false, 5.0)
