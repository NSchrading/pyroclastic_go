extends ColorPicker

@export var style_normal: StyleBox
@export var style_focus: StyleBox
@onready var first_open: bool = true


func _on_focus_entered() -> void:
	# The first time we open the color picker, we need to modify it so it works with gamepads
	if first_open:
		# hide the spin boxes and input boxes
		var spin_boxes = find_children("*SpinBox*", "", true, false)
		for spin_box in spin_boxes:
			spin_box.visible = false
		var hsliders = find_children("*HSlider*", "", true, false)
		if len(hsliders) > 0:
			var grid_container = hsliders[0].get_parent()
			# get rid of the spin box column
			grid_container.columns = 2
		for hslider in hsliders:
			if hslider.visible:
				# put the hslider into a panel so we can give it a style on focus
				var original_parent = hslider.get_parent()
				var original_index = hslider.get_index()
				original_parent.remove_child(hslider)
				var panel_container = PanelContainer.new()
				panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				panel_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				hslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hslider.size_flags_vertical = Control.SIZE_EXPAND_FILL
				panel_container.add_child(hslider)
				original_parent.add_child(panel_container)
				original_parent.move_child(panel_container, original_index)
				
				# make the slider focusable
				hslider.set_focus_mode(FOCUS_ALL)
				hslider.focus_entered.connect(_add_focus_style.bind(panel_container))
				hslider.focus_exited.connect(_remove_focus_style.bind(panel_container))
				panel_container.add_theme_stylebox_override("panel", style_normal)
		first_open = false
		if len(hsliders) > 0:
			hsliders[0].grab_focus()
	else:
		var hsliders = find_children("*HSlider*", "", true, false)
		if len(hsliders) > 0:
			hsliders[0].grab_focus()


func _add_focus_style(panel_container):
	panel_container.add_theme_stylebox_override("panel", style_focus)


func _remove_focus_style(panel_container):
	panel_container.add_theme_stylebox_override("panel", style_normal)
