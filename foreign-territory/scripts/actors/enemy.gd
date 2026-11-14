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
var armor_component: ArmorComponent
var starts_armored: bool = false
var _burn_remaining: float = 0.0
var _burn_dps: float = 0.0
var _burn_tick_timer: float = 0.5
var player: PlayerController
var _attack_timer: float = 1.0
var _crit_flash_time: float = 0.0


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
	armor_component = ArmorComponent.new()
	add_child(armor_component)
	if starts_armored:
		var armor_amount := start_health * (0.8 if tier == "normal" else 0.5)
		armor_component.setup(armor_amount)
	armor_component.changed.connect(queue_redraw)


# uses simple placeholder AI until the enemy programmer replaces it
func _physics_process(delta: float) -> void:
	_crit_flash_time = maxf(0.0, _crit_flash_time - delta)
	_tick_burn(delta)
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
	if armor_component != null and armor_component.armor > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 32, Color(0.35, 0.78, 1.0), 4.0)
	if _crit_flash_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 32, Color(1.0, 0.83, 0.25), 4.0)
	draw_circle(Vector2(0.0, -4.0), 4.0, Color(0.22, 0.1, 0.2))
	if armor_component != null and armor_component.armor > 0.0:
		var armor_ratio := armor_component.armor / armor_component.max_armor
		draw_rect(Rect2(-22.0, -radius - 23.0, 44.0 * armor_ratio, 5.0), Color(0.3, 0.8, 1.0))
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
func take_damage(amount: float, is_critical: bool = false, attacker: PlayerController = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	var remaining := amount
	if armor_component != null:
		remaining = armor_component.absorb_damage(amount)
	_show_damage_feedback(remaining, is_critical)
	health_component.take_damage(remaining)
	if is_alive() and attacker != null and attacker.relic_controller != null:
		attacker.relic_controller.on_enemy_hit(self)


# applies or refreshes a burn without making its ticks reapply the effect
func apply_burn(damage_per_second: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, damage_per_second)
	_burn_remaining = maxf(_burn_remaining, duration)


# applies periodic burning damage while the effect lasts
func _tick_burn(delta: float) -> void:
	if _burn_remaining <= 0.0 or not is_alive():
		return
	_burn_remaining = maxf(0.0, _burn_remaining - delta)
	_burn_tick_timer -= delta
	if _burn_tick_timer <= 0.0:
		take_damage(_burn_dps * 0.5)
		_burn_tick_timer += 0.5
	if _burn_remaining <= 0.0:
		_burn_dps = 0.0


# returns reduced stagger strength while the enemy still has armor
func get_stagger_multiplier() -> float:
	return armor_component.get_stagger_multiplier() if armor_component != null else 1.0


# displays floating damage text and a brief flash for critical hits
func _show_damage_feedback(amount: float, is_critical: bool) -> void:
	var label := Label.new()
	label.text = "CRIT! %.1f" % amount if is_critical else "%.1f" % amount
	var color := Color(1.0, 0.77, 0.2) if is_critical else Color(0.95, 0.97, 1.0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.08))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 26 if is_critical else 17)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-34.0 if is_critical else -10.0, -52.0)
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -42.0), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
	if is_critical:
		_crit_flash_time = 0.2
		queue_redraw()


# checks whether the enemy can still be targeted
func is_alive() -> bool:
	return health_component != null and health_component.health > 0.0


# reports the enemy's reward values and removes it from the level
func _on_died() -> void:
	remove_from_group("enemies")
	defeated.emit(self, xp_reward, tier)
	queue_free()
