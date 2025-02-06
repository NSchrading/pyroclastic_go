extends Control
class_name Table

@onready var table_rows: VBoxContainer = $MarginContainer/HBoxContainer/ScrollContainer/TableRows
@onready var scroll_container: ScrollContainer = $MarginContainer/HBoxContainer/ScrollContainer
@onready var table_row_scene = preload("res://main_menu/table_row.tscn")
@onready var scroll_bar = scroll_container.get_v_scroll_bar()
@onready var moving_cursor = false
@onready var delta_counter = 0.0
@onready var confirm_dialog: ConfirmationDialog = $MarginContainer/ConfirmationDialog

signal delete_row(seed: String)


func add_row(seed_val: String, high_score: String, time: String) -> void:
	var new_row: TableRow = table_row_scene.instantiate() as TableRow
	table_rows.add_child(new_row)
	new_row.set_row(seed_val, high_score, time)


func _physics_process(delta):
	# _physics_process is handling input along with _input because we want to handle the user
	# pressing and holding a controller button up or down to scroll along the table rows
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus is TableRow:
		if Input.is_action_just_released("ui_down") or Input.is_action_just_released("ui_up"):
			get_viewport().set_input_as_handled()
			moving_cursor = false

		if not moving_cursor:
			delta_counter = 0.0

		else:
			delta_counter += delta
			if delta_counter >= 0.1:
				delta_counter = 0.0
			
				if Input.is_action_pressed("ui_down"):
					_move_table_cursor_down(current_focus)

				elif Input.is_action_pressed("ui_up"):
					_move_table_cursor_up(current_focus)


func _move_table_cursor_down(current_focus: TableRow):
	get_viewport().set_input_as_handled()
	var next_focus = current_focus.find_valid_focus_neighbor(SIDE_BOTTOM)
	if next_focus is Table:
		get_node(get_focus_neighbor(SIDE_BOTTOM)).grab_focus()
		moving_cursor = false
	elif next_focus is TableRow:
		next_focus.grab_focus()


func _move_table_cursor_up(current_focus: TableRow):
	get_viewport().set_input_as_handled()
	var next_focus = current_focus.find_valid_focus_neighbor(SIDE_TOP)
	if next_focus is Table:
		get_node(get_focus_neighbor(SIDE_TOP)).grab_focus()
		moving_cursor = false
	elif next_focus is TableRow:
		next_focus.grab_focus()


func _input(event: InputEvent):
	var current_focus = get_viewport().gui_get_focus_owner()
	
	if current_focus is TableRow:
		if event.is_action_pressed("ui_down"):
			_move_table_cursor_down(current_focus)
			moving_cursor = true

		elif event.is_action_pressed("ui_up"):
			_move_table_cursor_up(current_focus)
			moving_cursor = true
			
		elif event.is_action_pressed("ui_text_delete"):
			get_viewport().set_input_as_handled()
			confirm_dialog.popup_centered()


func _on_focus_entered() -> void:
	if len(table_rows.get_children()) > 0:
		table_rows.get_children()[0].grab_focus()


func _on_confirmation_dialog_confirmed() -> void:
	var row_to_delete = get_viewport().gui_get_focus_owner()
	var next_focus_bottom = row_to_delete.find_valid_focus_neighbor(SIDE_BOTTOM)
	var next_focus_top = row_to_delete.find_valid_focus_neighbor(SIDE_TOP)
	var seed_to_delete = row_to_delete.seed_node.text
	print('emitting delete_row on ' + str(row_to_delete) + ' (' + seed_to_delete + ')')
	table_rows.remove_child(row_to_delete)

	# try to move to the next row down
	if next_focus_bottom is TableRow:
		next_focus_bottom.grab_focus()
	# if there isn't a next row down, try to move to the next row up
	elif next_focus_top is TableRow:
		next_focus_top.grab_focus()
	# table must be empty, get the focus neighbor above the table
	else:
		get_node(get_focus_neighbor(SIDE_TOP)).grab_focus()
	
	delete_row.emit(seed_to_delete)
	row_to_delete.queue_free()
