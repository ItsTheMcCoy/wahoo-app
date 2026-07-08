extends Control

const PIP_LAYOUTS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
}

@export_range(1, 6, 1) var face: int = 1:
	set(value):
		_face = clampi(value, 1, 6)
		queue_redraw()
	get:
		return _face

var _face := 1
var _idle := true
var _roll_tween: Tween
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	set_idle()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func set_idle() -> void:
	_idle = true
	rotation_degrees = 0.0
	scale = Vector2.ONE
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	queue_redraw()

func set_face(value: int) -> void:
	_idle = false
	face = value
	rotation_degrees = 0.0
	scale = Vector2.ONE

func play_roll(final_face: int) -> void:
	_idle = false
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	rotation_degrees = 0.0
	scale = Vector2.ONE

	var step_count := 12
	for i in range(step_count):
		var progress := float(i) / float(maxi(step_count - 1, 1))
		face = _rng.randi_range(1, 6)
		var wobble := lerpf(26.0, 8.0, progress)
		rotation_degrees = _rng.randf_range(-wobble, wobble)
		scale = Vector2(_rng.randf_range(0.92, 1.08), _rng.randf_range(0.92, 1.08))
		var delay := lerpf(0.05, 0.09, progress * progress)
		await get_tree().create_timer(delay).timeout

	face = clampi(final_face, 1, 6)
	_roll_tween = create_tween()
	_roll_tween.set_parallel(true)
	_roll_tween.tween_property(self, "rotation_degrees", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_roll_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_roll_tween.set_parallel(false)
	_roll_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _roll_tween.finished

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return

	var die_side := side * 0.84
	var die_pos := Vector2((size.x - die_side) * 0.5, (size.y - die_side) * 0.5)
	var die_rect := Rect2(die_pos, Vector2(die_side, die_side))
	var idle_mix := 0.38 if _idle else 0.0

	var shadow_alpha := 0.22 if not _idle else 0.14
	draw_circle(Vector2(size.x * 0.5, die_rect.position.y + die_side * 0.92), die_side * 0.43, Color(0.05, 0.035, 0.025, shadow_alpha))
	draw_circle(Vector2(size.x * 0.5, die_rect.position.y + die_side * 0.92), die_side * 0.31, Color(0.05, 0.035, 0.025, shadow_alpha * 0.45))

	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.95, 0.92, 0.85).lerp(Color(0.55, 0.48, 0.40), idle_mix)
	body.border_color = Color(0.20, 0.14, 0.10)
	var corner := maxi(3, int(round(die_side * 0.18)))
	body.corner_radius_top_left = corner
	body.corner_radius_top_right = corner
	body.corner_radius_bottom_left = corner
	body.corner_radius_bottom_right = corner
	var border_width := maxi(1, int(round(die_side * 0.02)))
	body.border_width_left = border_width
	body.border_width_top = border_width
	body.border_width_right = border_width
	body.border_width_bottom = border_width
	draw_style_box(body, die_rect)

	draw_rect(
		Rect2(die_rect.position + Vector2(0.0, die_side * 0.54), Vector2(die_side, die_side * 0.36)),
		Color(0.34, 0.24, 0.16, 0.17 if not _idle else 0.11),
		true
	)
	draw_rect(
		Rect2(die_rect.position + Vector2(die_side * 0.08, die_side * 0.10), Vector2(die_side * 0.84, die_side * 0.20)),
		Color(1.0, 0.97, 0.90, 0.11 if not _idle else 0.06),
		true
	)

	var pip_color := Color(0.14, 0.10, 0.07).lerp(Color(0.40, 0.34, 0.28), idle_mix)
	var pip_radius := maxf(2.0, die_side * 0.075)
	var spread := die_side * 0.26
	var layout: Array = PIP_LAYOUTS.get(_face, PIP_LAYOUTS[1])
	for offset in layout:
		var pip_pos: Vector2 = die_rect.get_center() + Vector2(offset.x * spread, offset.y * spread)
		draw_circle(pip_pos + Vector2(pip_radius * 0.16, pip_radius * 0.20), pip_radius * 1.04, Color(0.0, 0.0, 0.0, 0.20 if not _idle else 0.12))
		draw_circle(pip_pos, pip_radius, pip_color)
		draw_circle(pip_pos + Vector2(-pip_radius * 0.30, -pip_radius * 0.30), pip_radius * 0.33, Color(1.0, 0.94, 0.86, 0.24 if not _idle else 0.14))
