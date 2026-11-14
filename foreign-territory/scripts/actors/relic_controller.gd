extends Node2D
class_name RelicController

var player: PlayerController
var relic_ids: Array[String] = []
var relic_levels: Dictionary = {}
var relic_rarities: Dictionary = {}
var _meteor_timer: float = 5.0
var _aura_timer: float = 0.6
var _railgun_timer: float = 3.0
var _porcupine_cooldown: float = 0.0
var _metal_timer: float = 0.2
var _orbit_angle: float = 0.0


# runs periodic relic effects independently of the basic attack
func _physics_process(delta: float) -> void:
	if player == null or not player.is_alive():
		return
	_porcupine_cooldown = maxf(0.0, _porcupine_cooldown - delta)
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
	if relic_ids.has("piercing_shot"):
		_railgun_timer -= delta
		if _railgun_timer <= 0.0:
			_fire_piercing_shot()
			_railgun_timer = maxf(1.2, 3.0 - 0.3 * float(get_level("piercing_shot") - 1))
	if relic_ids.has("metallokinesis"):
		_orbit_angle += delta * 2.2
		_metal_timer -= delta
		if _metal_timer <= 0.0:
			_tick_metal()
			_metal_timer = 0.2
		queue_redraw()


# draws rotating scrap metal pieces around the player
func _draw() -> void:
	if not relic_ids.has("metallokinesis"):
		return
	for index in range(_metal_count()):
		var offset := _metal_offset(index)
		draw_circle(offset, 10.0, Color(0.76, 0.82, 0.88))
		draw_circle(offset, 4.0, Color(0.28, 0.39, 0.47))


# adds a new fixed-rarity relic or increases the level of an owned relic
func add_relic(relic_id: String) -> bool:
	var entry := GameCatalog.find_entry(GameCatalog.RELICS, relic_id)
	if entry.is_empty():
		return false
	var previous_bonus := _extra_dash_bonus() if relic_id == "extra_dash" else 0
	if relic_ids.has(relic_id):
		if get_level(relic_id) >= GameCatalog.MAX_RELIC_LEVEL:
			return false
		relic_levels[relic_id] = get_level(relic_id) + 1
	else:
		relic_ids.append(relic_id)
		relic_levels[relic_id] = 1
		relic_rarities[relic_id] = str(entry["rarity"])
	if relic_id == "extra_dash":
		var added_charges := _extra_dash_bonus() - previous_bonus
		player.max_dash_charges += added_charges
		player.dash_charges += added_charges
	queue_redraw()
	player.status_changed.emit()
	return true


# returns the current level of an owned relic
func get_level(relic_id: String) -> int:
	return int(relic_levels.get(relic_id, 0))


# returns the fixed rarity assigned to a relic's effect
func get_rarity(relic_id: String) -> String:
	return str(relic_rarities.get(relic_id, "common"))


# scales an owned relic's effect according to its level
func get_power(relic_id: String) -> float:
	if not relic_ids.has(relic_id):
		return 0.0
	return 1.0 + 0.3 * float(get_level(relic_id) - 1)


# calculates additional dash charges granted by the reserve thruster
func _extra_dash_bonus() -> int:
	if not relic_ids.has("extra_dash"):
		return 0
	return 1 + int(floor(float(get_level("extra_dash") - 1) / 2.0))


# fires extra shots at the next closest enemy instead of angling off-target
func on_attack_fired(_target_position: Vector2) -> void:
	if not relic_ids.has("extra_shot"):
		return
	var targets := player.basic_attack.get_nearest_enemies()
	if targets.is_empty():
		return
	var additional := mini(5, get_level("extra_shot"))
	for index in range(additional):
		var target := targets[mini(index + 1, targets.size() - 1)]
		player.basic_attack.fire_at(target.global_position)


# applies relic effects that trigger on a successful dash
func on_dashed() -> void:
	if relic_ids.has("dash_shield"):
		player.health_component.grant_temporary_shield(2.0 * get_power("dash_shield"))


# applies burning damage when a player's hit reaches an enemy
func on_enemy_hit(enemy: EnemyActor) -> void:
	if relic_ids.has("burn") and enemy.is_alive():
		enemy.apply_burn(1.5 * get_power("burn"), 3.0 + float(get_level("burn") - 1) * 0.5)


# releases porcupine spikes after an accepted hit when the cooldown is ready
func on_damaged() -> void:
	if not relic_ids.has("porcupine") or _porcupine_cooldown > 0.0:
		return
	_porcupine_cooldown = 5.0
	var count := 10 + (get_level("porcupine") - 1) * 2
	var scene_root := player.get_parent()
	for index in range(count):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(count))
		var spike := CombatProjectile.new()
		spike.source = player
		spike.direction = direction
		spike.speed = 400.0
		spike.lifetime = 1.1
		var hit := player.roll_attack_hit(player.attack_damage * 0.7 * get_power("porcupine"))
		spike.damage = float(hit["damage"])
		spike.critical_hit = bool(hit["critical"])
		spike.position = scene_root.to_local(player.global_position + direction * 24.0)
		scene_root.call_deferred("add_child", spike)


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
			enemy.take_damage(float(hit["damage"]), bool(hit["critical"]), player)


# fires a piercing railgun shot at the enemy with the highest maximum health
func _fire_piercing_shot() -> void:
	var target: EnemyActor
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive():
			if target == null or enemy.health_component.max_health > target.health_component.max_health:
				target = enemy
	if target == null:
		return
	var direction := (target.global_position - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var railgun := CombatProjectile.new()
	railgun.source = player
	railgun.direction = direction
	railgun.speed = 650.0
	railgun.max_hits = 2 + int(floor(float(get_level("piercing_shot")) / 2.0))
	var hit := player.roll_attack_hit(player.attack_damage * 1.6 * get_power("piercing_shot"), 0.5)
	railgun.damage = float(hit["damage"])
	railgun.critical_hit = bool(hit["critical"])
	player.get_parent().add_child(railgun)
	railgun.global_position = player.global_position + direction * 22.0


# returns the number of orbiting metal pieces at the current relic level
func _metal_count() -> int:
	return 2 + get_level("metallokinesis")


# positions each metal piece evenly around the player's orbit
func _metal_offset(index: int) -> Vector2:
	var count := _metal_count()
	var radius := 75.0 + float(get_level("metallokinesis") - 1) * 5.0
	return Vector2.RIGHT.rotated(_orbit_angle + TAU * float(index) / float(count)) * radius


# damages enemies touched by rotating scrap metal
func _tick_metal() -> void:
	for index in range(_metal_count()):
		var point := player.global_position + _metal_offset(index)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as EnemyActor
			if enemy != null and enemy.is_alive() and point.distance_to(enemy.global_position) <= 25.0:
				var hit := player.roll_attack_hit(player.attack_damage * 0.4 * get_power("metallokinesis"))
				enemy.take_damage(float(hit["damage"]), bool(hit["critical"]), player)
