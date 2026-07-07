extends Control

var bullet_nodes = []
var format_string = "%s of 15"
@onready var bullets_collected: Label = $BulletsCount

func _ready() -> void:
	var bullet_hits = 0
	if MPF.game and MPF.game.player:
		bullet_hits = int(MPF.game.player.get("bullet_hits", 0))
	if bullet_hits > 15:
		bullet_hits = 15
	bullets_collected.text = format_string % bullet_hits
	for i in range(1, 16):
		var bullet = get_node("%sBullets" % i) as Sprite2D
		bullet.visible = false
		bullet_nodes.append(bullet)
	_update_bullets(bullet_hits)
	MPF.game.connect("player_update", self._on_player_update)

func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "bullet_hits":
		var bullet_hits = int(value)
		if bullet_hits > 15:
			bullet_hits = 15
		if bullet_hits < 0:
			bullet_hits = 0
		bullets_collected.text = format_string % bullet_hits
		_update_bullets(bullet_hits)

func _update_bullets(bullet_hits: int) -> void:
	for bullet in bullet_nodes:
		bullet.visible = false
	for i in range(0, bullet_hits):
		if i < bullet_nodes.size():
			bullet_nodes[i].visible = true
