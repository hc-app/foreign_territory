extends Node
class_name WaveDirector

signal room_started(floor_number: int, room_number: int)
signal room_cleared
signal room_change_requested(next_floor: int, next_room: int)
signal enemy_defeated(enemy: EnemyActor, experience: int, tier: String)
signal run_won

@export_range(1, 20) var rooms_per_floor: int = 3
@export_range(0, 999) var max_floors: int = 5
@export var normal_enemies_per_room: int = 6
@export var enemies_added_per_floor: int = 2
@export var enemies_added_per_room: int = 2
@export var maximum_enemies_per_room: int = 60
@export var spawn_interval: float = 0.75
@export var elite_chance: float = 0.1
@export var armored_enemy_chance: float = 0.25

var floor_number: int = 1
var room_number: int = 0
var room_is_cleared: bool = false
var player: PlayerController
var world: Node2D
var _enemies_to_spawn: int = 0
var _alive_enemies: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false


# binds the wave system to the level and current player
func setup(level_root: Node2D, target: PlayerController) -> void:
	world = level_root
	player = target


# starts in a peaceful entry room before the first wave
func start_run() -> void:
	floor_number = 1
	room_number = 0
	_running = false
	room_is_cleared = true
	room_started.emit(floor_number, room_number)


# starts the next room or floor after its layout has been loaded
func begin_room(next_floor: int, next_room: int) -> void:
	floor_number = next_floor
	room_number = next_room
	_running = true
	room_is_cleared = false
	_start_room()


# spawns enemies over time and detects when each room is cleared
func _process(delta: float) -> void:
	if not _running:
		return
	if _enemies_to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_enemies_to_spawn -= 1
			_spawn_timer = spawn_interval
	elif _alive_enemies == 0:
		_running = false
		room_is_cleared = true
		room_cleared.emit()


# prepares one wave per room and adds a boss to the last room of every floor
func _start_room() -> void:
	var count := normal_enemies_per_room + (room_number - 1) * enemies_added_per_room
	count += (floor_number - 1) * enemies_added_per_floor
	_enemies_to_spawn = mini(maximum_enemies_per_room, count)
	if room_number == rooms_per_floor:
		_enemies_to_spawn += 1
	_spawn_timer = 0.4
	_alive_enemies = 0
	room_started.emit(floor_number, room_number)


# spawns enemies using room-provided positions instead of a fixed map
func _spawn_enemy() -> void:
	var index := _enemies_to_spawn
	var rank := "normal"
	if room_number == rooms_per_floor and index == 1:
		rank = "boss"
	elif randf() < elite_chance:
		rank = "elite"

	var kind := "ranged" if randf() < 0.35 else "melee"
	var enemy := EnemyActor.new()
	enemy.configure(kind, rank, floor_number, player)
	enemy.starts_armored = rank == "boss" or (rank == "elite" and randf() < 0.7) or randf() < armored_enemy_chance
	var spawn_position := player.global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 300.0
	if world.has_method("get_enemy_spawn_position"):
		spawn_position = world.call("get_enemy_spawn_position", player.global_position)
	enemy.position = world.to_local(spawn_position)
	world.add_child(enemy)

	enemy.defeated.connect(_on_enemy_defeated)
	_alive_enemies += 1


# forwards enemy rewards and reduces the current wave's enemy count
func _on_enemy_defeated(enemy: EnemyActor, experience: int, rank: String) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	enemy_defeated.emit(enemy, experience, rank)


# advances after an unlocked doorway is used instead of automatically clearing rooms
func advance_room() -> void:
	if not room_is_cleared:
		return
	var next_floor := floor_number
	var next_room := room_number + 1
	if next_room > rooms_per_floor:
		if max_floors > 0 and floor_number >= max_floors:
			run_won.emit()
			return
		next_floor += 1
		next_room = 1
	room_change_requested.emit(next_floor, next_room)


# prevents additional spawning and transitions after player death
func stop_run() -> void:
	_running = false
