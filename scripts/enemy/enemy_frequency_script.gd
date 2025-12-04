# This script is used to determine the frequency of the enemy's audio anomoly.
extends CharacterBody3D
class_name Enemy

var frequency_hz: float = 0.0
var rng := RandomNumberGenerator.new()

# To Do: In the future we might want a spawner class where we can initialize enemy objects and call our ready functions.
func _ready() -> void:
    rng.randomize()
    roll_frequency()

func roll_frequency() -> void:
    var lo := 30.0
    var hi := 20000.0
    var t := rng.randf() # 0..1
    frequency_hz = lo * pow(hi / lo, t)

