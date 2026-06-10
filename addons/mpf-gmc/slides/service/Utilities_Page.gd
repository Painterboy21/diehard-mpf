# Copyright 2021 Paradigm Tilt
extends ServicePage
class_name UtilitiesPage

var active_child

@onready var TestViews = $MarginContainer/HBoxContainer/TestViews

func _ready():
	List = $MarginContainer/HBoxContainer/VBoxContainer
	_add_reset_scores_button()

func _add_reset_scores_button():
	if List.has_node("reset_all_scores"):
		return

	var button_scene = preload("res://addons/mpf-gmc/slides/service/List_Button.tscn")
	var button = button_scene.instantiate()

	button.name = "reset_all_scores"

	if "text" in button:
		button.text = "RESET ALL SCORES"

	List.add_child(button)

func _input(event):
	if not event.is_class("InputEventKey") or event.key_label != -1:
		return
	if not self.is_focused:
		return

	if event.keycode == KEY_ENTER or event.keycode == KEY_CAPSLOCK:
		for c in List.get_children():
			if c.has_focus():
				var focused_name: String = c.name

				if focused_name == "reset_all_scores":
					MPF.server.send_event("reset_all_scores_and_records")
					print("Service reset requested: reset_all_scores_and_records")
					self._show_reset_scores_message()
					get_window().set_input_as_handled()
					break

				MPF.server.send_event("service_trigger&action=%s&sort=false" % focused_name)
				self._update_test_views(focused_name)
				get_window().set_input_as_handled()
				break

	elif active_child and (event.keycode == KEY_ESCAPE or event.keycode == KEY_CAPSLOCK):
		self.deselect_child()
		get_window().set_input_as_handled()
	else:
		super(event)

# A public method so children can de-select themselves
func deselect_child():
	List.get_node(active_child).grab_focus()
	MPF.server.send_event("sw_service_esc_active")
	self._update_test_views()

func _update_test_views(focused_name:String = ""):
	active_child = false

	for child in TestViews.get_children():
		TestViews.remove_child(child)
		child.queue_free()

	for menu in List.get_children():
		if "button_pressed" in menu:
			menu.button_pressed = menu.name == focused_name

	if focused_name:
		active_child = focused_name
		var child_node = load("res://addons/mpf-gmc/slides/service/%s.tscn" % focused_name).instantiate()
		TestViews.add_child(child_node)
		child_node.grab_focus()

func _show_reset_scores_message():
	active_child = false

	for child in TestViews.get_children():
		TestViews.remove_child(child)
		child.queue_free()

	for menu in List.get_children():
		if "button_pressed" in menu:
			menu.button_pressed = menu.name == "reset_all_scores"

	var label = Label.new()
	label.text = "ALL LOCAL SCORES\nAND MACHINE RECORDS\nRESET REQUESTED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	TestViews.add_child(label)