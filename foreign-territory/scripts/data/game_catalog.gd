extends RefCounted
class_name GameCatalog

# all upgrades names and values are tentative/temporary for now. will require balancing, additions, and possible new names/descriptions
const UPGRADES = [
	{"id": "damage", "name": "Plasma Amplifier", "description": "+2 attack damage", "stat": "damage", "value": 2.0},
	{"id": "speed", "name": "Thrusters", "description": "+25 movement speed", "stat": "move_speed", "value": 25.0},
	{"id": "health", "name": "Reinforced Hull", "description": "+2 maximum health and heal 2", "stat": "max_health", "value": 2.0},
	{"id": "attack_speed", "name": "Rapid Capacitor", "description": "10% faster automatic attacks", "stat": "attack_speed", "value": 0.10},
	{"id": "shield", "name": "Shield Battery", "description": "+2 regenerating shield capacity", "stat": "shield", "value": 2.0},
]

const RELICS = [
	{"id": "meteor", "name": "Orbital Meteor", "description": "Call down an area attack every 5 seconds"},
	{"id": "extra_shot", "name": "Twin Plasma", "description": "Fire an additional angled plasma ball"},
	{"id": "aura", "name": "Radiation Field", "description": "Damage nearby enemies every 0.6 seconds"},
	{"id": "dash_shield", "name": "Reactive Barrier", "description": "Gain 2 temporary shield when dashing"},
	{"id": "extra_dash", "name": "Reserve Thruster", "description": "Gain a second dash charge"},
]

const META_UPGRADES = [
	{"id": "damage", "name": "Weapon Calibration", "description": "+1 starting damage", "stat": "damage", "value": 1.0, "cost": 3, "max_level": 5},
	{"id": "health", "name": "Hull Reinforcement", "description": "+1 starting health", "stat": "max_health", "value": 1.0, "cost": 3, "max_level": 6},
	{"id": "speed", "name": "Engine Tuning", "description": "+5 starting move speed", "stat": "move_speed", "value": 5.0, "cost": 2, "max_level": 5},
	{"id": "attack_speed", "name": "Fire Control", "description": "2% faster starting attacks", "stat": "attack_speed", "value": 0.02, "cost": 3, "max_level": 5},
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
		if not excluded.has(entry["id"]):
			pool.append(entry)
	pool.shuffle()
	var chosen: Array[Dictionary] = []
	for index in range(mini(count, pool.size())):
		chosen.append(pool[index])
	return chosen
