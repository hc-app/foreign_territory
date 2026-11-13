extends Node
class_name RunProgression

signal experience_changed
signal reward_applied(message: String)

var player: PlayerController
var level: int = 1
var experience: int = 0
var relic_slots: int = 3
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


# creates three stat options or two new relic options for a pickup
# will add more/different options later
func get_reward_options(kind: String) -> Array[Dictionary]:
	if kind == "relic" and taken_relics.size() < relic_slots:
		return GameCatalog.pick_options(GameCatalog.RELICS, 2, taken_relics)
	return GameCatalog.pick_options(GameCatalog.UPGRADES, 3)


# applies a chosen reward while enforcing relic slots and uniqueness
# works better than I thought, but is a simple solution for now
func apply_reward(kind: String, entry: Dictionary) -> bool:
	if kind == "relic":
		if taken_relics.size() >= relic_slots or taken_relics.has(entry["id"]):
			return false
		if GameCatalog.find_entry(GameCatalog.RELICS, entry["id"]).is_empty():
			return false
		taken_relics.append(entry["id"])
		player.relic_controller.add_relic(entry["id"])
	else:
		if GameCatalog.find_entry(GameCatalog.UPGRADES, entry["id"]).is_empty():
			return false
		player.apply_stat_upgrade(entry["stat"], float(entry["value"]))
		upgrade_levels[entry["id"]] = int(upgrade_levels.get(entry["id"], 0)) + 1
	reward_applied.emit("Obtained: " + entry["name"])
	return true
