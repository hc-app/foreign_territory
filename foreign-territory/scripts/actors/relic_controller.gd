extends Node
class_name RelicController

var player: PlayerController
var relic_ids: Array[String] = []
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
			_meteor_timer = 5.0
	if relic_ids.has("aura"):
		_aura_timer -= delta
		if _aura_timer <= 0.0:
			_tick_aura()
			_aura_timer = 0.6


# installs a new relic and applies its immediate effects
func add_relic(relic_id: String) -> bool:
	if relic_ids.has(relic_id):
		return false
	relic_ids.append(relic_id)
	if relic_id == "extra_dash":
		player.max_dash_charges += 1
		player.dash_charges += 1
	player.queue_redraw()
	return true


# adds a second plasma shot whenever the basic attack fires
func on_attack_fired(target_position: Vector2) -> void:
	if relic_ids.has("extra_shot"):
		player.basic_attack.fire_at(target_position, 0.24)


# applies relic effects that trigger on a successful dash
func on_dashed() -> void:
	if relic_ids.has("dash_shield"):
		player.health_component.grant_temporary_shield(2.0)


# calls down a meteor near a currently living enemy
func _spawn_meteor() -> void:
	var target := player.basic_attack.find_nearest_enemy()
	if target == null:
		return
	var meteor := MeteorStrike.new()
	meteor.damage = player.attack_damage * 1.6 + 4.0
	player.get_parent().add_child(meteor)
	meteor.global_position = target.global_position


# damages all enemies within the radiation field radius
func _tick_aura() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive() and player.global_position.distance_to(enemy.global_position) <= 88.0:
			enemy.take_damage(player.attack_damage * 0.45)
