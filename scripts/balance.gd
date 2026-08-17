class_name Balance
extends RefCounted

## Every gameplay number lives here: fleet stats, upgrades, order flow and
## rewards. Visual sizes and camera controls are not balance and stay in their
## own scripts (`world.gd` for the camera, the marker scripts for looks).

# --- Fleet ---

const ROVER_COUNT: int = 3
const START_SPEED_MIN: float = 12.0
const START_SPEED_MAX: float = 22.0
const START_ENERGY_MIN: float = 120.0
const START_ENERGY_MAX: float = 200.0
const START_CARGO_MIN: int = 4
const START_CARGO_MAX: int = 8
const START_STRENGTH_MIN: float = 4.0
const START_STRENGTH_MAX: float = 8.0

# --- Energy ---

## Energy spent per degree of arc, so energy doubles as a range in degrees.
const ENERGY_PER_DEG: float = 1.0
const RECHARGE_PER_SEC: float = 12.0

# --- Upgrades ---

## Each purchase multiplies the price of that stat for that rover.
const UPGRADE_COST_GROWTH: float = 1.5
const SPEED_UPGRADE_BASE_COST: int = 20
const SPEED_UPGRADE_STEP: float = 3.0
const ENERGY_UPGRADE_BASE_COST: int = 20
const ENERGY_UPGRADE_STEP: float = 25.0
const CARGO_UPGRADE_BASE_COST: int = 25
const CARGO_UPGRADE_STEP: float = 2.0
const STRENGTH_UPGRADE_BASE_COST: int = 25
const STRENGTH_UPGRADE_STEP: float = 1.0

# --- Orders ---

const MAX_ORDERS: int = 5
const START_ORDERS: int = 2
const ORDER_INTERVAL_MIN: float = 5.0
const ORDER_INTERVAL_MAX: float = 11.0
const ORDER_MIN_DISTANCE_DEG: float = 20.0
const ORDER_MAX_DISTANCE_DEG: float = 170.0
## Keeps every order within reach of at least the strongest battery.
const ORDER_REACH_MARGIN: float = 0.95
const ORDER_CARGO_START: float = 3.0
## Linear growth of the requested cargo, in tons per second of play.
const ORDER_CARGO_GROWTH_PER_SEC: float = 0.03
const ORDER_CARGO_JITTER: float = 0.25

# --- Gold ---

const START_GOLD: int = 0
const REWARD_BASE: float = 10.0
const REWARD_PER_DEG: float = 0.6
## Off by default: the payout is tied to distance only. Raise it if heavier
## loads should also pay more.
const REWARD_PER_CARGO: float = 0.0


static func upgrade_cost(base_cost: int, level: int) -> int:
	return int(round(float(base_cost) * pow(UPGRADE_COST_GROWTH, float(level))))


static func delivery_reward(distance_deg: float, cargo: float) -> int:
	return int(round(REWARD_BASE + REWARD_PER_DEG * distance_deg + REWARD_PER_CARGO * cargo))


static func order_target_cargo(elapsed_sec: float) -> float:
	return ORDER_CARGO_START + ORDER_CARGO_GROWTH_PER_SEC * elapsed_sec


## Speed under load: every `strength` units of cargo halve the base speed.
static func loaded_speed(base_speed: float, strength: float, cargo: float) -> float:
	if cargo <= 0.0 or strength <= 0.0:
		return base_speed
	return base_speed * pow(0.5, cargo / strength)
