extends Node2D
class_name RailgunBeam

const BEAM_DURATION = 0.42
const FADE_DURATION = 0.25
const HIT_RADIUS = 15.0

var direction: Vector2 = Vector2.RIGHT
var beam_length: float = 900.0
var _remaining: float = BEAM_DURATION


# holds the railgun beam briefly before fading it out
func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
		return
	modulate.a = clampf(_remaining / FADE_DURATION, 0.0, 1.0)


# draws a bright railgun core with a wider glow
func _draw() -> void:
	var finish := direction * beam_length
	draw_line(Vector2.ZERO, finish, Color(0.26, 0.65, 1.0, 0.22), 26.0, true)
	draw_line(Vector2.ZERO, finish, Color(0.43, 0.86, 1.0, 0.68), 11.0, true)
	draw_line(Vector2.ZERO, finish, Color(0.95, 1.0, 1.0), 3.5, true)
	draw_circle(Vector2.ZERO, 10.0, Color(0.7, 0.94, 1.0, 0.85))


# damages enemies along the full beam once, up to its piercing limit
func fire(attacker: PlayerController, damage: float, critical: bool, max_hits: int, priority_target: EnemyActor = null) -> void:
	var targets: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyActor
		if enemy == null or not enemy.is_alive():
			continue
		var offset := enemy.global_position - global_position
		var distance := offset.dot(direction)
		if distance < 0.0 or distance > beam_length:
			continue
		var lateral_distance := absf(offset.cross(direction))
		var radius := HIT_RADIUS
		if enemy.tier == "elite":
			radius += 6.0
		elif enemy.tier == "boss":
			radius += 18.0
		if lateral_distance <= radius:
			targets.append({"enemy": enemy, "distance": distance})
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["enemy"] == priority_target:
			return true
		if b["enemy"] == priority_target:
			return false
		return float(a["distance"]) < float(b["distance"])
	)
	for index in range(mini(max_hits, targets.size())):
		var enemy := targets[index]["enemy"] as EnemyActor
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.take_damage(damage, critical, attacker)
