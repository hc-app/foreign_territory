extends Area2D
class_name RewardPickup

signal collected(pickup_kind: String, rarity: String)

var pickup_kind: String = "upgrade"
var rarity: String = "common"
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


# draws different colors and symbols for each reward type and rarity
func _draw() -> void:
	var color := GameCatalog.rarity_color(rarity)
	var center := Vector2(0.0, sin(_age * 3.0) * 3.0)
	draw_circle(center, 14.0, color)
	if pickup_kind == "relic":
		draw_arc(center, 10.0, 0.0, TAU, 24, Color(0.65, 0.25, 0.95), 3.0)
	else:
		draw_circle(center, 6.0, Color(0.1, 0.35, 0.55))
	draw_arc(center, 19.0, 0.0, TAU, 30, color.darkened(0.25), 2.0)


# sends the collected reward to the main gameplay controller
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(pickup_kind, rarity)
		queue_free()
