extends Area2D
class_name RewardPickup

signal collected(pickup_kind: String)

var pickup_kind: String = "upgrade"
var _age: float = 0.0


# enables collection when the player touches the reward
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 17.0
	collision.shape = circle
	add_child(collision)
	body_entered.connect(_on_body_entered)


# animates the pickup and draws its placeholder marker
func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


# draws different colors and symbols for each reward type
func _draw() -> void:
	var color := Color(0.3, 0.85, 1.0)
	if pickup_kind == "relic":
		color = Color(0.87, 0.44, 1.0)
	var center := Vector2(0.0, sin(_age * 3.0) * 3.0)
	draw_circle(center, 14.0, color)
	draw_arc(center, 19.0, 0.0, TAU, 30, color.darkened(0.25), 2.0)


# sends the collected reward to the main gameplay controller
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(pickup_kind)
		queue_free()
