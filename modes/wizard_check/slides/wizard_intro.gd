extends MPFSlide

@onready var video_player = $MPFVideoPlayer

func _ready() -> void:
	if video_player.has_signal("finished"):
		video_player.finished.connect(_on_video_finished)
	video_player.play()

func _on_video_finished() -> void:
	print("wizard_intro video finished - posting wizard_intro_finished")
	_post_mpf_event("wizard_intro_finished")

func _post_mpf_event(event_name: String) -> void:
	var mpf_gmc = get_node_or_null("/root/MpfGmc")
	if mpf_gmc and mpf_gmc.has_method("post_event"):
		mpf_gmc.post_event(event_name)
		return
	if mpf_gmc and mpf_gmc.has_method("send_event"):
		mpf_gmc.send_event(event_name)
		return
	var mpf = get_node_or_null("/root/MPF")
	if mpf and mpf.has_method("post_event"):
		mpf.post_event(event_name)
		return
	if mpf and mpf.has_method("send_event"):
		mpf.send_event(event_name)
		return
	print("Could not post MPF event: ", event_name)
