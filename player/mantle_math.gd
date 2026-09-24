class_name MantleMath
extends RefCounted

## Pure math for whether a ledge can be mantled and how long it takes
## (DESIGN.md §2.1: "between 0.2 m and 1.9 m above your feet ... Ledges from
## 0.5 m up take about 0.6-0.9 s, longer for higher ones. Low ledges
## (0.2-0.5 m) are a quick step-up of about 0.3 s").


## `height` is the ledge's height above the player's feet, in metres.
static func is_height_acceptable(height: float, min_height: float, max_height: float) -> bool:
	return height >= min_height and height <= max_height


## Below `step_up_max_height` (0.5 m), every mantle is a quick, constant
## `step_up_duration` step-up, regardless of the exact low height. At and
## above it, duration scales linearly up to `max_duration` at `max_height`,
## same as before. Heights outside the accepted range are clamped rather
## than extrapolated, since callers should have already rejected them with
## `is_height_acceptable`.
static func duration_for_height(
	height: float,
	step_up_max_height: float,
	max_height: float,
	step_up_duration: float,
	min_duration: float,
	max_duration: float
) -> float:
	if height <= step_up_max_height:
		return step_up_duration
	if max_height <= step_up_max_height:
		return min_duration
	var t: float = clampf((height - step_up_max_height) / (max_height - step_up_max_height), 0.0, 1.0)
	return lerpf(min_duration, max_duration, t)
