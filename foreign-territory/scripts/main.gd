extends Node2D

const LEVEL_SCENE = preload("res://scenes/world_environment/level_template.tscn")

var menu: MainMenu
var menu_layer: CanvasLayer
var world: Node2D
var player: PlayerController
var progression: RunProgression
var director: WaveDirector
var hud: GameHUD
var _reward_queue: Array[String] = []
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


# creates a fresh level and connects all gameplay systems together
func _start_run() -> void:
	get_tree().paused = false
	if menu_layer != null and is_instance_valid(menu_layer):
		menu_layer.queue_free()
		menu_layer = null
	_clear_run()
	_run_ended = false
	_reward_active = false
	_reward_queue.clear()

	world = LEVEL_SCENE.instantiate()
	add_child(world)
	player = world.get_node("Player") as PlayerController
	progression = RunProgression.new()
	world.add_child(progression)
	progression.setup(player)
	director = WaveDirector.new()
	world.add_child(director)
	director.setup(world, player)

	hud = GameHUD.new()
	add_child(hud)
	hud.setup(player, progression, director)
	hud.reward_chosen.connect(_on_reward_chosen)
	hud.restart_requested.connect(_start_run)
	hud.menu_requested.connect(_show_menu)
	progression.reward_applied.connect(hud.show_message)
	director.wave_started.connect(_on_wave_started)
	director.wave_cleared.connect(_on_wave_cleared)
	director.enemy_defeated.connect(_on_enemy_defeated)
	director.run_won.connect(_on_run_won)
	player.died.connect(_on_player_died)
	director.start_run()


# grants experience, drops temporary rewards, and awards elite/boss currency
func _on_enemy_defeated(enemy: EnemyActor, experience: int, rank: String) -> void:
	if _run_ended:
		return
	progression.add_experience(experience)
	if rank == "elite":
		GameData.earn_currency(1)
	elif rank == "boss":
		GameData.earn_currency(4)

	var drop_kind := ""
	var roll := randf()
	if rank == "boss":
		drop_kind = "relic"
	elif rank == "elite":
		drop_kind = "relic" if roll < 0.45 else ("upgrade" if roll < 0.82 else "")
	elif roll < 0.05:
		drop_kind = "relic"
	elif roll < 0.22:
		drop_kind = "upgrade"
	if not drop_kind.is_empty():
		call_deferred("_spawn_pickup", drop_kind, enemy.global_position)


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
func _on_pickup_collected(kind: String, _amount: int) -> void:
	if _run_ended:
		return
	_reward_queue.append(kind)
	_show_next_reward()


# pauses the action and presents the next collected reward
func _show_next_reward() -> void:
	if _reward_active or _reward_queue.is_empty() or _run_ended:
		return
	_active_reward_kind = _reward_queue.pop_front()
	if _active_reward_kind == "relic" and progression.taken_relics.size() >= progression.relic_slots:
		_active_reward_kind = "upgrade"
	var options := progression.get_reward_options(_active_reward_kind)
	if options.is_empty():
		_show_next_reward()
		return
	_reward_active = true
	get_tree().paused = true
	hud.show_reward(_active_reward_kind, options)


# installs the selected reward and resumes the current run
func _on_reward_chosen(entry: Dictionary) -> void:
	if not _reward_active:
		return
	progression.apply_reward(_active_reward_kind, entry)
	_reward_active = false
	hud.hide_overlay()
	get_tree().paused = false
	_show_next_reward()


# shows a short wave announcement when new enemies begin spawning
func _on_wave_started(floor_number: int, wave_number: int) -> void:
	hud.show_message("Floor %d, Wave %d" % [floor_number, wave_number])


# notifies the player that the current wave has ended
func _on_wave_cleared() -> void:
	hud.show_message("Wave clear! Collect any remaining rewards.")


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
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	if world != null and is_instance_valid(world):
		world.queue_free()
	hud = null
	world = null
	player = null
	director = null
	progression = null
