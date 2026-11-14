extends Control
class_name MainMenu

signal start_requested

var _shop_open: bool = false


# creates the title screen and keeps purchased upgrades up to date
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameData.changed.connect(_render)
	_render()


# rebuilds the main menu or meta-upgrade shop after a purchase
func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color(0.055, 0.085, 0.11)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 260)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(edge, 24)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	_add_label(layout, "FOREIGN TERRITORY", 30)
	_add_label(layout, "Meta currency: %d" % GameData.currency, 20)
	if _shop_open:
		_build_shop(layout)
	else:
		_add_label(layout, "Alien survival | Top-down roguelite", 17)
		_add_button(layout, "Start Run", func() -> void: start_requested.emit())
		_add_button(layout, "Permanent Upgrades", _open_shop)
		_add_button(layout, "Quit", func() -> void: get_tree().quit())
		_add_label(layout, "WASD / arrow keys: move   |   Space: dash", 15)


# displays purchase choices using the shared upgrade catalog
func _build_shop(layout: VBoxContainer) -> void:
	_add_label(layout, "PERMANENT UPGRADES", 22)
	for entry in GameCatalog.META_UPGRADES:
		var current_level := GameData.get_level(entry["id"])
		var max_level: int = entry["max_level"]
		var label_text := "%s  (%d/%d)  —  %s" % [entry["name"], current_level, max_level, entry["description"]]
		_add_label(layout, label_text, 16)
		var button_text := "MAXED" if current_level >= max_level else "Buy for %d currency" % GameData.get_cost(entry)
		var button := _add_button(layout, button_text, _buy_upgrade.bind(entry["id"]))
		button.disabled = current_level >= max_level or GameData.currency < GameData.get_cost(entry)
	_add_button(layout, "Reset Save Data", _confirm_reset)
	_add_button(layout, "Back", _close_shop)


# opens the meta-upgrade shop without leaving the main menu
func _open_shop() -> void:
	_shop_open = true
	_render()


# returns to the start screen from the meta-upgrade shop
func _close_shop() -> void:
	_shop_open = false
	_render()


# requests confirmation before resetting permanent progression
func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset Saved Progress"
	dialog.dialog_text = "Delete all meta currency and permanent upgrades? This cannot be undone."
	dialog.ok_button_text = "Reset Progress"
	add_child(dialog)
	dialog.confirmed.connect(GameData.reset_progress)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


# purchases a permanent upgrade and refreshes the shop
func _buy_upgrade(upgrade_id: String) -> void:
	GameData.purchase_upgrade(upgrade_id)


# creates a consistently sized label for the menu
func _add_label(parent: Node, value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


# creates a button and connects its requested action
func _add_button(parent: Node, value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
