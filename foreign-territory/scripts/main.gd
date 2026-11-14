extends Node2D

const LEVEL_SCENE = preload("res://scenes/world_environment/level_template.tscn")

@export var rooms_per_floor: int = 3
@export var max_floors: int = 5
@export var start_room_scene: PackedScene
@export var boss_room_scene: PackedScene
@export var room_scenes: Array[PackedScene] = []
@export var normal_drop_chance: float = 0.025
@export var elite_drop_chance: float = 0.18
@export var relic_reward_share: float = 0.30

var menu: MainMenu
var menu_layer: CanvasLayer
var world: Node2D
var player: PlayerController
var progression: RunProgression
var director: WaveDirector
var hud: GameHUD
var ship_parts: int = 0
var _reward_queue: Array[String] = []
var _reward_active: bool = false
var _active_reward_kind: String = ""
var _run_ended: bool = false
var _transitioning: bool = false
var _endless_mode: bool = false
var _pending_exit_position: Vector2
var _pending_exit_direction: String = "right"


# creates the input actions and opens the main menu
func _ready() -> void:
	_setup_input()
	_show_menu()


# defines movement and dashing without editing the team's input settings
func _setup_input() -> void:
	var controls := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SPACE],
		"interact": [KEY_E],
	}
	for action in controls:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in controls[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


# displays the title screen with the persistent upgrade shop
func _show_menu() -> void:
	get_tree().paused = false
	_clear_run()
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	menu = MainMenu.new()
	menu_layer.add_child(menu)
	menu.start_requested.connect(_start_run)


# creates a campaign or endless testing run using the same gameplay systems
func _start_run(endless_mode: bool = false) -> void:
	get_tree().paused = false
	_endless_mode = endless_mode
	if menu_layer != null and is_instance_valid(menu_layer):
		menu_layer.queue_free()
		menu_layer = null
	_clear_run()
	_run_ended = false
	_transitioning = false
	ship_parts = 0
	_reward_active = false
	_reward_queue.clear()

	progression = RunProgression.new()
	add_child(progression)
	director = WaveDirector.new()
	director.rooms_per_floor = maxi(1, rooms_per_floor)
	director.max_floors = maxi(0, max_floors)
	director.endless_waves = endless_mode
	add_child(director)
	_load_room(1 if endless_mode else 0)
	progression.setup(player)

	hud = GameHUD.new()
	add_child(hud)
	hud.setup(player, progression, director)
	hud.reward_chosen.connect(_on_reward_chosen)
	hud.restart_requested.connect(_restart_run)
	hud.menu_requested.connect(_show_menu)
	progression.reward_applied.connect(hud.show_message)
	director.room_started.connect(_on_room_started)
	director.room_cleared.connect(_on_room_cleared)
	director.room_change_requested.connect(_on_room_change_requested)
	director.enemy_defeated.connect(_on_enemy_defeated)
	director.run_won.connect(_on_run_won)
	director.start_run()
	if not endless_mode:
		world.call("set_exits_locked", false)


# restarts the selected mode without returning to the main menu
func _restart_run() -> void:
	_start_run(_endless_mode)


# loads a room beside the previous doorway without resetting the player to center
func _load_room(room_index: int, exit_position: Vector2 = Vector2.ZERO, exit_direction: String = "right") -> void:
	var room_scene: PackedScene = LEVEL_SCENE
	if room_index == 0 and start_room_scene != null:
		room_scene = start_room_scene
	elif room_index == rooms_per_floor and boss_room_scene != null:
		room_scene = boss_room_scene
	elif room_index > 0 and not room_scenes.is_empty():
		var scene_index := (room_index - 1) % room_scenes.size()
		if room_scenes[scene_index] != null:
			room_scene = room_scenes[scene_index]
	var next_world := room_scene.instantiate() as Node2D
	if next_world == null:
		push_error("Room scene must have a Node2D root")
		return

	var placeholder := next_world.get_node_or_null("Player")
	if placeholder != null:
		next_world.remove_child(placeholder)
		placeholder.free()
	add_child(next_world)

	var entry_position := Vector2.ZERO
	if player != null and next_world.has_method("get_entry_position"):
		var placement = next_world.call("get_entry_position", exit_direction)
		if placement is Vector2:
			entry_position = placement
		var forward := Vector2.RIGHT
		match exit_direction:
			"left":
				forward = Vector2.LEFT
			"up":
				forward = Vector2.UP
			"down":
				forward = Vector2.DOWN
		next_world.global_position = exit_position + forward * 48.0 - entry_position
	if player == null:
		player = PlayerController.new()
		player.name = "Player"
		next_world.add_child(player)
		player.died.connect(_on_player_died)
		if next_world.has_method("get_player_spawn_position"):
			var placement = next_world.call("get_player_spawn_position")
			if placement is Vector2:
				player.position = placement
	else:
		player.reparent(next_world, true)
		player.position = entry_position
	if next_world.has_method("get_room_bounds"):
		var bounds = next_world.call("get_room_bounds")
		if bounds is Rect2:
			player.arena_bounds = bounds
	if next_world.has_method("set_active_player"):
		next_world.call("set_active_player", player)
	if next_world.has_signal("exit_requested"):
		next_world.connect("exit_requested", _on_room_exit_requested)

	var previous_world := world
	world = next_world
	player.reset_physics_interpolation()
	if previous_world != null and is_instance_valid(previous_world):
		previous_world.queue_free()
	director.setup(world, player)


# grants experience, rolls reward drops, and awards elite/boss currency
func _on_enemy_defeated(enemy: EnemyActor, experience: int, rank: String) -> void:
	if _run_ended:
		return
	progression.add_experience(experience)
	if rank == "elite":
		GameData.earn_currency(1)
	elif rank == "boss":
		GameData.earn_currency(4)
		if not _endless_mode:
			call_deferred("_spawn_pickup", "ship_part", enemy.global_position)

	var drop_kind := _roll_enemy_drop(rank)
	if not drop_kind.is_empty():
		call_deferred("_spawn_pickup", drop_kind, enemy.global_position + Vector2(32.0, 0.0))


# rolls the overall drop chance before choosing a 70/30 upgrade or relic reward
func _roll_enemy_drop(rank: String) -> String:
	if rank == "boss":
		return "relic"
	var base_chance := elite_drop_chance if rank == "elite" else normal_drop_chance
	if randf() >= GameCatalog.chance_with_luck(base_chance, player.luck):
		return ""
	return "relic" if randf() < clampf(relic_reward_share, 0.0, 1.0) else "upgrade"


# places a reward after physics collision callbacks have finished
func _spawn_pickup(kind: String, spawn_position: Vector2) -> void:
	if _run_ended or world == null or not is_instance_valid(world):
		return
	var pickup := RewardPickup.new()
	pickup.pickup_kind = kind
	world.add_child(pickup)
	pickup.global_position = spawn_position
	pickup.collected.connect(_on_pickup_collected)


# queues an upgrade or relic choice when the player collects a drop
func _on_pickup_collected(kind: String) -> void:
	if _run_ended:
		return
	if kind == "ship_part":
		ship_parts += 1
		hud.show_message("Ship repair parts: %d/%d" % [ship_parts, max_floors])
		_unlock_cleared_room()
		return
	_reward_queue.append(kind)
	_show_next_reward()


# pauses the action and presents the next collected reward
func _show_next_reward() -> void:
	if _reward_active or _run_ended:
		return
	while not _reward_queue.is_empty():
		_active_reward_kind = _reward_queue.pop_front()
		var options := progression.get_reward_options(_active_reward_kind)
		if options.is_empty():
			continue
		_reward_active = true
		get_tree().paused = true
		hud.show_reward(_active_reward_kind, options)
		return


# installs the selected reward and resumes the current run
func _on_reward_chosen(entry: Dictionary) -> void:
	if not _reward_active:
		return
	if not progression.apply_reward(_active_reward_kind, entry):
		return
	_reward_active = false
	hud.hide_overlay()
	get_tree().paused = false
	_show_next_reward()


# announces the current room or endless wave when enemies begin spawning
func _on_room_started(floor_number: int, room_number: int) -> void:
	if _endless_mode:
		hud.show_message("Endless wave %d — depth %d" % [director.wave_number, floor_number])
	elif room_number == 0:
		hud.show_message("Starting room: press E at the open green doorway")
	else:
		hud.show_message("Floor %d, Room %d/%d" % [floor_number, room_number, director.rooms_per_floor])
	world.call("set_exits_locked", _endless_mode or room_number != 0)


# collects leftover rewards and applies room-clear relic effects
func _on_room_cleared() -> void:
	player.relic_controller.on_room_cleared()
	for node in world.get_children():
		var pickup := node as RewardPickup
		if pickup != null and pickup.pickup_kind != "ship_part" and not pickup.is_queued_for_deletion():
			_reward_queue.append(pickup.pickup_kind)
			pickup.queue_free()
	_show_next_reward()
	if _endless_mode:
		hud.show_message("Wave %d cleared! Next wave approaching" % director.wave_number)
	else:
		_unlock_cleared_room()


# unlocks exits only after the wave and any required ship part are complete
func _unlock_cleared_room() -> void:
	if _endless_mode or not director.room_is_cleared or _run_ended:
		return
	if director.room_number == director.rooms_per_floor and ship_parts < director.floor_number:
		hud.show_message("Collect the ship part to unlock the exit")
		return
	if max_floors > 0 and ship_parts >= max_floors and director.floor_number >= max_floors:
		_finish_run(true)
		return
	world.call("set_exits_locked", false)
	if director.room_number != 0:
		hud.show_message("Room clear! Press E at a green doorway")


# responds to doorway interaction only after the current room is complete
func _on_room_exit_requested(exit_door: RoomExit) -> void:
	if _endless_mode or _run_ended or _transitioning or not director.room_is_cleared:
		return
	_transitioning = true
	_pending_exit_position = exit_door.global_position
	_pending_exit_direction = exit_door.direction
	director.advance_room()


# requests a new room layout after the player uses an open doorway
func _on_room_change_requested(next_floor: int, next_room: int) -> void:
	call_deferred("_enter_next_room", next_floor, next_room)


# switches rooms without resetting the player's upgrades or relics
func _enter_next_room(next_floor: int, next_room: int) -> void:
	if _run_ended:
		return
	_load_room(next_room, _pending_exit_position, _pending_exit_direction)
	director.begin_room(next_floor, next_room)
	_transitioning = false


# finishes the run when the player runs out of health
func _on_player_died() -> void:
	_finish_run(false)


# finishes a run only when a nonzero floor limit is reached
func _on_run_won() -> void:
	_finish_run(true)


# freezes the finished run and displays restart/menu options
func _finish_run(won: bool) -> void:
	if _run_ended:
		return
	_run_ended = true
	director.stop_run()
	get_tree().paused = true
	hud.show_run_end(won)


# removes old run scenes and HUD elements before restarting or returning
func _clear_run() -> void:
	for node in [hud, world, progression, director]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	hud = null
	world = null
	player = null
	director = null
	progression = null
