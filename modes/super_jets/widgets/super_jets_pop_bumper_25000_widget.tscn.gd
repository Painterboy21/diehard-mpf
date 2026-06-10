
extends MPFWidget

@onready var holder: Node2D = $RandomHolder
@onready var sprite: Sprite2D = $RandomHolder/Sprite2D

var rng := RandomNumberGenerator.new()
var tween: Tween


func _ready():
	rng.randomize()
	visible = true
	holder.visible = true
	sprite.visible = true
	call_deferred("show_random")


func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_inside_tree():
		call_deferred("show_random")


func show_random():
	if not is_inside_tree():
		return

	var tree = get_tree()
	if tree == null:
		return

	await tree.process_frame

	if not is_inside_tree():
		return

	tree = get_tree()
	if tree == null:
		return

	await tree.process_frame

	if not is_inside_tree():
		return

	if tween:
		tween.kill()

	rng.randomize()

	var screen_size = get_viewport_rect().size
	var margin_x = 320
	var margin_y = 220

	var random_pos = Vector2(
		rng.randf_range(margin_x, screen_size.x - margin_x),
		rng.randf_range(margin_y, screen_size.y - margin_y)
	)

	holder.global_position = random_pos

	visible = true
	holder.visible = true
	sprite.visible = true

	holder.scale = Vector2(0.4, 0.4)
	holder.modulate = Color(1, 1, 1, 1)
	sprite.modulate = Color(1, 1, 1, 1)

	print("SUPER JETS 25000 RANDOM GLOBAL POSITION: ", holder.global_position)

	tween = create_tween()
	tween.tween_property(holder, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(holder, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_interval(0.35)
	tween.tween_property(holder, "modulate:a", 0.0, 0.2)
