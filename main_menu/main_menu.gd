extends Control

@export var menu_container: PanelContainer
@export var button_container: VBoxContainer
@export var new_game_button: Button
@export var retry_button: Button
@export var resume_button: Button
@export var quit_button: Button
@export var random_seed_input: LineEdit
@export var randomize_seed_button: TextureButton
@export var dice_animation: AnimationPlayer
@export var seed_submit_button: Button
@export var score_table: Table
@export var on_screen_keyboard: PanelContainer
@export var open_source_licenses: Button
@export var license_container: AcceptDialog
@export var title_text: RichTextLabel
@export var title_text_particles: GPUParticles2D
@export var title_text_animation: AnimationPlayer


func _ready() -> void:
	new_game_button.grab_focus()
	license_container.get_label().horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	license_container.dialog_text += Engine.get_license_text()
	license_container.dialog_text +=  "\nFonts\n"
	license_container.dialog_text += "Roman SD: Created by Steve Deffeyes; www.deffeyes.com\n"
	license_container.dialog_text += "Romanus: Created by Zamjump; https://zamjump.com/index.php/product/romanus/\n"
	license_container.dialog_text += "Romanica: Created by Keith Bates; www.k-type.com\n"
	license_container.dialog_text += "P39: Created by Allan Loder; http://individual.utoronto.ca/atloder/uncialfonts.html\n"
	license_container.dialog_text += "DIOGENES: Created by Apostrophic Labs; https://www.dafont.com/diogenes.font\n"
	title_text_animation.play("fun_text")


func _on_open_source_licenses_button_pressed() -> void:
	if !license_container.visible:
		license_container.popup_centered()
	else:
		license_container.hide()
