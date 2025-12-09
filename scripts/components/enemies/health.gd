# # This script is used to manage the health of a base enemy.

# extends CharacterBody3D

# @export var max_health: int = 100
# @export var current_health: int = max_health

# func _ready():
#     current_health = max_health

# func take_damage(damage: int):
#     current_health -= damage
#     if current_health <= 0:
#         die()