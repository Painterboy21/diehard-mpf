extends Control
## Display only: reads the existing player counters; never posts gameplay events.

const SPINNER_ART = preload("res://godot-media/images/spinnerrectangle.png")
const DISPLAY_FONT = preload("res://godot-media/fonts/impact.ttf")
const CARD_SIZE := Vector2(291, 150)
const HIDDEN_DURING_MODES := [
	"ambush",
	"skillshot",
	"villain_select",
	"wizard_mode",
	"yippee_ki_yay_wizard",
	"airplane_multiball",
	"central_park_multiball",
	"nakatomi_multiball",
	"eob_bonus",
	"hans_diehard",
	"hans_dieharder",
	"karl_diehard",
	"karl_dieharder",
	"katya_diehard",
	"katya_dieharder",
	"simon_diehard",
	"simon_dieharder",
	"col_stuart_diehard",
	"col_stuart_dieharder",
	"hans_difficulty_select",
	"karl_difficulty_select",
	"katya_difficulty_select",
	"simon_difficulty_select",
	"col_difficulty_select",
]

var spinner_left := 25
var pops_left := 10
var spinner_active := false
var pops_active := false
var refresh_elapsed := 0.0
var last_state: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_refresh()


func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var mpf = get_node_or_null("/root/MPF")
	if mpf == null or mpf.game == null or mpf.game.player.is_empty():
		visible = false
		return
	var player: Dictionary = mpf.game.player
	var score = get_parent().get_node_or_null("Control2/main_score")
	visible = (score == null or score.visible) and not _mode_hides_indicators(player, mpf.game.active_modes)
	update_from_player(player)


func _mode_hides_indicators(player: Dictionary, active_modes: Array) -> bool:
	for mode_name in active_modes:
		if str(mode_name) in HIDDEN_DURING_MODES:
			return true
	# The supers multiball runs inside the always-on spinner mode.
	for flag in ["multiball_running", "villain_mode_running", "villain_select_running", "villain_difficulty_select_running", "ambush_running", "wizard_mode_running", "wizard_mode_blackout", "yippee_ki_yay_running"]:
		if int(player.get(flag, 0)) == 1:
			return true
	return false


func update_from_player(player: Dictionary) -> void:
	spinner_left = maxi(0, int(player.get("super_spinners_goal", 25)) - int(player.get("super_spinners_hits", 0)))
	pops_left = maxi(0, int(player.get("super_jets_goal", 10)) - int(player.get("super_jets_hits", 0)))
	spinner_active = int(player.get("super_spinners", 0)) == 1
	pops_active = int(player.get("super_jets_active", 0)) == 1
	var state: Array = [spinner_left, pops_left, spinner_active, pops_active]
	if state != last_state:
		last_state = state
		queue_redraw()


func _draw() -> void:
	_draw_card(Vector2.ZERO, "SUPER SPINNERS", spinner_left, spinner_active, true)
	_draw_card(Vector2(maxf(0.0, size.x - CARD_SIZE.x), 0), "SUPER POPS", pops_left, pops_active, false)


func _draw_card(origin: Vector2, title: String, remaining: int, active: bool, spinner: bool) -> void:
	draw_set_transform(origin)
	# White printed tags matching Holly and Winchester.
	draw_rect(Rect2(Vector2(3, 4), CARD_SIZE), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2.ZERO, CARD_SIZE), Color("faf9f6"))
	draw_string(DISPLAY_FONT, Vector2(8, 32), title, HORIZONTAL_ALIGNMENT_CENTER, 275, 27, Color("cf1720"))
	draw_line(Vector2(0, 43), Vector2(291, 43), Color("dc2028"), 2)
	if spinner:
		var height := 91.0
		var width := height * SPINNER_ART.get_width() / SPINNER_ART.get_height()
		draw_line(Vector2(9, 95), Vector2(95, 95), Color("777777"), 4, true)
		draw_rect(Rect2(16, 50, width + 4, height + 4), Color("dc2028"))
		draw_texture_rect(SPINNER_ART, Rect2(18, 52, width, height), false)
	else:
		draw_set_transform(origin + Vector2(51, 93), 0, Vector2(0.70, 0.70))
		_draw_red_bumper(Vector2.ZERO)
		draw_set_transform(origin)
	var value := "ACTIVE" if active else str(remaining)
	draw_string(DISPLAY_FONT, Vector2(99, 103), value, HORIZONTAL_ALIGNMENT_CENTER, 182, 40 if active else 52, Color("126f36") if active else Color.BLACK)
	var caption := "SUPER SCORING" if active else ("HIT TO GO" if remaining == 1 else "HITS TO GO")
	draw_string(DISPLAY_FONT, Vector2(99, 132), caption, HORIZONTAL_ALIGNMENT_CENTER, 182, 20, Color("303030"))
	draw_set_transform(Vector2.ZERO)


func _draw_red_bumper(center: Vector2) -> void:
	# A red cap, metal skirt and mounting stem, drawn directly in Godot.
	draw_rect(Rect2(center + Vector2(-10, 21), Vector2(20, 42)), Color("868e99"))
	draw_circle(center + Vector2(0, 13), 51, Color("353a43"), true, -1, true)
	draw_circle(center + Vector2(0, 8), 49, Color("d8dce2"), true, -1, true)
	draw_circle(center + Vector2(0, 7), 43, Color("69717b"), true, -1, true)
	draw_circle(center, 47, Color("580c10"), true, -1, true)
	draw_circle(center + Vector2(0, -5), 43, Color("b61822"), true, -1, true)
	draw_circle(center + Vector2(0, -9), 36, Color("ee303b"), true, -1, true)
	draw_arc(center + Vector2(0, -9), 31, PI * 1.12, PI * 1.8, 40, Color("ff9b9f"), 4, true)
	draw_arc(center + Vector2(0, -5), 40, 0.12, PI * 0.85, 40, Color("870d17"), 3, true)

