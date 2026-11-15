extends CharacterBody2D
class_name PlayerController

signal status_changed
signal died

const BASE_HEALTH = 8.0
const BASE_DAMAGE = 3.0
const BASE_SPEED = 230.0
const BASE_ATTACK_INTERVAL = 0.5
const BASE_CRIT_CHANCE = 0.05
const BASE_CRIT_DAMAGE = 0.5

var attack_damage: float = BASE_DAMAGE
var move_speed: float = BASE_SPEED
var attack_interval: float = BASE_ATTACK_INTERVAL
var crit_chance: float = BASE_CRIT_CHANCE
var crit_damage: float = BASE_CRIT_DAMAGE
var luck: float = 0.0
var area_radius: float = 1.0
var status_potency: float = 1.0
var dash_speed: float = 680.0
var dash_duration: float = 0.18
var dash_cooldown: float = 1.5
var max_dash_charges: int = 1
var dash_charges: int = 1
var arena_bounds: Rect2 = Rect2(-610, -325, 1220, 650)

var health_component: HealthComponent
var basic_attack: BasicAttack
var relic_controller: RelicController
var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_time_left: float = 0.0
var _dash_recharge_time: float = 0.0
var _invulnerable_time: float = 0.0


# sets up movement collision, combat, and the player's permanent bonuses
func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 4
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	collision.shape = circle
	add_child(collision)

	health_component = HealthComponent.new()
	add_child(health_component)
	health_component.setup(BASE_HEALTH)
	health_component.changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	basic_attack = BasicAttack.new()
	basic_attack.player = self
	add_child(basic_attack)
	relic_controller = RelicController.new()
	relic_controller.player = self
	add_child(relic_controller)
	basic_attack.attack_fired.connect(relic_controller.on_attack_fired)
	_apply_meta_upgrades()


# moves the player and manages dash charges and immunity frames
func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_invulnerable_time = maxf(0.0, _invulnerable_time - delta)
	if dash_charges < max_dash_charges:
		_dash_recharge_time -= delta
		if _dash_recharge_time <= 0.0:
			dash_charges += 1
			_dash_recharge_time = dash_cooldown
			status_changed.emit()
	if Input.is_action_just_pressed("dash"):
		_try_dash()
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_direction * dash_speed
	else:
		velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * move_speed
	move_and_slide()
	position = position.clamp(arena_bounds.position, arena_bounds.end)
	queue_redraw()


# draws the player, equipped aura, and shield strength around the body
func _draw() -> void:
	if relic_controller != null and relic_controller.relic_ids.has("aura"):
		var radius := (88.0 + 10.0 * float(relic_controller.get_level("aura") - 1)) * area_radius
		draw_circle(Vector2.ZERO, radius, Color(0.35, 0.95, 0.4, 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.5, 1.0, 0.6, 0.38), 2.0)
	if health_component != null:
		var capacity := health_component.shield_capacity
		if capacity > 0.0 and health_component.shield > 0.0:
			var ratio := clampf(health_component.shield / capacity, 0.0, 1.0)
			draw_circle(Vector2.ZERO, 24.0, Color(0.27, 0.65, 1.0, 0.12 * ratio))
			draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 48, Color(0.28, 0.48, 0.66, 0.32), 2.0)
			draw_arc(Vector2.ZERO, 24.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 48, Color(0.37, 0.82, 1.0), 3.5)
		if health_component.temporary_shield > 0.0:
			draw_circle(Vector2.ZERO, 29.0, Color(0.44, 1.0, 0.87, 0.06))
			draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 48, Color(0.42, 1.0, 0.91), 2.8)
	var color := Color(0.52, 0.98, 0.67)
	if _invulnerable_time > 0.0:
		color = Color(0.67, 0.85, 1.0)
	draw_circle(Vector2.ZERO, 16.0, color)
	draw_circle(Vector2(-6, -4), 3.0, Color(0.12, 0.18, 0.25))
	draw_circle(Vector2(6, -4), 3.0, Color(0.12, 0.18, 0.25))


# tries to spend one dash charge and trigger dash relics
func _try_dash() -> void:
	if dash_charges <= 0 or _dash_time_left > 0.0:
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_direction = input_direction if input_direction != Vector2.ZERO else _dash_direction
	var was_full := dash_charges == max_dash_charges
	dash_charges -= 1
	if was_full:
		_dash_recharge_time = dash_cooldown
	_dash_time_left = dash_duration
	_invulnerable_time = dash_duration + 0.08
	relic_controller.on_dashed()
	status_changed.emit()


# reduces player health unless a dash or recent hit prevents damage
func take_damage(amount: float) -> void:
	if _invulnerable_time > 0.0:
		return
	health_component.take_damage(amount)
	_invulnerable_time = 0.45
	relic_controller.on_damaged()
	status_changed.emit()


# applies an in-run or permanent stat modifier by its stat id
func apply_stat_upgrade(stat: String, value: float) -> void:
	match stat:
		"damage":
			attack_damage += value
		"move_speed":
			move_speed += value
		"max_health":
			health_component.increase_max_health(value)
		"attack_speed":
			attack_interval = maxf(0.15, attack_interval * (1.0 - value))
		"shield":
			health_component.add_shield_capacity(value)
		"crit_chance":
			var total_chance := crit_chance + maxf(0.0, value)
			crit_damage += maxf(0.0, total_chance - 1.0) * 1.5
			crit_chance = minf(1.0, total_chance)
		"crit_damage":
			crit_damage += value
		"luck":
			luck += value
		"dash_recharge":
			var old_cooldown := dash_cooldown
			dash_cooldown = maxf(0.35, dash_cooldown * (1.0 - value))
			if dash_charges < max_dash_charges:
				_dash_recharge_time *= dash_cooldown / old_cooldown
		"area_radius":
			area_radius += maxf(0.0, value)
		"status_potency":
			status_potency += maxf(0.0, value)
	status_changed.emit()


# rolls critical damage and converts excess special crit chance into extra crit damage
func roll_attack_hit(base_damage: float, bonus_crit_chance: float = 0.0) -> Dictionary:
	var chance := crit_chance + bonus_crit_chance
	var excess := maxf(0.0, chance - 1.0)
	var critical := randf() < minf(1.0, chance)
	var multiplier := 1.0 + crit_damage + excess * 1.5
	return {"damage": base_damage * multiplier if critical else base_damage, "critical": critical}


# returns the resulting damage of an attack without critical hit metadata
func roll_attack_damage(base_damage: float) -> float:
	return float(roll_attack_hit(base_damage)["damage"])


# returns progress toward the next recharged dash charge
func get_dash_recharge_ratio() -> float:
	if dash_charges >= max_dash_charges:
		return 1.0
	return clampf(1.0 - _dash_recharge_time / dash_cooldown, 0.0, 1.0)


# applies meta-upgrade levels once at the beginning of a run
func _apply_meta_upgrades() -> void:
	for entry in GameCatalog.META_UPGRADES:
		var times := GameData.get_level(entry["id"])
		for i in range(times):
			apply_stat_upgrade(entry["stat"], float(entry["value"]))


# reports whether the player can still fight
func is_alive() -> bool:
	return health_component != null and health_component.health > 0.0


# forwards changes to the user interface
func _on_health_changed() -> void:
	status_changed.emit()


# tells the game to end the run when player health reaches zero
func _on_died() -> void:
	died.emit()
