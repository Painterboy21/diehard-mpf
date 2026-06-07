
extends VideoStreamPlayer


var available_videos: Array[String] = [
	"res://videos/john/john1.ogv",
	"res://videos/john/john2.ogv",
	"res://videos/john/john3.ogv",
	"res://videos/john/john4.ogv",
	"res://videos/john/john5.ogv",
	"res://videos/john/john6.ogv",
	"res://videos/john/john8.ogv",
	"res://videos/john/john10.ogv",
	"res://videos/john/john11.ogv",
	"res://videos/john/john12.ogv",
	"res://videos/john/john13.ogv",
	"res://videos/john/john14.ogv",
	"res://videos/john/john16.ogv",
	"res://videos/john/john17.ogv",
	"res://videos/john/john18.ogv",
	"res://videos/john/john19.ogv",
	"res://videos/john/john21.ogv",
	"res://videos/john/john22.ogv",
	"res://videos/john/john23.ogv",
	"res://videos/john/john24.ogv",
	"res://videos/john/john26.ogv",
	"res://videos/john/john27.ogv",
	"res://videos/john/john29.ogv",
	"res://videos/john/john30.ogv",
	"res://videos/john/john31.ogv",
	"res://videos/john/john33.ogv",
	"res://videos/john/john34.ogv",
	"res://videos/john/john35.ogv",
	"res://videos/john/john37.ogv",
	"res://videos/john/john38.ogv",
	"res://videos/john/john39.ogv",
	"res://videos/john/john40.ogv",
	"res://videos/john/john41.ogv",
	"res://videos/john/john42.ogv",
	"res://videos/john/john43.ogv",
	"res://videos/john/john46.ogv",
	"res://videos/john/john47.ogv",
	"res://videos/john/john48.ogv",
	"res://videos/john/john49.ogv",
	"res://videos/john/john51.ogv",
	"res://videos/john/john52.ogv",
]


var award_names: Array[String] = [
	"Award Points",
	"Advance Nakatomi",
	"Advance Airplane",
	"Advance Park",
	"Bullets",
	"Ball Save",
	"Bonus X",
	"Hold Bonus X",
	"Super Jets",
	"Super Spinners",
	"Playfield X",
	"Ambush",
	"Light Extra Ball",
	"Add a Ball",
	"Add More Time",
]


@onready var flash_timer: Timer = $Timer
@onready var award_label: Label = $"../VBoxContainer/VaultAward"
@onready var bonus_x_held_widget: CanvasItem = $"../VBoxContainer/BonusXHeldWidget"


var current_index := 0
var flashing := false
var last_award_index := -1

var scroll_award_indexes: Array[int] = []
var scroll_position := 0


func _ready() -> void:
	self.finished.connect(_on_video_finished)
	flash_timer.timeout.connect(_on_timer_timeout)

	MPF.server.add_event_handler("mystery_awarded", self._mystery_awarded)
	MPF.server.add_event_handler("show_bonus_x_held_widget", self._show_bonus_x_held_widget)
	MPF.server.add_event_handler("hide_bonus_x_held_widget", self._hide_bonus_x_held_widget)

	MPF.game.connect("player_update", self._on_player_update)

	if bonus_x_held_widget:
		bonus_x_held_widget.visible = false

	var stream: VideoStream = load(available_videos.pick_random())
	self.stream = stream
	self.play()

	start_award_flash()


func start_award_flash() -> void:
	flashing = true
	current_index = 0
	scroll_position = 0
	last_award_index = -1

	_build_scroll_award_indexes()

	if award_label and scroll_award_indexes.size() > 0:
		award_label.visible = true
		award_label.text = award_names[scroll_award_indexes[0]]

	flash_timer.start()


func _build_scroll_award_indexes() -> void:
	scroll_award_indexes.clear()

	var bullets_full := int(_get_player_var("bullet_hits", 0)) >= 15
	var super_spinners_awarded := int(_get_player_var("super_spinners", 0)) == 1

	var villain_active := int(_get_player_var("mystery_villain_active", 0)) == 1
	var multiball_active := int(_get_player_var("mystery_multiball_active", 0)) == 1
	var ambush_active := int(_get_player_var("mystery_ambush_active", 0)) == 1
	var pending_ambush := int(_get_player_var("mystery_pending_ambush", 0)) == 1

	var add_time_available := int(_get_player_var("mystery_add_time_available", 0)) == 1
	var add_a_ball_available := int(_get_player_var("mystery_add_a_ball_available", 0)) == 1

	for i in range(award_names.size()):
		if bullets_full and i == 4:
			continue

		if super_spinners_awarded and i == 9:
			continue

		if i == 11 and (villain_active or multiball_active or ambush_active or pending_ambush):
			continue

		if i == 13 and not (multiball_active and add_a_ball_available):
			continue

		if i == 14 and not (villain_active and add_time_available):
			continue

		scroll_award_indexes.append(i)


func _on_timer_timeout() -> void:
	if not flashing:
		return

	if scroll_award_indexes.size() == 0:
		return

	var award_index := scroll_award_indexes[scroll_position]
	award_label.text = award_names[award_index]

	scroll_position = (scroll_position + 1) % scroll_award_indexes.size()


func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "mystery_awarded_index":
		last_award_index = int(value)

		if last_award_index < 0:
			_clear_award_label_only()
			return

		if not flashing:
			_show_award_by_index(last_award_index)


func _mystery_awarded(payload: Dictionary) -> void:
	flashing = false
	flash_timer.stop()

	if last_award_index >= 0:
		_show_award_by_index(last_award_index)
		return

	var index = _get_player_var("mystery_awarded_index", -1)
	_show_award_by_index(int(index))


func _show_award_by_index(index: int) -> void:
	if index < 0:
		_clear_award_label_only()
		return

	if index >= award_names.size():
		print("Mystery award index out of range: ", index)
		return

	if award_label:
		award_label.visible = true
		award_label.text = award_names[index]

	print("Mystery final award: ", award_names[index])


func _clear_award_label_only() -> void:
	flashing = false
	last_award_index = -1

	if flash_timer:
		flash_timer.stop()

	if award_label:
		award_label.text = ""
		award_label.visible = false

	if bonus_x_held_widget:
		bonus_x_held_widget.visible = false

	print("Mystery award label cleared")


func _show_bonus_x_held_widget(payload: Dictionary = {}) -> void:
	if bonus_x_held_widget:
		bonus_x_held_widget.visible = true
		print("Bonus X Held widget shown")


func _hide_bonus_x_held_widget(payload: Dictionary = {}) -> void:
	if bonus_x_held_widget:
		bonus_x_held_widget.visible = false
		print("Bonus X Held widget hidden")


func _get_player_var(var_name: String, default_value: Variant = null) -> Variant:
	if MPF.game.player == null:
		return default_value

	var value = MPF.game.player.get(var_name)

	if value == null:
		return default_value

	return value


func _on_video_finished() -> void:
	print("Video Finished")
