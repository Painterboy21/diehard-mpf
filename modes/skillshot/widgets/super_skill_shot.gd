extends MPFWidget

@onready var label: Label = $label

func _ready():
	call_deferred("play_intro")

func set_font_colour(colour: Color):
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

func play_intro():
	visible = true
	label.visible = true
	label.text = "SUPER SKILL SHOT HIT"

	# Keep modulate white so it does not tint the black shadow/outline.
	modulate = Color(1, 1, 1, 1)
	label.modulate = Color(1, 1, 1, 1)
	label.self_modulate = Color(1, 1, 1, 1)

	# Force clean text, black outline, black shadow.
	set_font_colour(Color(1, 1, 1, 1))
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_constant_override("shadow_offset_x", 5)
	label.add_theme_constant_override("shadow_offset_y", 5)

	label.scale = Vector2(0.05, 0.05)
	label.rotation_degrees = 0

	await get_tree().process_frame
	label.pivot_offset = label.size / 2

	var start_pos = label.position
	var tween = create_tween()

	# Big straight Die Hard-style impact entrance.
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.65, 1.65), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): set_font_colour(Color(1, 1, 1, 1)))
	tween.set_parallel(false)

	# Slam down but keep straight.
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Alarm flicker - font only, shadow stays black.
	tween.tween_callback(func(): set_font_colour(Color(1, 1, 1, 1)))
	tween.tween_interval(0.04)
	tween.tween_callback(func(): set_font_colour(Color(1, 0.05, 0.02, 1)))
	tween.tween_interval(0.04)
	tween.tween_callback(func(): set_font_colour(Color(1, 1, 1, 1)))
	tween.tween_interval(0.04)
	tween.tween_callback(func(): set_font_colour(Color(1, 0.05, 0.02, 1)))
	tween.tween_interval(0.04)
	tween.tween_callback(func(): set_font_colour(Color(1, 1, 1, 1)))

	# Small straight shake.
	tween.tween_property(label, "position", start_pos + Vector2(-18, 0), 0.03)
	tween.tween_property(label, "position", start_pos + Vector2(18, 0), 0.03)
	tween.tween_property(label, "position", start_pos + Vector2(-8, 0), 0.03)
	tween.tween_property(label, "position", start_pos, 0.03)

	# Hold SUPER SKILL SHOT HIT.
	tween.tween_interval(0.55)

	# First flip: show 10000.
	tween.tween_property(label, "scale:x", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_flip_to_points)
	tween.tween_property(label, "scale:x", 1.25, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Hold 10000.
	tween.tween_interval(0.75)

	# Second flip: show FULL BULLETS.
	tween.tween_property(label, "scale:x", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_flip_to_full_bullets)
	tween.tween_property(label, "scale:x", 1.25, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Final straight punch and hold.
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "rotation_degrees", 0, 0.01)
	tween.tween_interval(1.0)

func _flip_to_points():
	label.text = "10000"
	set_font_colour(Color(1, 1, 1, 1))
	label.rotation_degrees = 0

func _flip_to_full_bullets():
	label.text = "FULL BULLETS"
	set_font_colour(Color(1, 1, 1, 1))
	label.rotation_degrees = 0
