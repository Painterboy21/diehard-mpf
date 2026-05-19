extends Control

var detonator_nodes = []
var last_hits = -1

func _ready() -> void:
	for i in range(1, 9):
		var detonator = get_node("%s_detonator" % i) as Sprite2D
		detonator.visible = true
		detonator_nodes.append(detonator)

	update_from_mpf()


func _process(_delta: float) -> void:
	update_from_mpf()


func update_from_mpf() -> void:
	var hits = int(MPF.game.player.get("hans_diehard_progress", 0))
	hits = clampi(hits, 0, 8)

	if hits == last_hits:
		return

	last_hits = hits
	update_detonators(hits)


func update_detonators(hits: int) -> void:
	# Show all first
	for detonator in detonator_nodes:
		detonator.visible = true

	# Hide one per hit: 1st hit hides 8, then 7, etc.
	for i in range(0, hits):
		detonator_nodes[7 - i].visible = false
