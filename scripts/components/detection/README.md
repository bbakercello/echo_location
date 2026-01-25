# Detection System

Cone-shaped object detection with target prioritization (Hades-style targeting).

## Files

| File | Purpose |
|------|---------|
| `cone_detector.gd` | Base detection - finds objects in cone |
| `enemy_detector.gd` | Enemy-specific wrapper |
| `target_prioritizer.gd` | Ranks targets, handles sticky targeting |
| `target_score.gd` | Score data structure (external use) |
| `detection_error.gd` | Custom error types |

## Architecture

```
┌─────────────────┐
│  ConeDetector   │  Finds all objects in cone (spatial + raycast)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│TargetPrioritizer│  Scores by distance/angle, prevents flickering
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Player Script  │  Queries best target, responds to signals
└─────────────────┘
```

## Usage

```gdscript
# Setup
var detector = EnemyDetector.new()
detector.get_target_changed_signal().connect(_on_target_changed)

# Every frame
detector.check_facing_object(self, facing_dir)

# Query
var best = detector.get_best_enemy()           # Single best (O(n))
var all = detector.get_prioritized_enemies()   # Sorted list (O(n log n))
var current = detector.get_current_enemy()     # Locked target
```

## Target Scoring

```
Score = (distance × 0.6) + (angle × 0.4) + persistence_bonus

- Distance: closer = higher (0-1)
- Angle: more centered = higher (0-1)  
- Persistence: +0.15 bonus for current target (prevents flickering)
```

## Detection vs Query

Detection runs every frame to keep the cache fresh. Querying just reads from cache.

```gdscript
func _physics_process(delta: float) -> void:
    # Always update detection
    detector.check_facing_object(self, facing_dir)
    
    # Query on input
    if Input.is_action_just_pressed("attack"):
        var target = detector.get_best_enemy()
        # do something with target
```

## Signals

```gdscript
# Emitted when locked target changes
detector.get_target_changed_signal().connect(_on_target_changed)

func _on_target_changed(new_target: Node, old_target: Node) -> void:
    if new_target:
        print("Locked: ", new_target.name)
    else:
        print("Target lost")
```

## Configuration

```gdscript
# Full constructor
var detector = EnemyDetector.new(
    GameConstants.LAYER_ENEMY | GameConstants.LAYER_ENVIRONMENT,  # collision mask
    60.0,   # range
    0.5,    # height offset
    1.047,  # cone angle (radians, 60°)
    true    # update_continuously
)

# Runtime changes (use setters to update cached values)
detector.set_detection_range(80.0)
detector.set_cone_angle(PI / 3)
```

## Optimizations

- **Spatial partitioning**: Grid-based culling (auto-disabled for <20 objects)
- **Raycast optimization**: Distant objects checked less frequently
- **Object reuse**: No per-frame allocations
- **Squared distances**: Avoids sqrt where possible

All configurable via `GameConstants`.
