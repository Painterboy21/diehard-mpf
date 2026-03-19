extends Control

@export var start_index: int
@onready var lblInitials = $"../Initials"

var letter_index: int
var initials = ""

var letters_lookup = [
	"A","B","C","D","E","F","G","H","I","J","K","L","M",
	"N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	letter_index = self.start_index
	MPF.server.connect("text_input", self._on_text_input_event)
	show_sprite()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_text_input_event(payload):
	print("textinput")
	if not payload.has("action"):
		return

	var count = get_child_count() # or letters.size()
	print(payload.action)
	match payload.action:
		"left":
			letter_index = wrapi(letter_index - 1, 0, count)
		"right":
			letter_index = wrapi(letter_index + 1, 0, count)
		"select":
			if letter_index == 26:
				print("END")
				MPF.server.send_event("text_input_high_score_complete&text=%s" % [initials])
			elif letter_index == 27:
				print("DEL")
				if initials.length() > 0:
					initials = initials.substr(0, initials.length() - 1)
					lblInitials.text = initials
			else:
				if initials.length() < 3:
					initials = initials + letters_lookup[letter_index]
					lblInitials.text = initials
				
	show_sprite()

func show_sprite():
	var children = get_children()
	for i in children.size():
		children[i].visible = (i == letter_index)
