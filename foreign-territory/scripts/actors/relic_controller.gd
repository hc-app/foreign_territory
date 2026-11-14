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
var _chain_cooldown: float = 0.0
var _gravity_timer: float = 7.0
var _gravity_duration: float = 0.0
var _gravity_position: Vector2 = Vector2.ZERO


# runs periodic relic effects independently of the basic attack
func _physics_process(delta: float) -> void:
	if player == null or not player.is_alive():
		return
	_porcupine_cooldown = maxf(0.0, _porcupine_cooldown - delta)
	_chain_cooldown = maxf(0.0, _chain_cooldown - delta)
	if relic_ids.has("gravity_well"):
		_gravity_timer -= delta
		if _gravity_timer <= 0.0:
			_start_gravity_well()
			_gravity_timer = maxf(3.5, 7.0 - 0.6 * float(get_level("gravity_well") - 1))
		if _gravity_duration > 0.0:
			_tick_gravity_well(delta)
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


# draws orbiting scrap metal and the active gravity field
func _draw() -> void:
	if relic_ids.has("metallokinesis"):
		for index in range(_metal_count()):
			var offset := _metal_offset(index)
			draw_circle(offset, 10.0, Color(0.76, 0.82, 0.88))
			draw_circle(offset, 4.0, Color(0.28, 0.39, 0.47))
	if _gravity_duration > 0.0:
		var radius := 140.0 * player.area_radius * get_power("gravity_well")
		draw_circle(to_local(_gravity_position), radius, Color(0.5, 0.35, 1.0, 0.08))
		draw_arc(to_local(_gravity_position), radius, 0.0, TAU, 48, Color(0.68, 0.49, 1.0, 0.65), 3.0)


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


# applies burn and occasionally chains lightning from a successful hit
func on_enemy_hit(enemy: EnemyActor) -> void:
	if relic_ids.has("burn") and enemy.is_alive():
		enemy.apply_burn(1.5 * get_power("burn") * player.status_potency, (3.0 + float(get_level("burn") - 1) * 0.5) * player.status_potency)
	if relic_ids.has("chain_lightning") and _chain_cooldown <= 0.0:
		var chance := minf(0.75, 0.22 + 0.08 * float(get_level("chain_lightning") - 1))
		if randf() < chance:
			_chain_cooldown = 0.6
			_chain_lightning(enemy)


# returns the amount of extra damage attacks apply to an armor layer
func get_armor_damage_multiplier() -> float:
	if not relic_ids.has("armor_breaker"):
		return 1.0
	return 2.5 + 0.6 * float(get_level("armor_breaker") - 1)


# heals the player after an enemy wave is cleared
func on_room_cleared() -> void:
	if relic_ids.has("emergency_repairs"):
		player.health_component.heal(1.0 + 0.7 * float(get_level("emergency_repairs") - 1))


# returns how close a pickup can be before it is collected automatically
func get_pickup_radius() -> float:
	if not relic_ids.has("scrap_collector"):
		return 17.0
	return 24.0 + 40.0 * get_power("scrap_collector")


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
	meteor.radius = (78.0 + 10.0 * float(get_level("meteor") - 1)) * player.area_radius
	player.get_parent().add_child(meteor)
	meteor.global_position = target.global_position


# damages all enemies within the radiation field radius
func _tick_aura() -> void:
	var radius := (88.0 + 10.0 * float(get_level("aura") - 1)) * player.area_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive() and player.global_position.distance_to(enemy.global_position) <= radius:
			var hit := player.roll_attack_hit(player.attack_damage * 0.45 * get_power("aura"))
			enemy.take_damage(float(hit["damage"]), bool(hit["critical"]), player)


# fires a lingering railgun beam through the highest-health target and beyond
func _fire_piercing_shot() -> void:
	var target: EnemyActor
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive():
			if target == null or enemy.health_component.max_health > target.health_component.max_health:
				target = enemy
	if target == null:
		return
	var to_target := target.global_position - player.global_position
	var direction := to_target.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var beam := RailgunBeam.new()
	beam.z_index = 12
	beam.direction = direction
	beam.beam_length = maxf(900.0, to_target.length() + 450.0)
	player.get_parent().add_child(beam)
	beam.global_position = player.global_position
	var hit := player.roll_attack_hit(player.attack_damage * 1.6 * get_power("piercing_shot"), 0.5)
	var maximum_hits := 2 + int(floor(float(get_level("piercing_shot")) / 2.0))
	beam.fire(player, float(hit["damage"]), bool(hit["critical"]), maximum_hits, target)

# returns the number of orbiting metal pieces at the current relic level
func _metal_count() -> int:
	return 2 + get_level("metallokinesis")


# positions each metal piece evenly around the player's orbit
func _metal_offset(index: int) -> Vector2:
	var count := _metal_count()
	var radius := (75.0 + float(get_level("metallokinesis") - 1) * 5.0) * player.area_radius
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


# jumps lightning between nearby enemies without triggering another chain
func _chain_lightning(first_enemy: EnemyActor) -> void:
	var source_position := first_enemy.global_position
	var hit_ids: Array[int] = [first_enemy.get_instance_id()]
	var jumps := 1 + int(floor(float(get_level("chain_lightning") - 1) / 2.0))
	for _jump in range(jumps):
		var target: EnemyActor
		var best_distance := pow(195.0 * player.area_radius, 2.0)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as EnemyActor
			if enemy == null or not enemy.is_alive() or hit_ids.has(enemy.get_instance_id()):
				continue
			var distance := source_position.distance_squared_to(enemy.global_position)
			if distance < best_distance:
				best_distance = distance
				target = enemy
		if target == null:
			break
		_draw_lightning(source_position, target.global_position)
		var hit := player.roll_attack_hit(player.attack_damage * 0.5 * get_power("chain_lightning"))
		target.take_damage(float(hit["damage"]), bool(hit["critical"]), player, false)
		hit_ids.append(target.get_instance_id())
		source_position = target.global_position


# briefly draws a lightning arc connecting two combat targets
func _draw_lightning(start: Vector2, finish: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.5, 0.86, 1.0)
	player.get_parent().add_child(line)
	line.add_point(line.to_local(start))
	line.add_point(line.to_local(finish))
	var tween := get_tree().create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)


# places a gravity field near the closest current enemy
func _start_gravity_well() -> void:
	var target := player.basic_attack.find_nearest_enemy()
	if target == null:
		return
	_gravity_position = target.global_position
	_gravity_duration = 2.0 + 0.25 * float(get_level("gravity_well") - 1)
	queue_redraw()


# applies temporary pulling force to enemies inside the gravity field
func _tick_gravity_well(delta: float) -> void:
	_gravity_duration = maxf(0.0, _gravity_duration - delta)
	var radius := 140.0 * player.area_radius * get_power("gravity_well")
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive() and enemy.global_position.distance_to(_gravity_position) < radius:
			enemy.apply_gravity_pull(_gravity_position, 180.0 * get_power("gravity_well") * player.status_potency, 0.15)
	queue_redraw()
