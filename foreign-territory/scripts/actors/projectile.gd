extends Area2D
class_name CombatProjectile

var direction: Vector2 = Vector2.RIGHT
var speed: float = 470.0
var damage: float = 1.0
var hostile: bool = false
var critical_hit: bool = false
var source: Node2D
var lifetime: float = 3.0
var max_hits: int = 1
var _hit_targets: Array[int] = []


# creates the projectile collision area and hit callback
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 if hostile else 2
	monitoring = true
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0 if hostile else 6.0
	collision.shape = circle
	add_child(collision)
	body_entered.connect(_on_body_entered)
	queue_redraw()


# moves the projectile until it hits something or expires
func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


# draws a placeholder projectile without requiring an imported sprite
func _draw() -> void:
	var color := Color(1.0, 0.36, 0.26) if hostile else Color(0.42, 0.96, 1.0)
	if max_hits > 1:
		color = Color(1.0, 0.77, 0.35)
	draw_circle(Vector2.ZERO, 7.0, color)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)


# damages a valid target and removes the projectile
func _on_body_entered(body: Node2D) -> void:
	if body == source or not body.has_method("take_damage"):
		return
	if hostile and not body.is_in_group("player"):
		return
	if not hostile and not body.is_in_group("enemies"):
		return
	if _hit_targets.has(body.get_instance_id()):
		return
	_hit_targets.append(body.get_instance_id())
	if hostile:
		body.take_damage(damage)
	else:
		body.take_damage(damage, critical_hit, source as PlayerController)
	if _hit_targets.size() >= max_hits:
		queue_free()
