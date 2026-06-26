extends Sprite2D

var speed = 2000
var movingRight = true
var isInCenter = false
var hitSuccess = false
var playingIntro = true
var skillshotHitSent = false

var playerBallFlashTime = 0.0
var playerBallFlashSpeed = 0.25
var playerBallFlashCount = 0
var playerBallMaxFlashes = 6
var playerBallFlashFinished = false
var playerBallLabelActive = false

var playerBallHoldTime = 0.0
var playerBallHoldDuration = 4.0
var playerBallHolding = false

var clearSkillshotHandler := Callable()

@onready var videoPlayer: VideoStreamPlayer = $"../VideoStreamPlayer"
@onready var playerBallLabel: Label = $"../PlayerBallLabel"


func _ready():
	position.x = -312
	movingRight = true
	isInCenter = false
	hitSuccess = false
	playingIntro = true
	skillshotHitSent = false

	playerBallFlashTime = 0.0
	playerBallFlashCount = 0
	playerBallFlashFinished = false
	playerBallLabelActive = false
	playerBallHoldTime = 0.0
	playerBallHolding = false

	clearSkillshotHandler = Callable(self, "_on_clear_skillshot_player_ball")
	MPF.server.add_event_handler("clear_skillshot_player_ball", clearSkillshotHandler)

	update_player_ball_label()

	if MPF.game.player:
		var currentBall = MPF.game.player.ball
		speed = 1700 + currentBall * 900
		if speed > 4000:
			speed = 4000

	videoPlayer.stream = load("res://modes/skillshot/slides/assets/SkillShot.ogv")
	videoPlayer.finished.connect(_on_video_finished)
	videoPlayer.play()


func _exit_tree():
	if clearSkillshotHandler.is_valid():
		MPF.server.remove_event_handler("clear_skillshot_player_ball", clearSkillshotHandler)


func update_player_ball_label():
	if not playerBallLabel:
		return

	var player_num = 1
	var ball_num = 1

	if MPF.game.player:
		ball_num = int(MPF.game.player.ball)

		var possible_player_num = null

		if "number" in MPF.game.player:
			possible_player_num = MPF.game.player.number
		elif "player_num" in MPF.game.player:
			possible_player_num = MPF.game.player.player_num
		elif "num" in MPF.game.player:
			possible_player_num = MPF.game.player.num

		if possible_player_num != null:
			player_num = int(possible_player_num)

	playerBallLabel.text = "PLAYER %d  BALL %d" % [player_num, ball_num]
	playerBallLabel.visible = true

	playerBallLabelActive = true
	playerBallFlashTime = 0.0
	playerBallFlashCount = 0
	playerBallFlashFinished = false
	playerBallHoldTime = 0.0
	playerBallHolding = false


func hide_player_ball_label():
	playerBallLabelActive = false
	playerBallFlashFinished = true
	playerBallHolding = false
	playerBallFlashTime = 0.0
	playerBallFlashCount = 0
	playerBallHoldTime = 0.0

	if playerBallLabel:
		playerBallLabel.visible = false
		playerBallLabel.text = ""


func flash_player_ball_label(delta):
	if not playerBallLabel:
		return

	if not playerBallLabelActive:
		playerBallLabel.visible = false
		return

	if not playerBallFlashFinished:
		playerBallFlashTime += delta

		if playerBallFlashTime >= playerBallFlashSpeed:
			playerBallFlashTime = 0.0
			playerBallLabel.visible = not playerBallLabel.visible
			playerBallFlashCount += 1

			if playerBallFlashCount >= playerBallMaxFlashes:
				playerBallFlashFinished = true
				playerBallHolding = true
				playerBallHoldTime = 0.0
				playerBallLabel.visible = true

		return

	if playerBallHolding:
		playerBallLabel.visible = true
		playerBallHoldTime += delta

		if playerBallHoldTime >= playerBallHoldDuration:
			hide_player_ball_label()

		return


func _process(delta):
	flash_player_ball_label(delta)

	if playingIntro:
		return

	if movingRight:
		position.x += speed * delta
	else:
		position.x -= speed * delta

	var screen_center = get_viewport_rect().size.x / 2

	if abs(position.x - screen_center) < 150:
		modulate = Color(1, 0, 0)
		isInCenter = true
	else:
		modulate = Color(1, 1, 1)
		isInCenter = false

	if position.x > get_viewport_rect().size.x + 312:
		movingRight = false
		flip_h = true
	elif position.x < -312:
		movingRight = true
		flip_h = false


func CheckHit(payload: Dictionary):
	hide_player_ball_label()

	if playingIntro:
		MPF.server.send_event("skillshot_miss")
		return

	if isInCenter:
		hitSuccess = true

		if not skillshotHitSent:
			skillshotHitSent = true
			MPF.server.send_event("skillshot_hit_fast")

		match MPF.game.player.ball:
			1:
				videoPlayer.stream = load("res://modes/skillshot/slides/assets/1M5Sec.ogv")
			2:
				videoPlayer.stream = load("res://modes/skillshot/slides/assets/2Mil7Sec.ogv")
			_:
				videoPlayer.stream = load("res://modes/skillshot/slides/assets/4M10Sec.ogv")
	else:
		hitSuccess = false
		videoPlayer.stream = load("res://modes/skillshot/slides/assets/SkillshotMissed.ogv")

	videoPlayer.visible = true
	videoPlayer.play()


func _on_video_finished():
	if playingIntro:
		playingIntro = false
		videoPlayer.visible = false
		return

	hide_player_ball_label()

	if hitSuccess:
		MPF.server.send_event("skillshot_hit")
	else:
		MPF.server.send_event("skillshot_miss")


func _on_clear_skillshot_player_ball(payload: Dictionary):
	hide_player_ball_label()