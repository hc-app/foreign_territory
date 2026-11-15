extends CanvasLayer
class_name GameHUD

signal reward_chosen(entry: Dictionary)
signal pause_requested
signal restart_requested
signal menu_requested

var player: PlayerController
var progression: RunProgression
var director: WaveDirector
var run_controller: Node2D
var _status: Label
var _combat_stats: Label
var _dash_bar: ProgressBar
var _wave_status: Label
var _resource_stats: Label
var _message: Label
var _help: Label
var _overlay: Control
var pause_menu_open: bool = false
var _message_time: float = 0.0


# builds the gameplay HUD and controls that still work while paused
func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)

	var left := VBoxContainer.new()
	left.offset_left = 20
	left.offset_top = 16
	left.offset_right = 650
	left.offset_bottom = 140
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(left)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 19)
	left.add_child(_status)
	_combat_stats = Label.new()
	_combat_stats.add_theme_font_size_override("font_size", 17)
	left.add_child(_combat_stats)
	_wave_status = Label.new()
	_wave_status.add_theme_font_size_override("font_size", 18)
	left.add_child(_wave_status)
	_resource_stats = Label.new()
	_resource_stats.add_theme_font_size_override("font_size", 16)
	left.add_child(_resource_stats)
	_dash_bar = ProgressBar.new()
	_dash_bar.custom_minimum_size = Vector2(245.0, 18.0)
	_dash_bar.max_value = 100.0
	_dash_bar.show_percentage = false
	left.add_child(_dash_bar)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 18)
	_message.modulate = Color(1.0, 0.92, 0.62)
	left.add_child(_message)

	var help := Label.new()
	help.text = "WASD / Arrows: move  •  Space: dash  •  E: door  •  Esc: pause"
	help.position = Vector2(20, 665)
	help.add_theme_font_size_override("font_size", 16)
	canvas.add_child(help)
	_help = help


# opens or closes the pause menu only when no other overlay is active
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and (pause_menu_open or _overlay == null):
		pause_requested.emit()
		get_viewport().set_input_as_handled()


# updates player and wave values without coupling other scripts to UI nodes
func _process(delta: float) -> void:
	if player != null and progression != null and director != null and is_instance_valid(player):
		var health := player.health_component
		_status.text = "HP %.1f/%.1f  Shield %.1f  Damage %.1f" % [
			health.health, health.max_health, health.total_shield(), player.attack_damage
		]
		_combat_stats.text = "Crit %.1f%% (+%.0f%% damage)  Luck %.1f" % [
			player.crit_chance * 100.0, player.crit_damage * 100.0, player.luck
		]
		var part_count := 0
		var part_goal := 5
		if run_controller != null:
			part_count = int(run_controller.get("ship_parts"))
			part_goal = maxi(1, int(run_controller.get("max_floors")))
		if director.endless_waves:
			_wave_status.text = "Endless wave %d  Depth %d  Lv %d  XP %d/%d  Dashes %d/%d" % [
				director.wave_number, director.floor_number, progression.level,
				progression.experience, progression.experience_required(), player.dash_charges,
				player.max_dash_charges
			]
		else:
			_wave_status.text = "Floor %d  Room %d/%d  Parts %d/%d  Lv %d  XP %d/%d  Dashes %d/%d" % [
				director.floor_number, director.room_number, director.rooms_per_floor, part_count,
				part_goal, progression.level, progression.experience, progression.experience_required(),
				player.dash_charges, player.max_dash_charges
			]
		_resource_stats.text = "Relics %d  Meta %d  Dash %.2fs  Area %.0f%%  Status %.0f%%" % [
			progression.taken_relics.size(), GameData.currency, player.dash_cooldown,
			player.area_radius * 100.0, player.status_potency * 100.0
		]
		_dash_bar.value = player.get_dash_recharge_ratio() * 100.0

	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""


# attaches HUD readouts to this run's gameplay systems
func setup(target: PlayerController, run_progression: RunProgression, wave_director: WaveDirector) -> void:
	player = target
	progression = run_progression
	director = wave_director
	run_controller = wave_director.get_parent() as Node2D
	if _help != null and wave_director.endless_waves:
		_help.text = "WASD / Arrows: move  •  Space: dash  •  Esc: pause  •  Survive waves"


# displays a short message for leveling, drops, and wave changes
func show_message(value: String) -> void:
	_message.text = value
	_message_time = 3.0


# shows selectable upgrades or relics and pauses gameplay behind them
func show_reward(kind: String, options: Array[Dictionary]) -> void:
	_create_overlay()
	var layout := _make_overlay_panel()
	_add_overlay_label(layout, "CHOOSE A %s" % kind.to_upper(), 25)
	for entry in options:
		var button := Button.new()
		var rarity := str(entry.get("rarity", "common"))
		var rarity_entry := GameCatalog.find_entry(GameCatalog.RARITIES, rarity)
		var rarity_name := str(rarity_entry.get("name", "Common"))
		button.text = "%s — %s\n%s" % [rarity_name, entry["name"], entry["description"]]
		var color := GameCatalog.rarity_color(rarity)
		for theme_color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(theme_color, color)
		button.custom_minimum_size.y = 64
		button.pressed.connect(_select_reward.bind(entry))
		layout.add_child(button)


# pauses gameplay and presents resume, options, and menu controls
func show_pause_menu() -> void:
	_create_overlay()
	pause_menu_open = true
	var layout := _make_overlay_panel()
	_add_overlay_label(layout, "PAUSED", 28)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func() -> void: pause_requested.emit())
	layout.add_child(resume)
	var options := Button.new()
	options.text = "Options (Coming Soon)"
	options.disabled = true
	layout.add_child(options)
	var menu := Button.new()
	menu.text = "Return to Main Menu"
	menu.pressed.connect(func() -> void: menu_requested.emit())
	layout.add_child(menu)


# shows win or loss controls when the current run ends
func show_run_end(won: bool) -> void:
	_create_overlay()
	var layout := _make_overlay_panel()
	_add_overlay_label(layout, "ESCAPED EARTH!" if won else "RUN OVER", 28)
	_add_overlay_label(layout, "Meta currency earned is saved for future runs.", 17)
	var again := Button.new()
	again.text = "Play Again"
	again.pressed.connect(func() -> void: restart_requested.emit())
	layout.add_child(again)
	var menu := Button.new()
	menu.text = "Main Menu / Permanent Upgrades"
	menu.pressed.connect(func() -> void: menu_requested.emit())
	layout.add_child(menu)


# clears the active reward, pause, or end-of-run overlay
func hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	pause_menu_open = false


# adds a darkened background that blocks gameplay clicks
func _create_overlay() -> void:
	hide_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	get_child(0).add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)


# creates a centered panel shared by reward and end screens
func _make_overlay_panel() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 220)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(edge, 20)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	return layout


# creates a heading or explanation inside an overlay
func _add_overlay_label(parent: Node, value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


# sends the chosen upgrade back to the run progression system
func _select_reward(entry: Dictionary) -> void:
	reward_chosen.emit(entry)
