extends VideoStreamPlayer
# Playlist of video files (local resources)
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
	"Advance Tower",
	"Advance Airplane",
	"Advance Park",
	"Bullets",
	"Ball Save",
	"Bonus X",
	"Hold Bonus X",
	"Advance Bumpers",
	"Advance Spinner",
	"Playfield X",
	"Ambush",
	"Light Extra Ball",
]

@onready var flash_timer: Timer = $Timer
@onready var award_label = $"../VBoxContainer/VaultAward"

var current_index := 0
var flashing := false
var flash_duration := 2.0        # total time to flash
var elapsed_time := 0.0          # accumulator

func _ready() -> void:
	self.finished.connect(_on_video_finished)
	self.flash_timer.timeout.connect(_on_timer_timeout)

	var stream: VideoStream = load(available_videos.pick_random())
	self.stream = stream
	self.play()
	self.start_award_flash()

func start_award_flash():
	flashing = true
	elapsed_time = 0.0
	current_index = 0
	flash_timer.start()

func _on_video_finished() -> void:
	#self.get_parent().remove()
	print("Video Finished")

func _on_timer_timeout() -> void:
	if flashing:
		elapsed_time += flash_timer.wait_time
		# cycle text
		award_label.text = award_names[current_index]
		current_index = (current_index + 1) % award_names.size()

		# stop after full duration
		if elapsed_time >= flash_duration:
			flashing = false
			flash_timer.stop()
			award_label.text = award_names[MPF.game.player.mystery_awarded_index]
