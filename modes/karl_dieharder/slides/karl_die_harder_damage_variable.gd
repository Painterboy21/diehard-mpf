extends MPFVariable

# ------------------------------------------------------------
# KARL DIE HARDER - DAMAGE VARIABLE SCRIPT
# ------------------------------------------------------------
#
# Attach this to:
#
#   Control1/KarlDieHarderDamageVariable
#
# Expected sibling node:
#
#   karlDieHarderhealth
#
# MPF variable on this node:
#
#   karl_health_display
# ------------------------------------------------------------


@onready var karl_health: TextureRect = $"../karlDieHarderhealth"


var last_damage := -1


func _ready() -> void:
	super._ready()

	if karl_health == null:
		push_warning("karlDieHarderhealth not found from KarlDieHarderDamageVariable")


func _process(_delta: float) -> void:
	if karl_health == null:
		return

	var clean_text := text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var damage := int(clean_text)

	if damage == last_damage:
		return

	last_damage = damage

	var frame_number := 12 - int(float(damage) * 0.12)
	frame_number = clamp(frame_number, 1, 12)

	# Reuse the existing Karl health images from Karl Die Hard.
	var path := "res://modes/karl_diehard/widgets/karl%d.png" % frame_number
	var texture_file := load(path)

	if texture_file == null:
		push_warning("Missing Karl health frame: %s" % path)
		return

	karl_health.texture = texture_file
