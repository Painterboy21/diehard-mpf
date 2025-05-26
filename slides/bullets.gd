extends Control

var bullet_nodes = []

func _ready() -> void:

	for i in range(1, 16):
		var bullet = get_node("%sBullets" % i) as Sprite2D
		bullet.visible = false
		bullet_nodes.append(bullet)

	MPF.game.connect("player_update", self._on_player_update)

func _on_player_update(var_name: String, value: Variant) -> void:
	print("TODO")
