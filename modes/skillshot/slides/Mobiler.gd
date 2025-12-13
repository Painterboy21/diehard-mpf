extends Sprite2D

var speed = 2000
var movingRight = true
var isInCenter = false
var hitSuccess = false
var playingIntro = true

@onready var videoPlayer: VideoStreamPlayer = $"../VideoStreamPlayer"

# Called when the node enters the scene tree for the first time.
func _ready():
	position.x = -312
	movingRight = true
	isInCenter = false
	if MPF.game.player:
		var currentBall = MPF.game.player.ball
		speed = 1000 + currentBall * 1000
		if speed > 3000:
			speed = 3000

	videoPlayer.stream = load("res://modes/skillshot/slides/assets/SkillShot.ogv")
	videoPlayer.finished.connect(_on_video_finished)
	videoPlayer.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if playingIntro:
		return

	if movingRight:
		position.x += speed * delta
	else:
		position.x -= speed * delta

	var screen_center = get_viewport_rect().size.x / 2
	if abs(position.x - screen_center) < 150:
		modulate = Color(1,0,0)
		isInCenter = true
	else:
		modulate = Color(1,1,1)
		isInCenter = false

	if position.x > get_viewport_rect().size.x + 312:
		movingRight = false
		flip_h = true
	elif position.x < -312:
		movingRight = true
		flip_h = false

func CheckHit(payload: Dictionary):
	if playingIntro:
		MPF.server.send_event("skillshot_miss")
		return

	if isInCenter:
		#play success video
		hitSuccess = true
		match MPF.game.player.ball:
			1: videoPlayer.stream = load("res://modes/skillshot/slides/assets/1M5Sec.ogv")
			2: videoPlayer.stream = load("res://modes/skillshot/slides/assets/2Mil7Sec.ogv")
			_: videoPlayer.stream = load("res://modes/skillshot/slides/assets/4M10Sec.ogv")
	else:
		#play miss video
		hitSuccess = false
		videoPlayer.stream = load("res://modes/skillshot/slides/assets/SkillshotMissed.ogv")

	videoPlayer.play()

func _on_video_finished():
	if playingIntro:
		playingIntro = false
		return

	if hitSuccess:
		MPF.server.send_event("skillshot_hit")
	else:
		MPF.server.send_event("skillshot_miss")
