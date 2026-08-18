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
## Inside a crater the rover moves this much slower. Burn rate per second
## stays the same, so energy and time per degree both scale by `1 / factor`.
const CRATER_SPEED_FACTOR: float = 0.5

# --- Energy ---

## One-way range from the base on clear ground: `energy * RANGE_PER_ENERGY`
## degrees. Energy 6 covers a full hemisphere (180°) if the path is empty.
const RANGE_PER_ENERGY: float = 30.0
const RECHARGE_PER_SEC: float = 0.25
## Equal-angle samples along a great-circle when costing a trip through craters.
const PATH_SEGMENTS: int = 36

# --- Craters ---

const CRATER_COUNT: int = 10
const CRATER_RADIUS_DEG: float = 12.0

# --- Upgrades ---

const UPGRADE_COST: int = 1

# --- Orders ---

const MAX_ORDERS: int = 5
const START_ORDERS: int = 2
const ORDER_SPAWN_INTERVAL: float = 5.0
const ORDER_LIFETIME: float = 30.0
## Closest an order can appear from the base, in degrees (independent of the
## distance slider tiers).
const ORDER_MIN_DISTANCE_DEG: float = 5.0
const ORDER_WEIGHT_MIN: int = 1

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


## Slider tiers 1..6 map to spawn distance the same way rover energy does.
static func distance_deg_for_tier(tier: int) -> float:
	return float(clampi(tier, STAT_MIN, STAT_MAX)) * RANGE_PER_ENERGY
