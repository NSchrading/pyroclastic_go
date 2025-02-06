extends Control

@export var menu_container: PanelContainer
@export var new_game_button: Button
@export var retry_button: Button
@export var resume_button: Button
@export var quit_button: Button
@export var random_seed_input: LineEdit
@export var seed_submit_button: Button
@export var score_table: Table
@export var on_screen_keyboard: PanelContainer
@export var open_source_licenses: Button
@export var license_container: PanelContainer
@export var license_text: RichTextLabel
@export var title_text: RichTextLabel
@export var title_text_particles: GPUParticles2D
@export var title_text_animation: AnimationPlayer


func _ready() -> void:
	new_game_button.grab_focus()
	license_text.add_text(Engine.get_license_text())
	license_text.add_text("\nFonts\n")
	license_text.add_text("Roman SD: Created by Steve Deffeyes; www.deffeyes.com\n")
	license_text.add_text("Romanus: Created by Zamjump; https://zamjump.com/index.php/product/romanus/\n")
	license_text.add_text("Romanica: Created by Keith Bates; www.k-type.com\n")
	license_text.add_text("P39: Created by Allan Loder; http://individual.utoronto.ca/atloder/uncialfonts.html\n")
	license_text.add_text("DIOGENES: Created by Apostrophic Labs; https://www.dafont.com/diogenes.font\n")
	title_text_animation.play("fun_text")


func _on_open_source_licenses_button_pressed() -> void:
	license_container.visible = not license_container.visible
