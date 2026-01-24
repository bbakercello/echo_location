# Shared game constants
# This script should be added as an Autoload in Project Settings > Autoload
# Name it "GameConstants" so it's accessible globally
extends Node

# ============================================================================
# COLLISION LAYERS
# ============================================================================
# These are the bit flag VALUES (not names) that match the layer numbers in project.godot
# Layer 1 = 1, Layer 2 = 2, Layer 3 = 4, etc. (powers of 2)
# The layer NAMES are defined in project.godot [layer_names] section for editor UI only
const LAYER_PLAYER: int = 1      # Matches layer_1 in project.godot
const LAYER_ENEMY: int = 2       # Matches layer_2 in project.godot
const LAYER_ENVIRONMENT: int = 4  # Matches layer_3 in project.godot

# ============================================================================
# DETECTION SYSTEM CONSTANTS
# ============================================================================

# Distance thresholds
const DETECTION_MIN_DISTANCE_SQ: float = 0.0001  # Min squared distance to prevent division by zero
const DETECTION_MIN_FACING_LENGTH_SQ: float = 0.0001  # Min facing vector length squared

# LOD (Level of Detail) system constants
const DETECTION_LOD_CLOSE_RANGE_RATIO: float = 0.5  # Objects within 50% of range get full checks
const DETECTION_LOD_MID_RANGE_RATIO: float = 0.75  # Objects within 75% get reduced checks
const DETECTION_LOD_MID_RANGE_CHECK_INTERVAL: int = 2  # Check mid-range objects every 2 frames

# Spatial partitioning constants
const DETECTION_SPATIAL_CELL_SIZE_RATIO: float = 0.33  # Cell size as ratio of detection range
const DETECTION_SPATIAL_REBUILD_COOLDOWN: int = 60  # Min frames between rebuilds (~1s at 60fps)
const DETECTION_SPATIAL_MIN_OBJECTS: int = 20  # Auto-disable spatial partitioning if fewer objects

# Group member caching
const DETECTION_CACHE_REFRESH_INTERVAL: int = 30  # Refresh cache every 30 frames (~0.5s at 60fps)

# Spatial hash constants
const DETECTION_SPATIAL_HASH_PRIME: int = 73856093  # Large prime for cell key hashing
# Max cell coordinate before wrapping (prevents overflow)
const DETECTION_SPATIAL_MAX_CELL_COORD: int = 10000

# Spatial partitioning limits
# Maximum cells to check in each direction (prevents excessive checks)
const DETECTION_SPATIAL_MAX_CELL_RADIUS: int = 10

# Default detection configuration values
# These are used as default parameters in ConeDetector._init()
const DETECTION_DEFAULT_RANGE: float = 60.0  # Default detection range in units
const DETECTION_DEFAULT_HEIGHT: float = 0.5  # Default detection height offset
const DETECTION_DEFAULT_CONE_ANGLE_RAD: float = 1.047  # Default cone angle (60 degrees)
