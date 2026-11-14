extends RefCounted
class_name GameCatalog

const MAX_RELIC_LEVEL = 5

# all upgrades names and values are tentative/temporary for now. will require balancing, additions, and possible new names/descriptions
const UPGRADES = [
	{"id": "damage", "name": "Plasma Amplifier", "description": "attack damage", "stat": "damage", "value": 2.0},
	{"id": "speed", "name": "Thrusters", "description": "movement speed", "stat": "move_speed", "value": 25.0},
	{"id": "health", "name": "Reinforced Hull", "description": "maximum health and healing", "stat": "max_health", "value": 2.0},
	{"id": "attack_speed", "name": "Rapid Capacitor", "description": "faster automatic attacks", "stat": "attack_speed", "value": 0.1},
	{"id": "shield", "name": "Shield Battery", "description": "regenerating shield capacity", "stat": "shield", "value": 2.0},
	{"id": "crit_chance", "name": "Targeting Matrix", "description": "critical hit chance", "stat": "crit_chance", "value": 0.05},
	{"id": "crit_damage", "name": "Overcharged Core", "description": "bonus critical hit damage", "stat": "crit_damage", "value": 0.15},
	{"id": "luck", "name": "Lucky Circuit", "description": "luck for drops and rarity", "stat": "luck", "value": 1.0},
]

const RELICS = [
	{"id": "meteor", "name": "Orbital Meteor", "description": "Call down an area attack periodically"},
	{"id": "extra_shot", "name": "Twin Plasma", "description": "Fire additional plasma projectiles"},
	{"id": "aura", "name": "Radiation Field", "description": "Damage nearby enemies periodically"},
	{"id": "dash_shield", "name": "Reactive Barrier", "description": "Gain temporary shield when dashing"},
	{"id": "extra_dash", "name": "Reserve Thruster", "description": "Increase the number of dash charges"},
]

const RARITIES = [
	{"id": "common", "name": "Common", "weight": 60.0, "upgrade_scale": 1.0, "relic_scale": 1.0},
	{"id": "uncommon", "name": "Uncommon", "weight": 26.0, "upgrade_scale": 1.5, "relic_scale": 1.3},
	{"id": "rare", "name": "Rare", "weight": 11.0, "upgrade_scale": 2.0, "relic_scale": 1.7},
	{"id": "legendary", "name": "Legendary", "weight": 3.0, "upgrade_scale": 3.0, "relic_scale": 2.4},
]

# future fusion recipes can specify two relic ids and a resulting effect
const RELIC_FUSIONS = []

const META_UPGRADES = [
	{"id": "damage", "name": "Weapon Calibration", "description": "+1 starting damage", "stat": "damage", "value": 1.0, "cost": 3, "max_level": 5},
	{"id": "health", "name": "Hull Reinforcement", "description": "+1 starting health", "stat": "max_health", "value": 1.0, "cost": 3, "max_level": 6},
	{"id": "speed", "name": "Engine Tuning", "description": "+5 starting move speed", "stat": "move_speed", "value": 5.0, "cost": 2, "max_level": 5},
	{"id": "attack_speed", "name": "Fire Control", "description": "2% faster starting attacks", "stat": "attack_speed", "value": 0.02, "cost": 3, "max_level": 5},
	{"id": "luck", "name": "Fortune Sensor", "description": "+0.25 starting luck", "stat": "luck", "value": 0.25, "cost": 4, "max_level": 5},
]


# finds an entry in a catalog by its id
static func find_entry(entries: Array, entry_id: String) -> Dictionary:
	for entry in entries:
		if entry["id"] == entry_id:
			return entry
	return {}


# returns a shuffled set of entries without repeating the same option
static func pick_options(entries: Array, count: int, excluded: Array[String] = []) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for entry in entries:
		if not excluded.has(str(entry["id"])):
			pool.append(entry)
	pool.shuffle()
	var chosen: Array[Dictionary] = []
	for index in range(mini(count, pool.size())):
		chosen.append(pool[index])
	return chosen


# increases drop chances with luck while keeping the result below certainty
static func chance_with_luck(base_chance: float, luck: float) -> float:
	var attempts := 1.0 + maxf(0.0, luck) * 0.12
	return clampf(1.0 - pow(1.0 - clampf(base_chance, 0.0, 1.0), attempts), 0.0, 1.0)


# rolls rarity independently for each selected reward option
static func roll_rarity(luck: float) -> String:
	var weights: Array[float] = []
	var total := 0.0
	for index in range(RARITIES.size()):
		var entry: Dictionary = RARITIES[index]
		var modifier := 1.0 + maxf(0.0, luck) * 0.08 * float(index)
		var weight: float = float(entry["weight"]) * modifier
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for index in range(RARITIES.size()):
		roll -= weights[index]
		if roll < 0.0:
			return str(RARITIES[index]["id"])
	return "legendary"


# returns the stat or relic multiplier assigned to a rarity
static func rarity_scale(rarity_id: String, kind: String = "upgrade") -> float:
	var entry := find_entry(RARITIES, rarity_id)
	if entry.is_empty():
		return 1.0
	return float(entry["relic_scale"] if kind == "relic" else entry["upgrade_scale"])


# returns a readable color for each rarity in menus and pickups
static func rarity_color(rarity_id: String) -> Color:
	match rarity_id:
		"uncommon":
			return Color(0.44, 0.9, 0.55)
		"rare":
			return Color(0.44, 0.7, 1.0)
		"legendary":
			return Color(1.0, 0.75, 0.3)
	return Color(0.85, 0.88, 0.94)
