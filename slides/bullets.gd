extends Control

var bullet_nodes = []

@onready var bullets_collected: Label = $BulletsCount

func _ready() -> void:
	bullets_collected.text = "0 of 15"
	for i in range(1, 16):
		var bullet = get_node("%sBullets" % i) as Sprite2D
		bullet.visible = false
		bullet_nodes.append(bullet)

	MPF.game.connect("player_update", self._on_player_update)

func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "bullet_hits":
		if value > 15:
			value = 15

		var format_string = "%s of 15"
		bullets_collected.text = format_string % value
		for i in range(0,value):
			bullet_nodes[i].visible = true
