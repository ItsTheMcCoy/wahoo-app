extends Control

const WahooResponsiveLayout = preload("res://scripts/wahoo_responsive_layout.gd")

signal closed

const PAGE_TITLES: Array = [
	"Goal & Setup",
	"Your Turn",
	"Moving Your Marbles",
	"The Center Shortcut",
	"Winning",
]

const PAGE_BODIES: Array = [
	"[b]Objective[/b]\nBe the first player to move all 4 of your marbles into your home row.\n\n[b]Setup[/b]\n4 players, 4 marbles each. All start in your base.\n\nOne six-sided die. Highest opening roll goes first; play passes clockwise.",

	"Roll the die and move one marble according to the rules.\n\n[b]If you can make a legal move, you must.[/b] No legal move? Your turn passes.\n\n[b]Rolling a 6 lets you roll again[/b], no limit on consecutive 6s.",

	"[b]Getting out of base[/b]\nRoll a 1 or 6 to move a marble from base onto your start square.\n\n[b]On the track[/b]\nMove forward the exact number rolled. You can't land on your own marbles. Landing on an opponent's marble sends it back to their base.\n\n[b]Into home[/b]\nOnce a marble makes it around the board (or takes the center shortcut, see the next page) it cannot go past your home row. You need an exact roll to land in each slot, no overshooting. If you can't make the move, that marble stays put.\n\n[b]Inside home[/b]\nHome marbles are safe and can't be captured.",

	"The center position is a major shortcut.\n\n[b]To enter:[/b]  Your marble must be in the first 6 squares after leaving base. Roll exactly the number that lands you in the center position. Entering is [b]optional[/b], you can choose to advance around the board normally instead.\n\n[b]To Exit:[/b] You must roll a 1. Your marble exits into the position that is both closest to the center position and your home row.\n\n[b]The Catch:[/b] Only one marble fits at a time. An opponent who rolls the right number to enter bumps you back to base.\n\n[b]One chance per trip[/b] — once past the entry window, no shortcut for that marble.",

	"Did you not read the first page?\n\nIt was literally the first sentence of the first page.",
]

@onready var _title_label: Label          = $Center/HowToPlayPanel/HowToPlayContent/HowToPlayTitle
@onready var _body_scroll: ScrollContainer = $Center/HowToPlayPanel/HowToPlayContent/BodyScroll
@onready var _body_label: RichTextLabel   = $Center/HowToPlayPanel/HowToPlayContent/BodyScroll/HowToPlayBody
@onready var _prev_btn: Button            = $Center/HowToPlayPanel/HowToPlayContent/NavRow/PrevBtn
@onready var _page_indicator: Label       = $Center/HowToPlayPanel/HowToPlayContent/NavRow/PageIndicator
@onready var _next_btn: Button            = $Center/HowToPlayPanel/HowToPlayContent/NavRow/NextBtn
@onready var _close_btn: Button           = $Center/HowToPlayPanel/HowToPlayContent/CloseBtn
@onready var _panel: PanelContainer       = $Center/HowToPlayPanel
@onready var _content: VBoxContainer      = $Center/HowToPlayPanel/HowToPlayContent

var _current_page := 0

func _ready() -> void:
	_prev_btn.pressed.connect(_go_prev)
	_next_btn.pressed.connect(_go_next)
	_close_btn.pressed.connect(_close)
	_apply_theme()
	get_viewport().size_changed.connect(_apply_theme)
	visible = false

func show_overlay() -> void:
	_current_page = 0
	_update_page()
	visible = true
	WahooResponsiveLayout.push_back_handler(_close)

func _close() -> void:
	visible = false
	WahooResponsiveLayout.pop_back_handler()
	closed.emit()

func _go_prev() -> void:
	if _current_page > 0:
		_current_page -= 1
		_update_page()

func _go_next() -> void:
	if _current_page < PAGE_TITLES.size() - 1:
		_current_page += 1
		_update_page()

func _update_page() -> void:
	_title_label.text = PAGE_TITLES[_current_page]
	_body_label.text = PAGE_BODIES[_current_page]
	_page_indicator.text = "%d / %d" % [_current_page + 1, PAGE_TITLES.size()]
	_prev_btn.disabled = _current_page == 0
	_next_btn.disabled = _current_page == PAGE_TITLES.size() - 1
	_body_scroll.scroll_vertical = 0

func _apply_theme() -> void:
	var viewport_size := get_viewport_rect().size
	var is_mobile := WahooResponsiveLayout.is_mobile_like_layout(viewport_size)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.17, 0.13, 0.10, 0.94)
	panel_style.border_color = Color(0.46, 0.34, 0.24, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	panel_style.shadow_size = 6
	var margin := 24 if is_mobile else 28
	panel_style.content_margin_left = margin
	panel_style.content_margin_top = margin
	panel_style.content_margin_right = margin
	panel_style.content_margin_bottom = margin
	_panel.add_theme_stylebox_override("panel", panel_style)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.30, 0.22, 0.15, 0.98)
	btn_normal.border_color = Color(0.73, 0.56, 0.39, 0.98)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.38, 0.28, 0.19, 0.98)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.22, 0.16, 0.11, 0.98)

	var btn_disabled := btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.19, 0.15, 0.12, 0.74)
	btn_disabled.border_color = Color(0.41, 0.34, 0.28, 0.74)

	var nav_font_size := 20 if is_mobile else 18
	var close_font_size := 22 if is_mobile else 20
	var close_height := 56 if is_mobile else 52

	for btn: Button in [_prev_btn, _next_btn]:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_stylebox_override("disabled", btn_disabled)
		btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
		btn.add_theme_color_override("font_pressed_color", Color(0.97, 0.93, 0.86))
		btn.add_theme_color_override("font_disabled_color", Color(0.67, 0.62, 0.57))
		btn.add_theme_font_size_override("font_size", nav_font_size)

	_close_btn.add_theme_stylebox_override("normal", btn_normal)
	_close_btn.add_theme_stylebox_override("hover", btn_hover)
	_close_btn.add_theme_stylebox_override("pressed", btn_pressed)
	_close_btn.add_theme_stylebox_override("disabled", btn_disabled)
	_close_btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
	_close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
	_close_btn.add_theme_color_override("font_pressed_color", Color(0.97, 0.93, 0.86))
	_close_btn.custom_minimum_size = Vector2(0, close_height)
	_close_btn.add_theme_font_size_override("font_size", close_font_size)

	var title_size := 22 if is_mobile else 20
	_title_label.add_theme_font_size_override("font_size", title_size)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))

	var body_size := 17 if is_mobile else 16
	_body_label.add_theme_font_size_override("normal_font_size", body_size)
	_body_label.add_theme_font_size_override("bold_font_size", body_size)
	_body_label.add_theme_color_override("default_color", Color(0.95, 0.91, 0.84))

	var indicator_size := 17 if is_mobile else 15
	_page_indicator.add_theme_font_size_override("font_size", indicator_size)
	_page_indicator.add_theme_color_override("font_color", Color(0.72, 0.66, 0.58))

	var content_width := 460.0 if is_mobile else 480.0
	if viewport_size.x > 0.0 and viewport_size.x < content_width + 80.0:
		content_width = maxf(280.0, viewport_size.x - 80.0)
	_content.custom_minimum_size = Vector2(content_width, 0)

	var body_min_height := 200 if is_mobile else 220
	_body_scroll.custom_minimum_size = Vector2(0, body_min_height)
