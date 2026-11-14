extends Node2D
class_name MeteorStrike

var radius: float = 78.0
var damage: float = 8.0
var player: PlayerController
var charge_time: float = 0.65
var _impact_time: float = 0.2
var _impacted: bool = false


# counts down the warning circle before dealing area damage
func _process(delta: float) -> void:
	if not _impacted:
		charge_time -= delta
		if charge_time <= 0.0:
			_impact()
	else:
		_impact_time -= delta
		if _impact_time <= 0.0:
			queue_free()
	queue_redraw()


# draws the area warning and the brief impact flash
func _draw() -> void:
	if _impacted:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.5, 0.15, 0.60))
	else:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.4, 0.15, 0.9), 4.0)
		draw_circle(Vector2.ZERO, radius * (1.0 - charge_time / 0.65), Color(1.0, 0.3, 0.15, 0.16))


# damages enemies standing inside the meteor area at impact
func _impact() -> void:
	_impacted = true
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy != null and enemy.is_alive() and global_position.distance_to(enemy.global_position) <= radius:
			if player != null:
				var hit := player.roll_attack_hit(damage)
				enemy.take_damage(float(hit["damage"]), bool(hit["critical"]))
			else:
				enemy.take_damage(damage)
