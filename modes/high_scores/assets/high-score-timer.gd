extends Timer

@onready var label = $"../ExpireLabel"
@onready var text_input = $"../Control"

var t_left := 60

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_label()
	self.start()

func _on_ExpireTimer_timeout():
	t_left -= 1
	update_label()

	if t_left <= 0:
		self.stop()
		on_countdown_finished()

func update_label():
	label.text = str(t_left)

func on_countdown_finished():
	print("Time's up!")
	MPF.server.send_event("text_input_high_score_complete&text=%s" % [text_input.initials])
