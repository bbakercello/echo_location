# Raycasting Logic Analysis

## Current Implementation Issues

### 1. **Too Complex & Nested**
- 4-5 levels of nested if statements
- Hard to follow the logic flow
- Difficult to debug and maintain

### 2. **Hardcoded Values**
- `2.0` - close range distance (appears twice)
- `3.0` - far range check distance
- `0.7` - dot product threshold (appears in comment but uses different value)
- `0xFFFFFFFF` - all layers mask (could use a constant)

### 3. **Duplicate Logic**
- Distance calculation done multiple times
- Dot product check appears in multiple places
- Enemy iteration logic is repeated

### 4. **Unnecessary Complexity**
- The direct raycast to enemy (lines 207-254) is overly complex
- If enemy is close and in front, we don't need another raycast
- The `enemy_dist < wall_dist` check already handles this

### 5. **Not Following Single Responsibility**
- One function does too many things:
  - Casts ray
  - Checks groups
  - Calculates distances
  - Does secondary raycasts
  - Handles debug output

## Step-by-Step Logic Walkthrough

### Current Flow:
```
1. Get space state ✓ (Good)
2. Cast forward ray ✓ (Good)
3. Check if hit is enemy → detect ✓ (Good)
4. If hit is wall:
   a. Get all enemies
   b. For each enemy:
      - Calculate distance
      - Check if close enough
      - Calculate dot product
      - Check if in front
      - If close OR closer than wall → detect
      - ELSE do ANOTHER raycast to enemy (unnecessary!)
```

### Problems:
- Step 4b is doing too much
- The "else" block (lines 207-254) is never reached because of the condition on line 198
- Too many nested conditions make it hard to reason about

## Best Practices Violations

1. **Magic Numbers**: Hardcoded values should be constants
2. **Function Length**: `_check_facing_enemy()` is 180+ lines (should be <50)
3. **Cyclomatic Complexity**: Too many branching paths
4. **Code Duplication**: Distance/dot calculations repeated
5. **Mixed Concerns**: Debug code mixed with logic

## Refactored Solution

### Improvements:
1. **Separated Concerns**: Split into `_check_facing_enemy()` and `_check_nearby_enemies()`
2. **All Constants**: All magic numbers are now named constants
3. **Early Returns**: Reduces nesting
4. **Simplified Logic**: Removed unnecessary secondary raycast
5. **Clearer Flow**: Each function has one clear purpose

### New Flow:
```
1. Cast forward ray
2. If hit enemy → done ✓
3. If hit wall → check nearby enemies
4. Nearby check:
   - Filter by distance
   - Filter by direction (dot product)
   - If close OR closer than wall → detect
```

## Recommendations

1. **Use the refactored version** - It's cleaner and easier to maintain
2. **Add constants** for all magic numbers
3. **Split large functions** into smaller, focused ones
4. **Remove unnecessary raycasts** - The distance check is sufficient
5. **Use early returns** to reduce nesting

## Godot Best Practices Followed

✅ Using `PhysicsDirectSpaceState3D` correctly
✅ Using `PhysicsRayQueryParameters3D.create()`
✅ Excluding self from raycast
✅ Using groups for enemy detection
✅ Proper type checking with `is` keyword
✅ Using constants for configuration

## Godot Best Practices NOT Followed (in current version)

❌ Function too long (should be <50 lines)
❌ Too many nested conditions
❌ Magic numbers scattered throughout
❌ Mixed concerns (debug + logic)
❌ Unnecessary complexity

