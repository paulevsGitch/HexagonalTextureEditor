extends Node

func _ready() -> void:
	%SolidValue.connect("text_changed", _text_changed)
	%BlendValue.connect("text_changed", _text_changed)

func _text_changed(_new_text: String) -> void:
	%ImageProcessor.update_image()
