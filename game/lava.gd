extends Area2D

@export var rise_speed = 32.0  # Pixels per second

@onready var lava_collision = $CollisionShape2D
@onready var lava_sprite = $LavaSprite
@onready var lava_particles = $GPUParticles2D


func _ready() -> void:
	lava_sprite.scale.y = 0.1
	lava_collision.shape.distance = 32


func _physics_process(delta):
	lava_sprite.scale.y += rise_speed * delta
	lava_sprite.get_material().set_shader_parameter("rect_size", Vector2(1920.0, lava_sprite.scale.y))
	lava_collision.shape.distance = lava_sprite.scale.y
	lava_particles.position.y = lava_sprite.position.y - lava_sprite.scale.y - 24
