extends Node2D

const LEVEL_SCENE = preload("res://scenes/world_environment/level_template.tscn")

@export var total_rooms: int = 3
@export var room_scenes: Array[PackedScene] = []

var menu: MainMenu
var menu_layer: CanvasLayer
var world: Node2D
var player: PlayerController
var progression: RunProgression
var director: WaveDirector
var hud: GameHUD
var _reward_queue: Array[Dictionary] = []
var _reward_active: bool = false
var _active_reward_kind: String = ""
var _run_ended: bool = false


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


# creates a fresh run and connects all gameplay systems together
func _start_run() -> void:
	get_tree().paused = false
	if menu_layer != null and is_instance_valid(menu_layer):
		menu_layer.queue_free()
		menu_layer = null
	_clear_run()
	_run_ended = false
	_reward_active = false
	_reward_queue.clear()

	progression = RunProgression.new()
	add_child(progression)
	director = WaveDirector.new()
	director.total_rooms = maxi(1, total_rooms)
	add_child(director)
	_load_room(1)
	progression.setup(player)

	hud = GameHUD.new()
	add_child(hud)
	hud.setup(player, progression, director)
	hud.reward_chosen.connect(_on_reward_chosen)
	hud.restart_requested.connect(_start_run)
	hud.menu_requested.connect(_show_menu)
	progression.reward_applied.connect(hud.show_message)
	director.room_started.connect(_on_room_started)
	director.room_cleared.connect(_on_room_cleared)
	director.room_change_requested.connect(_on_room_change_requested)
	director.enemy_defeated.connect(_on_enemy_defeated)
	director.run_won.connect(_on_run_won)
	director.start_run()


# loads a room scene while keeping the existing player's run progression
func _load_room(room_index: int) -> void:
	var room_scene: PackedScene = LEVEL_SCENE
	if room_index <= room_scenes.size() and room_scenes[room_index - 1] != null:
		room_scene = room_scenes[room_index - 1]
	var next_world := room_scene.instantiate() as Node2D
	if next_world == null:
		push_error("Room scene must have a Node2D root")
		return

	var placeholder := next_world.get_node_or_null("Player")
	if placeholder != null:
		next_world.remove_child(placeholder)
		placeholder.free()

	if player == null:
		player = PlayerController.new()
		player.name = "Player"
		next_world.add_child(player)
		player.died.connect(_on_player_died)
	else:
		player.reparent(next_world, false)
	player.position = Vector2.ZERO
	player.reset_physics_interpolation()
	if next_world.has_method("get_player_spawn_position"):
		player.position = next_world.get_player_spawn_position()
	player.reset_physics_interpolation()
	if next_world.has_method("get_room_bounds"):
		player.arena_bounds = next_world.get_room_bounds()

	var old_world := world
	world = next_world
	add_child(world)
	if old_world != null and is_instance_valid(old_world):
		old_world.queue_free()
	director.setup(world, player)


# grants experience, drops rarity-based rewards, and awards elite/boss currency
func _on_enemy_defeated(enemy: EnemyActor, experience: int, rank: String) -> void:
	if _run_ended:
		return
	progression.add_experience(experience)
	if rank == "elite":
		GameData.earn_currency(1)
	elif rank == "boss":
		GameData.earn_currency(4)

	var drop_kind := _roll_enemy_drop(rank)
	if not drop_kind.is_empty():
		var rarity := GameCatalog.roll_rarity(player.luck)
		call_deferred("_spawn_pickup", drop_kind, rarity, enemy.global_position)


# rolls lower base drop rates and applies the player's luck modifier
func _roll_enemy_drop(rank: String) -> String:
	if rank == "boss":
		return "relic"
	var relic_chance := 0.012
	var upgrade_chance := 0.09
	if rank == "elite":
		relic_chance = 0.25
		upgrade_chance = 0.12
	var total_chance := relic_chance + upgrade_chance
	var roll := randf()
	if roll >= GameCatalog.chance_with_luck(total_chance, player.luck):
		return ""
	return "relic" if randf() < relic_chance / total_chance else "upgrade"


# places a rarity-tagged reward after physics callbacks have finished
func _spawn_pickup(kind: String, rarity: String, spawn_position: Vector2) -> void:
	if _run_ended or world == null or not is_instance_valid(world):
		return
	var pickup := RewardPickup.new()
	pickup.pickup_kind = kind
	pickup.rarity = rarity
	world.add_child(pickup)
	pickup.global_position = spawn_position
	pickup.collected.connect(_on_pickup_collected)


# queues an upgrade or relic choice when the player collects a drop
func _on_pickup_collected(kind: String, rarity: String) -> void:
	if _run_ended:
		return
	_reward_queue.append({"kind": kind, "rarity": rarity})
	_show_next_reward()


# pauses the action and presents the next collected reward
func _show_next_reward() -> void:
	if _reward_active or _run_ended:
		return
	while not _reward_queue.is_empty():
		var reward: Dictionary = _reward_queue.pop_front()
		_active_reward_kind = str(reward["kind"])
		var rarity := str(reward["rarity"])
		var options := progression.get_reward_options(_active_reward_kind, rarity)
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


# announces the next room after a layout has been loaded
func _on_room_started(room_number: int, room_count: int) -> void:
	hud.show_message("Room %d/%d" % [room_number, room_count])


# collects leftover rewards before leaving a cleared room
func _on_room_cleared() -> void:
	hud.show_message("Room clear! Collecting remaining drops.")
	for node in world.get_children():
		var pickup := node as RewardPickup
		if pickup != null and not pickup.is_queued_for_deletion():
			_reward_queue.append({"kind": pickup.pickup_kind, "rarity": pickup.rarity})
			pickup.queue_free()
	_show_next_reward()


# waits until the current room is clear before replacing its layout
func _on_room_change_requested(next_room: int) -> void:
	call_deferred("_enter_next_room", next_room)


# switches rooms without resetting the player's upgrades or relics
func _enter_next_room(next_room: int) -> void:
	if _run_ended:
		return
	_load_room(next_room)
	director.begin_room(next_room)


# finishes the run when the player runs out of health
func _on_player_died() -> void:
	_finish_run(false)


# finishes the run when the final boss and wave are cleared
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
