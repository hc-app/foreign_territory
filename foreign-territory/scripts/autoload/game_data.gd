extends Node

signal changed

const SAVE_PATH = "user://foreign_territory_save.json"

var currency: int = 0
var purchased: Dictionary = {}


# loads permanent progression when the game starts
func _ready() -> void:
	load_data()


# restores saved currency and purchased upgrades
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return
	currency = maxi(0, int(parsed.get("currency", 0)))
	var levels = parsed.get("purchased", {})
	if levels is Dictionary:
		purchased = levels
	changed.emit()


# writes permanent progression without storing temporary run upgrades
func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save permanent progression")
		return
	file.store_string(JSON.stringify({"currency": currency, "purchased": purchased}))


# adds currency earned from elite or boss enemies
func earn_currency(amount: int) -> void:
	currency += maxi(0, amount)
	save_data()
	changed.emit()


# returns how many times a permanent upgrade has been purchased
func get_level(upgrade_id: String) -> int:
	return int(purchased.get(upgrade_id, 0))


# calculates the cost of the next purchase
func get_cost(entry: Dictionary) -> int:
	return int(entry["cost"]) * (get_level(entry["id"]) + 1)


# buys a permanent stat upgrade when funds and level limits permit
func purchase_upgrade(upgrade_id: String) -> bool:
	var entry := GameCatalog.find_entry(GameCatalog.META_UPGRADES, upgrade_id)
	if entry.is_empty():
		return false
	var current_level := get_level(upgrade_id)
	if current_level >= int(entry["max_level"]):
		return false
	var cost := get_cost(entry)
	if currency < cost:
		return false
	currency -= cost
	purchased[upgrade_id] = current_level + 1
	save_data()
	changed.emit()
	return true
