class_name WahooResponsiveLayout
extends RefCounted

const MAIN_COMPACT_BREAKPOINT := 980.0
const MAIN_COMPACT_ASPECT_THRESHOLD := 1.12
const MOBILE_LIKE_SHORT_SIDE_MAX := 600.0
const MOBILE_LIKE_LONG_SIDE_MAX := 2200.0
const SHORT_LANDSCAPE_HEIGHT_MAX := 760.0

static func is_mobile_like_layout(viewport_size: Vector2) -> bool:
	var short_side := minf(viewport_size.x, viewport_size.y)
	var long_side := maxf(viewport_size.x, viewport_size.y)
	return short_side <= MOBILE_LIKE_SHORT_SIDE_MAX and long_side <= MOBILE_LIKE_LONG_SIDE_MAX

static func is_main_scene_compact(viewport_size: Vector2) -> bool:
	return viewport_size.x <= MAIN_COMPACT_BREAKPOINT \
		or viewport_size.x < viewport_size.y * MAIN_COMPACT_ASPECT_THRESHOLD \
		or is_mobile_like_layout(viewport_size)

static func is_short_landscape(viewport_size: Vector2) -> bool:
	return viewport_size.x > viewport_size.y and viewport_size.y <= SHORT_LANDSCAPE_HEIGHT_MAX
