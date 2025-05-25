extends Control

var holly_h: Sprite2D
var holly_o: Sprite2D
var holly_l: Sprite2D
var holly_l1: Sprite2D
var holly_y: Sprite2D

func _ready() -> void:
	print("Holly Letters Ready")
	self.holly_h = $H
	self.holly_o = $O
	self.holly_l = $L
	self.holly_l1 = $L1
	self.holly_y = $Y

	self.holly_h.visible = 0
	self.holly_o.visible = 0
	self.holly_l.visible = 0
	self.holly_l1.visible = 0
	self.holly_y.visible = 0
	MPF.game.connect("player_update", self._on_player_update)

func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == 'shot_holly_h':
		self.holly_h.visible = value
	if var_name == 'shot_holly_o':
		self.holly_o.visible = value
	if var_name == 'shot_holly_l':
		self.holly_l.visible = value
	if var_name == 'shot_holly_l1':
		self.holly_l1.visible = value
	if var_name == 'shot_holly_y':
		self.holly_y.visible = value
