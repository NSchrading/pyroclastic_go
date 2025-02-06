extends Sprite2D

class_name Scroll

@onready var sprite = $Sprite2D
@onready var collision_area = $Area2D
@onready var effect_timer = $EffectTimer
@onready var character_body = null
@onready var scroll_effect = true
@onready var scroll_text = ""
@onready var move_random = true
@onready var move_mult = 1.0

var viewport_size = 0.0

const velocity =  Vector2.ZERO
const FALL_SPEED = 150.0


func _ready() -> void:
	viewport_size = get_viewport().get_visible_rect().size
	set_effect(true)


func set_effect(effect: bool):
	scroll_effect = effect


func set_text(text: String):
	scroll_text = text


func _physics_process(delta: float) -> void:
	if is_instance_valid(self) and global_position.y > viewport_size.y:
		queue_free()
	if visible:
		position += FALL_SPEED * Vector2.DOWN * delta
		if move_random:
			position.x += [0.0, 1.0, 2.0, 3.0, -1.0, -2.0, -3.0].pick_random()
		else:
			position.x += 2.0 * move_mult
			move_mult *= -1.0


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		character_body = body
		body.apply_scroll_effect(self)
		effect_timer.start()
		# make scroll uncollidable
		collision_area.queue_free()
		# but keep it in existence to remove scroll effect after timeout
		visible = false


func _on_effect_timer_timeout() -> void:
	print('removing scroll effect')
	character_body.remove_scroll_effect(self)
	if is_instance_valid(self):
		queue_free()
