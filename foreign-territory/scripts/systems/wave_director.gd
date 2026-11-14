extends Node
class_name WaveDirector

signal room_started(room_number: int, total_rooms: int)
signal room_cleared
signal room_change_requested(next_room: int)
signal enemy_defeated(enemy: EnemyActor, experience: int, tier: String)
signal run_won

@export var total_rooms: int = 3
@export var normal_enemies_per_room: int = 7
@export var enemies_added_per_room: int = 2
@export var spawn_interval: float = 0.75
@export var elite_chance: float = 0.1
@export var room_clear_delay: float = 3.0

var room_number: int = 1
var player: PlayerController
var world: Node2D
var _enemies_to_spawn: int = 0
var _alive_enemies: int = 0
var _spawn_timer: float = 0.0
var _transition_timer: float = -1.0
var _running: bool = false


# binds the wave system to the level and current player
func setup(level_root: Node2D, target: PlayerController) -> void:
	world = level_root
	player = target


# starts the first wave when a new run begins
func start_run() -> void:
	room_number = 1
	_running = true
	_start_room()


# starts the next room after the main scene has loaded its layout
func begin_room(next_room: int) -> void:
	room_number = next_room
	_running = true
	_transition_timer = -1.0
	_start_room()


# spawns enemies over time and detects when each room is cleared
func _process(delta: float) -> void:
	if not _running:
		return
	if _transition_timer >= 0.0:
		_transition_timer -= delta
		if _transition_timer < 0.0:
			_advance_room()
		return
	if _enemies_to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_enemies_to_spawn -= 1
			_spawn_timer = spawn_interval
	elif _alive_enemies == 0:
		room_cleared.emit()
		_transition_timer = room_clear_delay


# prepares one wave per room with a boss in the final room
func _start_room() -> void:
	_enemies_to_spawn = normal_enemies_per_room + (room_number - 1) * enemies_added_per_room
	if room_number == total_rooms:
		_enemies_to_spawn += 1
	_spawn_timer = 0.4
	_alive_enemies = 0
	room_started.emit(room_number, total_rooms)


# spawns enemies using room-provided positions instead of a fixed map
func _spawn_enemy() -> void:
	var index := _enemies_to_spawn
	var rank := "normal"

	if room_number == total_rooms and index == 1:
		rank = "boss"
	elif randf() < elite_chance:
		rank = "elite"

	var kind := "ranged" if randf() < 0.35 else "melee"
	var enemy := EnemyActor.new()
	enemy.configure(kind, rank, room_number, player)
	var spawn_position := player.global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 300.0
	if world.has_method("get_enemy_spawn_position"):
		spawn_position = world.get_enemy_spawn_position(player.global_position)
	enemy.position = world.to_local(spawn_position)
	world.add_child(enemy)

	enemy.defeated.connect(_on_enemy_defeated)
	_alive_enemies += 1


# forwards enemy rewards and reduces the current wave's enemy count
func _on_enemy_defeated(enemy: EnemyActor, experience: int, rank: String) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	enemy_defeated.emit(enemy, experience, rank)


# asks the main scene to replace the room or finish the run
func _advance_room() -> void:
	_running = false
	if room_number >= total_rooms:
		run_won.emit()
	else:
		room_change_requested.emit(room_number + 1)


# prevents additional spawning and transitions after player death
func stop_run() -> void:
	_running = false
