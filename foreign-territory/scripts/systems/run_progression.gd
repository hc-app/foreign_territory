extends Node
class_name RunProgression

signal experience_changed
signal reward_applied(message: String)

const RELIC_LEVEL_UP_CHANCE = 0.4

var player: PlayerController
var level: int = 1
var experience: int = 0
var taken_relics: Array[String] = []
var upgrade_levels: Dictionary = {}


# connects run progression to the current player
func setup(target: PlayerController) -> void:
	player = target
	experience_changed.emit()


# calculates the experience needed to reach the next level
# will need tweaking
func experience_required() -> int:
	return int(ceil(12.0 * pow(float(level), 1.35)))


# adds experience and processes multiple level-ups if necessary
func add_experience(amount: int) -> void:
	experience += maxi(0, amount)
	while experience >= experience_required():
		experience -= experience_required()
		level += 1
		player.apply_stat_upgrade("damage", 1.0) # might change
		var missing_health := player.health_component.max_health - player.health_component.health
		player.health_component.heal(missing_health * 0.2) # might change
		reward_applied.emit("Level %d: +1 damage and restored 20%% missing health" % level) # might change
	experience_changed.emit()


# rolls reward choices first, then rolls a separate rarity for every option
func get_reward_options(kind: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if kind == "relic":
		var available := GameCatalog.pick_relic_options(2, taken_relics, player.luck)
		var upgradable: Array[String] = []
		for relic_id in taken_relics:
			if player.relic_controller.get_level(relic_id) < GameCatalog.MAX_RELIC_LEVEL:
				upgradable.append(relic_id)
		upgradable.shuffle()
		var include_level := not upgradable.is_empty() and (available.is_empty() or randf() < RELIC_LEVEL_UP_CHANCE)
		if include_level:
			options.append(_make_relic_option(upgradable[0], true))
		for entry in available:
			if options.size() >= 2:
				break
			options.append(_make_relic_option(str(entry["id"]), false))
		if options.is_empty() and not upgradable.is_empty():
			options.append(_make_relic_option(upgradable[0], true))
		if not options.is_empty():
			return options

	for entry in GameCatalog.pick_options(GameCatalog.UPGRADES, 3):
		var option: Dictionary = entry.duplicate()
		var rarity := GameCatalog.roll_rarity(player.luck)
		option["rarity"] = rarity
		option["option_type"] = "upgrade"
		option["value"] = float(entry["value"]) * GameCatalog.rarity_scale(rarity)
		option["description"] = "+%s %s" % [_format_value(float(option["value"]), str(entry["stat"])), entry["description"]]
		options.append(option)
	return options


# creates a new relic or relic-level option using the relic's fixed rarity
func _make_relic_option(relic_id: String, level_up: bool) -> Dictionary:
	var option := GameCatalog.find_entry(GameCatalog.RELICS, relic_id).duplicate()
	var next_level := 1
	option["option_type"] = "relic_level" if level_up else "relic_new"
	if level_up:
		next_level = player.relic_controller.get_level(relic_id) + 1
		option["description"] = "Increase this relic's level and strengthen its effects"
	option["level"] = next_level
	option["name"] = "%s (Lv. %d)" % [option["name"], next_level]
	return option


# formats percentages and numerical amounts for upgrade descriptions
func _format_value(value: float, stat: String) -> String:
	if stat in ["attack_speed", "crit_chance", "crit_damage"]:
		return "%.1f%%" % (value * 100.0)
	return "%.1f" % value


# applies rarity-scaled stats or increases the level of a fixed-rarity relic
func apply_reward(kind: String, entry: Dictionary) -> bool:
	var entry_id := str(entry.get("id", ""))
	var rarity := str(entry.get("rarity", "common"))
	if GameCatalog.find_entry(GameCatalog.RARITIES, rarity).is_empty():
		return false
	if kind == "relic" and str(entry.get("option_type", "")) != "upgrade":
		var relic := GameCatalog.find_entry(GameCatalog.RELICS, entry_id)
		if relic.is_empty() or rarity != str(relic["rarity"]):
			return false
		var is_level_up := str(entry.get("option_type", "")) == "relic_level"
		if is_level_up != taken_relics.has(entry_id):
			return false
		if is_level_up and player.relic_controller.get_level(entry_id) >= GameCatalog.MAX_RELIC_LEVEL:
			return false
		if not player.relic_controller.add_relic(entry_id):
			return false
		if not is_level_up:
			taken_relics.append(entry_id)
	else:
		var base := GameCatalog.find_entry(GameCatalog.UPGRADES, entry_id)
		if base.is_empty():
			return false
		player.apply_stat_upgrade(str(base["stat"]), float(base["value"]) * GameCatalog.rarity_scale(rarity))
		upgrade_levels[entry_id] = int(upgrade_levels.get(entry_id, 0)) + 1
	reward_applied.emit("Obtained: " + str(entry.get("name", entry_id)))
	return true
