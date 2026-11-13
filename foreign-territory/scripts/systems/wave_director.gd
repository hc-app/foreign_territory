extends Node
class_name WaveDirector

signal wave_started(floor_number: int, wave_number: int)
signal wave_cleared
signal enemy_defeated(enemy: EnemyActor, experience: int, tier: String)
signal run_won

@export var total_floors: int = 2
@export var waves_per_floor: int = 3
@export var spawn_interval: float = 0.75

var floor_number: int = 1
var wave_number: int = 0
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
	_running = true
	_start_wave()


# spawns enemies over time and detects when each wave is cleared
func _process(delta: float) -> void:
	if not _running:
		return
	if _transition_timer >= 0.0:
		_transition_timer -= delta
		if _transition_timer < 0.0:
			_advance_wave()
		return
	if _enemies_to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_enemies_to_spawn -= 1
			_spawn_timer = spawn_interval
	elif _alive_enemies == 0:
		wave_cleared.emit()
		_transition_timer = 4.5


# prepares a normal wave or a final boss wave for the current floor
func _start_wave() -> void:
	wave_number += 1
	_enemies_to_spawn = 2 if wave_number == waves_per_floor else 4 + wave_number * 3 + floor_number
	if wave_number == waves_per_floor:
		_enemies_to_spawn += 1
	_spawn_timer = 0.4
	_alive_enemies = 0
	wave_started.emit(floor_number, wave_number)


# instantiates a temporary enemy setup for the AI and world teams to replace
func _spawn_enemy() -> void:
	var index := _enemies_to_spawn
	var rank := "normal"
	if wave_number == waves_per_floor and index == 1:
		rank = "boss"
	elif randf() < 0.12:
		rank = "elite"
	var kind := "ranged" if randf() < 0.35 else "melee"
	var enemy := EnemyActor.new()
	enemy.configure(kind, rank, floor_number, player)
	world.add_child(enemy)
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(260.0, 410.0)
	enemy.global_position = (player.global_position + Vector2.RIGHT.rotated(angle) * distance).clamp(
		Vector2(-590.0, -305.0), Vector2(590.0, 305.0)
	)
	enemy.defeated.connect(_on_enemy_defeated)
	_alive_enemies += 1


# forwards enemy rewards and reduces the current wave's enemy count
func _on_enemy_defeated(enemy: EnemyActor, experience: int, rank: String) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	enemy_defeated.emit(enemy, experience, rank)


# advances to the next wave, floor, or end of the run
func _advance_wave() -> void:
	if wave_number >= waves_per_floor:
		if floor_number >= total_floors:
			_running = false
			run_won.emit()
			return
		floor_number += 1
		wave_number = 0
	_start_wave()


# prevents additional spawning and transitions after player death
func stop_run() -> void:
	_running = false
