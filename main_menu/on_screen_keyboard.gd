# Adapted from the plugin "Onscreen Keyboard" https://godotengine.org/asset-library/asset/1328
# The plugin doesn't work with controllers, so the code was forked and heavily modified to do so.

@tool
extends PanelContainer

@export var line_edit: LineEdit
@export var separation:Vector2i = Vector2i(0,0)

@export_group("Font")
@export var font:FontFile
@export var font_size:int = 24
@export var font_color_normal:Color = Color(1,1,1)
@export var font_color_hover:Color = Color(1,1,1)
@export var font_color_pressed:Color = Color(1,1,1)

@onready var KeyListHandler = preload("res://on_screen_keyboard/scripts/keylist.gd").new()
@onready var KeyboardButton = preload("res://on_screen_keyboard/scripts/keyboard_button.gd")
@onready var default_layout = preload("res://on_screen_keyboard/scripts/default_layout.gd").new()
const ICON_DELETE = preload("res://on_screen_keyboard/icons/delete.png")
const ICON_SHIFT = preload("res://on_screen_keyboard/icons/shift.png")
const ICON_LEFT = preload("res://on_screen_keyboard/icons/left.png")
const ICON_RIGHT = preload("res://on_screen_keyboard/icons/right.png")
const ICON_HIDE = preload("res://on_screen_keyboard/icons/hide.png")
const ICON_ENTER = preload("res://on_screen_keyboard/icons/enter.png")

var layouts = []
var keys = []
var capslock_keys = []
var uppercase = false
var prev_prev_layout = null
var previous_layout = null
var current_layout = null


signal layout_changed


func _ready() -> void:
	layouts = []
	keys = []
	capslock_keys = []
	uppercase = false
	prev_prev_layout = null
	previous_layout = null
	current_layout = null
	_init_keyboard()


func _input(event):
	var current_focus = get_viewport().gui_get_focus_owner()

	# show the keyboard if the LineEdit is focused and the user pressed ui_accept
	if not visible and current_focus is LineEdit and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if not line_edit.has_selection():
			line_edit.select_all()
		show_keyboard()
		select_first_key()

	# don't process input if not visible
	elif not visible:
		return

	# if the keyboard goes out of focus, allow refocusing back onto it
	elif visible and current_focus is LineEdit and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if not line_edit.has_selection():
			print('selecting all')
			line_edit.select_all()
		select_first_key()

	# close the keyboard
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_keyboard()

	# submit text on enter
	elif event is InputEventKey and event.keycode == KEY_ENTER:
		get_viewport().set_input_as_handled()
		hide_keyboard()
		line_edit.text_submitted.emit(line_edit.text)

	# clear text on backspace
	elif event is InputEventKey and event.keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		line_edit.clear()

	# add text for any normal key events
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
		if len(line_edit.text) == line_edit.max_length:
			line_edit.clear()
			line_edit.insert_text_at_caret(char(event.unicode))
			line_edit.text_changed.emit(line_edit.text)
		else:
			if line_edit.has_selection():
				line_edit.clear()
			line_edit.insert_text_at_caret(char(event.unicode))
			line_edit.text_changed.emit(line_edit.text)


func _init_keyboard():
	_create_keyboard(default_layout.data)
	if visible:
		hide_keyboard()


func show_keyboard():
	_show_keyboard()


func hide_keyboard(key_data=null):
	change_visibility(false)
	line_edit.grab_focus()


func _show_keyboard(key_data=null):
	change_visibility(true)


func change_visibility(value):
	if value:
		super.show()
	else:
		_set_caps_lock(false)
		super.hide()
	visibility_changed.emit()


func select_first_key():
	var vbox = current_layout.get_children()[0]
	var hbox = vbox.get_children()[0]
	var button = hbox.get_children()[0]
	button.grab_focus()


func _show_layout(layout):
	layout.show()
	current_layout = layout
	select_first_key()


func _hide_layout(layout):
	layout.hide()


func _switch_layout(key_data):
	prev_prev_layout = previous_layout
	previous_layout = current_layout
	
	layout_changed.emit(key_data.get("layout-name"))

	for layout in layouts:
		_hide_layout(layout)

	if key_data.get("layout-name") == "PREVIOUS-LAYOUT":
		if prev_prev_layout != null:
			_show_layout(prev_prev_layout)
			return

	for layout in layouts:
		if layout.get_meta("layout_name") == key_data.get("layout-name"):
			_show_layout(layout)
			return

	_set_caps_lock(false)


func _set_caps_lock(value: bool):
	uppercase = value
	for key in capslock_keys:
		if value:
			if key.get_draw_mode() != BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed
		else:
			if key.get_draw_mode() == BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed

	for key in keys:
		key.change_uppercase(value)


func _trigger_uppercase(key_data):
	uppercase = !uppercase
	_set_caps_lock(uppercase)


func _key_released(key_data):
	if key_data.has("output"):
		var key_value = key_data.get("output")

		###########################
		## DISPATCH InputEvent 
		###########################

		var input_event_key = InputEventKey.new()
		input_event_key.shift_pressed = uppercase
		input_event_key.alt_pressed = false
		input_event_key.meta_pressed = false
		input_event_key.ctrl_pressed = false
		input_event_key.pressed = true

		var key = KeyListHandler.get_key_from_string(key_value)
		if !uppercase && KeyListHandler.has_lowercase(key_value):
			key += 32

		input_event_key.keycode = key
		input_event_key.unicode = key

		Input.parse_input_event(input_event_key)

		###########################
		## DISABLE CAPSLOCK AFTER 
		###########################
		_set_caps_lock(false)


func _create_keyboard(layout_data):
	var data = layout_data

	var index = 0
	for layout in data.get("layouts"):

		var layout_container = PanelContainer.new()

		# SHOW FIRST LAYOUT ON DEFAULT
		if index > 0:
			layout_container.hide()
		else:
			current_layout = layout_container

		var layout_name = layout.get("name")
		layout_container.set_meta("layout_name", layout_name)
		layouts.push_back(layout_container)
		add_child(layout_container)

		var base_vbox = VBoxContainer.new()
		base_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		base_vbox.size_flags_vertical = SIZE_EXPAND_FILL
		# theme override for spacing
		base_vbox.add_theme_constant_override("separation", separation.y)

		for row in layout.get("rows"):

			var key_row = HBoxContainer.new()
			key_row.size_flags_horizontal = SIZE_EXPAND_FILL
			key_row.size_flags_vertical = SIZE_EXPAND_FILL
			key_row.add_theme_constant_override("separation", separation.x)

			for key in row.get("keys"):
				var new_key = KeyboardButton.new(key)

				new_key.set('theme_override_font_sizes/font_size', font_size)
				if font != null:
					new_key.set('theme_override_fonts/font', font)
				if font_color_normal != null:
					new_key.set('theme_override_colors/font_color', font_color_normal)
					new_key.set('theme_override_colors/font_hover_color', font_color_hover)
					new_key.set('theme_override_colors/font_pressed_color', font_color_pressed)
					new_key.set('theme_override_colors/font_disabled_color', font_color_normal)

				new_key.released.connect(_key_released)

				if key.has("type"):
					if key.get("type") == "switch-layout":
						new_key.released.connect(_switch_layout)
					elif key.get("type") == "special":
						pass
					elif key.get("type") == "special-shift":
						new_key.released.connect(_trigger_uppercase)
						new_key.toggle_mode = true
						capslock_keys.push_back(new_key)
					elif key.get("type") == "special-hide-keyboard":
						new_key.released.connect(hide_keyboard)

				# SET ICONS
				if key.has("display-icon"):
					var icon_data = str(key.get("display-icon")).split(":")
					# PREDEFINED
					if str(icon_data[0])=="PREDEFINED":
						if str(icon_data[1])=="DELETE":
							new_key.set_icon(ICON_DELETE)
						elif str(icon_data[1])=="SHIFT":
							new_key.set_icon(ICON_SHIFT)
						elif str(icon_data[1])=="LEFT":
							new_key.set_icon(ICON_LEFT)
						elif str(icon_data[1])=="RIGHT":
							new_key.set_icon(ICON_RIGHT)
						elif str(icon_data[1])=="HIDE":
							new_key.set_icon(ICON_HIDE)
						elif str(icon_data[1])=="ENTER":
							new_key.set_icon(ICON_ENTER)
					# CUSTOM
					if str(icon_data[0])=="res":
						var texture = load(key.get("display-icon"))
						new_key.set_icon(texture)

					if font_color_normal != null:
						new_key.set_icon_color(font_color_normal)

				key_row.add_child(new_key)
				keys.push_back(new_key)

			base_vbox.add_child(key_row)

		layout_container.add_child(base_vbox)
		index += 1
