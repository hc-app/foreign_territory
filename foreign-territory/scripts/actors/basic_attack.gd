extends Node
class_name BasicAttack

signal attack_fired(target_position: Vector2)

var player: PlayerController
var _attack_timer: float = 0.0


# fires at the nearest enemy whenever the automatic attack is ready
func _physics_process(delta: float) -> void:
	if player == null or not player.is_alive():
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	var target := find_nearest_enemy()
	if target == null:
		_attack_timer = 0.1
		return
	fire_at(target.global_position)
	attack_fired.emit(target.global_position)
	_attack_timer = player.attack_interval


# finds the closest living enemy in the current scene
func find_nearest_enemy() -> EnemyActor:
	var targets := get_nearest_enemies()
	return targets[0] if not targets.is_empty() else null


# returns living enemies sorted from nearest to farthest
func get_nearest_enemies() -> Array[EnemyActor]:
	var ordered: Array[EnemyActor] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive():
			ordered.append(enemy)
	ordered.sort_custom(func(a: EnemyActor, b: EnemyActor) -> bool:
		return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position)
	)
	return ordered


# spawns a plasma ball toward a chosen enemy without an angle offset
func fire_at(target_position: Vector2) -> void:
	var aim := (target_position - player.global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var projectile := CombatProjectile.new()
	projectile.source = player
	projectile.direction = aim
	var hit := player.roll_attack_hit(player.attack_damage)
	projectile.damage = float(hit["damage"])
	projectile.critical_hit = bool(hit["critical"])
	player.get_parent().add_child(projectile)
	projectile.global_position = player.global_position + projectile.direction * 22.0
