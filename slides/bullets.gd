extends Control

var bullet_nodes = []
var format_string = "%s of 15"
@onready var bullets_collected: Label = $BulletsCount

func _ready() -> void:
	bullets_collected.text = format_string % MPF.game.player.bullet_hits

	for i in range(1, 16):
		var bullet = get_node("%sBullets" % i) as Sprite2D
		bullet.visible = false
		bullet_nodes.append(bullet)

	for i in range(0,MPF.game.player.bullet_hits):
			bullet_nodes[i].visible = true

	MPF.game.connect("player_update", self._on_player_update)

func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "bullet_hits":
		if value > 15:
			value = 15

		bullets_collected.text = format_string % value
		for i in range(0,value):
			bullet_nodes[i].visible = true
