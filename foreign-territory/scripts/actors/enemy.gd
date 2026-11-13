extends CharacterBody2D
class_name EnemyActor

signal defeated(enemy: EnemyActor, xp_reward: int, tier: String)

var tier: String = "normal"
var enemy_kind: String = "melee"
var floor_number: int = 1
var move_speed: float = 100.0
var contact_damage: float = 1.0
var xp_reward: int = 5
var health_component: HealthComponent
var player: PlayerController
var _attack_timer: float = 1.0


# configures the enemy type and difficulty before it enters the scene
func configure(kind: String, rank: String, floor_index: int, target: PlayerController) -> void:
	enemy_kind = kind
	tier = rank
	floor_number = floor_index
	player = target


# creates the enemy's health and collision setup
func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0 if tier == "normal" else (20.0 if tier == "elite" else 32.0)
	collision.shape = circle
	add_child(collision)
	var start_health := 10.0 + 4.0 * float(floor_number - 1)
	if tier == "elite":
		start_health *= 3.0
	elif tier == "boss":
		start_health *= 9.0
	move_speed = 110.0 if enemy_kind == "melee" else 85.0
	if tier == "boss":
		move_speed = 70.0
	xp_reward = 5 + floor_number * 2
	if tier == "elite":
		xp_reward *= 4
	elif tier == "boss":
		xp_reward *= 12
	health_component = HealthComponent.new()
	add_child(health_component)
	health_component.setup(start_health)
	health_component.changed.connect(queue_redraw)
	health_component.died.connect(_on_died)


# uses simple placeholder AI until the enemy programmer replaces it
func _physics_process(delta: float) -> void:
	if player == null or not player.is_alive() or not is_alive():
		velocity = Vector2.ZERO
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var desired_range := 215.0 if enemy_kind == "ranged" or tier == "boss" else 20.0
	velocity = to_player.normalized() * move_speed if distance > desired_range else Vector2.ZERO
	move_and_slide()
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		if enemy_kind == "ranged" or tier == "boss":
			if distance <= 370.0:
				_fire_projectile(to_player.normalized())
				_attack_timer = 1.7 if tier == "normal" else 1.1
		elif distance <= 35.0:
			player.take_damage(contact_damage)
			_attack_timer = 0.9
	queue_redraw()


# draws an enemy body and health bar with distinct elite and boss colors
func _draw() -> void:
	var color := Color(0.95, 0.45, 0.37)
	var radius := 14.0
	if enemy_kind == "ranged":
		color = Color(0.98, 0.72, 0.3)
	if tier == "elite":
		color = Color(0.78, 0.42, 0.95)
		radius = 20.0
	elif tier == "boss":
		color = Color(0.97, 0.25, 0.57)
		radius = 32.0
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(0.0, -4.0), 4.0, Color(0.22, 0.1, 0.2))
	if health_component != null and health_component.health < health_component.max_health:
		var ratio := health_component.health / health_component.max_health
		draw_rect(Rect2(-22.0, -radius - 14.0, 44.0, 5.0), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(-22.0, -radius - 14.0, 44.0 * ratio, 5.0), Color(0.45, 1.0, 0.53))


# creates a hostile projectile with the shared combat behavior
func _fire_projectile(direction: Vector2) -> void:
	var projectile := CombatProjectile.new()
	projectile.source = self
	projectile.hostile = true
	projectile.direction = direction
	projectile.speed = 255.0
	projectile.damage = 1.0 if tier == "normal" else 2.0
	get_parent().add_child(projectile)
	projectile.global_position = global_position + direction * 24.0


# accepts damage from weapons, relics, or environmental effects
func take_damage(amount: float) -> void:
	health_component.take_damage(amount)


# checks whether the enemy can still be targeted
func is_alive() -> bool:
	return health_component != null and health_component.health > 0.0


# reports the enemy's reward values and removes it from the level
func _on_died() -> void:
	remove_from_group("enemies")
	defeated.emit(self, xp_reward, tier)
	queue_free()
