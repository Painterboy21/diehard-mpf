extends Control

@onready var P1Overlay: Control = $P1Overlay
@onready var P2Overlay: Control = $P2Overlay
@onready var P3Overlay: Control = $P3Overlay
@onready var P4Overlay: Control = $P4Overlay

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player = MPF.game.player.number
	P1Overlay.visible = false
	P2Overlay.visible = false
	P3Overlay.visible = false
	P4Overlay.visible = false

	match player:
		1:
			P1Overlay.visible = true
		2:
			P2Overlay.visible = true
		3:
			P3Overlay.visible = true
		4:
			P4Overlay.visible = true
	
	
	
