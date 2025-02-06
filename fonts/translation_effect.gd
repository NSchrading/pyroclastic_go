@tool
extends RichTextEffect
class_name TranslationEffect

var bbcode = "translation"
const DEFAULT_COLOR = "#310000"
const TRANSLATED_COLOR = "#5a0000"

# Expose a variable that we can tween so we can fade in/out characters
@export var current_alpha: float = 1.0


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var target_color: Color = char_fx.env.get("color", Color(DEFAULT_COLOR))

	char_fx.color.r = target_color.r
	char_fx.color.g = target_color.g
	char_fx.color.b = target_color.b
	char_fx.color.a = current_alpha

	return true
