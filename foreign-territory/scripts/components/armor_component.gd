extends Node
class_name ArmorComponent

signal changed
signal broken

var max_armor: float = 0.0
var armor: float = 0.0
var damage_reduction: float = 0.9
var stagger_multiplier: float = 0.35


# configures a temporary armor layer for the owning enemy
func setup(amount: float, reduction: float = 0.9) -> void:
	max_armor = maxf(0.0, amount)
	armor = max_armor
	damage_reduction = clampf(reduction, 0.0, 1.0)
	changed.emit()


# spends armor durability while reducing health damage until armor breaks
func absorb_damage(incoming: float, armor_damage_multiplier: float = 1.0) -> float:
	if armor <= 0.0:
		return incoming
	var health_damage := incoming * (1.0 - damage_reduction)
	armor = maxf(0.0, armor - incoming * maxf(0.0, armor_damage_multiplier))
	changed.emit()
	if armor <= 0.0:
		broken.emit()
	return health_damage


# reports the stagger strength while armor is still intact
func get_stagger_multiplier() -> float:
	return stagger_multiplier if armor > 0.0 else 1.0
