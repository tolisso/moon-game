class_name Balance
extends RefCounted

## Every gameplay number lives here. Visual sizes and camera controls stay in
## their own scripts (`world.gd` for the camera, the marker scripts for looks).

# --- Fleet ---

const ROVER_COUNT: int = 3
const STAT_MIN: int = 1
const STAT_MAX: int = 6
const START_ENERGY: int = 1
const START_WEIGHT: int = 1
## Constant angular speed for every rover, degrees per second along the arc.
const ROVER_SPEED_DEG: float = 8.0

# --- Energy ---

## One-way range from the base: `energy * RANGE_PER_ENERGY` degrees.
## Energy 6 covers a full hemisphere (180°).
const RANGE_PER_ENERGY: float = 30.0
const RECHARGE_PER_SEC: float = 0.25

# --- Upgrades ---

const UPGRADE_COST: int = 1

# --- Orders ---

const MAX_ORDERS: int = 5
const START_ORDERS: int = 2
const ORDER_INTERVAL_MIN: float = 5.0
const ORDER_INTERVAL_MAX: float = 11.0
const ORDER_MIN_DISTANCE_DEG: float = 12.0
const ORDER_MAX_DISTANCE_DEG: float = 170.0
const ORDER_WEIGHT_MIN: int = 1
const ORDER_WEIGHT_MAX: int = 6

# --- Gold ---

const START_GOLD: int = 0
const DELIVERY_REWARD: int = 1


static func range_deg(energy: float) -> float:
	return maxf(energy, 0.0) * RANGE_PER_ENERGY


static func energy_needed(distance_deg: float) -> float:
	return distance_deg / RANGE_PER_ENERGY


static func travel_time(distance_deg: float) -> float:
	return 2.0 * distance_deg / ROVER_SPEED_DEG


static func recharge_time(missing_energy: float) -> float:
	if missing_energy <= 0.0:
		return 0.0
	return missing_energy / RECHARGE_PER_SEC


static func delivery_reward(_distance_deg: float, _weight: float) -> int:
	return DELIVERY_REWARD
