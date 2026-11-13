extends Node
class_name HealthComponent

signal changed
signal died

var max_health: float = 1.0
var health: float = 1.0
var shield_capacity: float = 0.0
var shield: float = 0.0
var temporary_shield: float = 0.0
var shield_regen: float = 0.0
var regen_delay: float = 3.0
var _time_since_hit: float = 0.0
var _temporary_timer: float = 0.0
var _dead: bool = false


# regenerates regular shield and expires temporary dash shield
func _process(delta: float) -> void:
	if _dead:
		return
	_time_since_hit += delta
	if _temporary_timer > 0.0:
		_temporary_timer -= delta
		if _temporary_timer <= 0.0:
			temporary_shield = 0.0
			changed.emit()
	if shield < shield_capacity and _time_since_hit >= regen_delay:
		shield = minf(shield_capacity, shield + shield_regen * delta)
		changed.emit()


# configures full health when a new character is created
func setup(starting_health: float) -> void:
	max_health = maxf(1.0, starting_health)
	health = max_health
	shield = 0.0
	temporary_shield = 0.0
	_dead = false
	changed.emit()


# applies damage to temporary shield, regular shield, and then health
func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	_time_since_hit = 0.0
	var remainder := amount
	var temporary_absorb := minf(temporary_shield, remainder)
	temporary_shield -= temporary_absorb
	remainder -= temporary_absorb
	var shield_absorb := minf(shield, remainder)
	shield -= shield_absorb
	remainder -= shield_absorb
	health = maxf(0.0, health - remainder)
	changed.emit()
	if health <= 0.0:
		_dead = true
		died.emit()


# restores health without going above the current maximum
func heal(amount: float) -> void:
	health = minf(max_health, health + maxf(0.0, amount))
	changed.emit()


# increases maximum health and also heals by that amount
func increase_max_health(amount: float) -> void:
	max_health += maxf(0.0, amount)
	heal(amount)


# adds regenerating shield capacity from upgrades
func add_shield_capacity(amount: float) -> void:
	shield_capacity += maxf(0.0, amount)
	shield_regen = 0.8 if shield_capacity > 0.0 else 0.0
	shield = minf(shield_capacity, shield + amount)
	changed.emit()


# grants a short-lived shield used by dash relics
func grant_temporary_shield(amount: float, duration: float = 2.0) -> void:
	temporary_shield = maxf(temporary_shield, amount)
	_temporary_timer = duration
	changed.emit()


# returns the combined amount of shield currently protecting the character
func total_shield() -> float:
	return shield + temporary_shield
