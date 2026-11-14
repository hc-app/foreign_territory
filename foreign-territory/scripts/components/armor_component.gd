extends Node
class_name ArmorComponent

signal changed
signal broken

var max_armor: float = 0.0
var armor: float = 0.0
var damage_reduction: float = 0.6
var stagger_multiplier: float = 0.35


# configures a temporary armor layer for the owning enemy
func setup(amount: float, reduction: float = 0.6) -> void:
	max_armor = maxf(0.0, amount)
	armor = max_armor
	damage_reduction = clampf(reduction, 0.0, 1.0)
	changed.emit()


# spends armor durability and returns the damage that reaches health
func absorb_damage(incoming: float) -> float:
	if armor <= 0.0:
		return incoming
	var prevented := minf(armor, incoming * damage_reduction)
	armor -= prevented
	changed.emit()
	if armor <= 0.0:
		broken.emit()
	return incoming - prevented


# reports the stagger strength while armor is still intact
func get_stagger_multiplier() -> float:
	return stagger_multiplier if armor > 0.0 else 1.0
