# Component for handling collisions with enemies
# Can be attached to any CharacterBody3D that needs enemy collision handling
class_name EnemyCollisionHandler
extends RefCounted

# Collision constants
const ENEMY_PUSH_FORCE := 5.0  # Force applied when pushing enemies

func handle_collisions(character: CharacterBody3D) -> void:
	# Check for collisions with enemies and push them back.
	var collision_count: int = character.get_slide_collision_count()
	for i: int in range(collision_count):
		var collision: KinematicCollision3D = character.get_slide_collision(i)
		var collider: Object = collision.get_collider()
		
		if not collider is Node:
			continue
		
		var node: Node = collider as Node
        # We assigned the enemies to the "enemies" group in the Enemy scene
		if not node.is_in_group("enemies"):
			continue
		
		# Push the enemy back
		# TODO: Re-implement push away functionality when needed

