extends Node
class_name RelicController

var player: PlayerController
var relic_ids: Array[String] = []
var relic_levels: Dictionary = {}
var relic_rarities: Dictionary = {}
var relic_level_bonuses: Dictionary = {}
var _meteor_timer: float = 5.0
var _aura_timer: float = 0.6


# runs periodic relic effects independently of the basic attack
func _physics_process(delta: float) -> void:
	if player == null or not player.is_alive():
		return
	if relic_ids.has("meteor"):
		_meteor_timer -= delta
		if _meteor_timer <= 0.0:
			_spawn_meteor()
			_meteor_timer = maxf(1.4, 5.0 - float(get_level("meteor") - 1) * 0.45)
	if relic_ids.has("aura"):
		_aura_timer -= delta
		if _aura_timer <= 0.0:
			_tick_aura()
			_aura_timer = 0.6


# adds a new relic or levels up an owned relic without a slot limit
func add_relic(relic_id: String, rarity: String = "common") -> bool:
	if GameCatalog.find_entry(GameCatalog.RELICS, relic_id).is_empty():
		return false
	var previous_bonus := _extra_dash_bonus() if relic_id == "extra_dash" else 0
	if relic_ids.has(relic_id):
		if get_level(relic_id) >= GameCatalog.MAX_RELIC_LEVEL:
			return false
		relic_levels[relic_id] = get_level(relic_id) + 1
		relic_level_bonuses[relic_id] = float(relic_level_bonuses.get(relic_id, 0.0)) + 0.3 * GameCatalog.rarity_scale(rarity, "relic")
	else:
		relic_ids.append(relic_id)
		relic_levels[relic_id] = 1
		relic_rarities[relic_id] = rarity
		relic_level_bonuses[relic_id] = 0.0
	if relic_id == "extra_dash":
		var added_charges := _extra_dash_bonus() - previous_bonus
		player.max_dash_charges += added_charges
		player.dash_charges += added_charges
	player.queue_redraw()
	player.status_changed.emit()
	return true


# returns the current level of an owned relic
func get_level(relic_id: String) -> int:
	return int(relic_levels.get(relic_id, 0))


# returns the rarity assigned when a relic was first obtained
func get_rarity(relic_id: String) -> String:
	return str(relic_rarities.get(relic_id, "common"))


# scales an owned relic's effect by its initial rarity and level-up rarities
func get_power(relic_id: String) -> float:
	if not relic_ids.has(relic_id):
		return 0.0
	return GameCatalog.rarity_scale(get_rarity(relic_id), "relic") * (1.0 + float(relic_level_bonuses.get(relic_id, 0.0)))


# calculates additional dash charges granted by the reserve thruster
func _extra_dash_bonus() -> int:
	if not relic_ids.has("extra_dash"):
		return 0
	return mini(5, 1 + int(floor(maxf(0.0, get_power("extra_dash") - 1.0))))


# adds extra plasma shots whenever the basic attack fires
func on_attack_fired(target_position: Vector2) -> void:
	if not relic_ids.has("extra_shot"):
		return
	var additional := mini(5, 1 + int(floor(get_power("extra_shot") - 1.0)))
	for index in range(additional):
		var side := -1.0 if index % 2 == 0 else 1.0
		var angle := side * (0.2 + float(index / 2) * 0.13)
		player.basic_attack.fire_at(target_position, angle)


# applies relic effects that trigger on a successful dash
func on_dashed() -> void:
	if relic_ids.has("dash_shield"):
		player.health_component.grant_temporary_shield(2.0 * get_power("dash_shield"))


# calls down a meteor near a currently living enemy
func _spawn_meteor() -> void:
	var target := player.basic_attack.find_nearest_enemy()
	if target == null:
		return
	var meteor := MeteorStrike.new()
	meteor.player = player
	meteor.damage = player.attack_damage * (1.6 * get_power("meteor")) + 4.0
	meteor.radius = 78.0 + 10.0 * float(get_level("meteor") - 1)
	player.get_parent().add_child(meteor)
	meteor.global_position = target.global_position


# damages all enemies within the radiation field radius
func _tick_aura() -> void:
	var radius := 88.0 + 10.0 * float(get_level("aura") - 1)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive() and player.global_position.distance_to(enemy.global_position) <= radius:
			var hit := player.roll_attack_hit(player.attack_damage * 0.45 * get_power("aura"))
			enemy.take_damage(float(hit["damage"]), bool(hit["critical"]))
