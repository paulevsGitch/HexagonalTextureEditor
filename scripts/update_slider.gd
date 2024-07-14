extends Slider

@export var value_text: Label

func _ready() -> void:
	connect("value_changed", _on_value_changed)

func _on_value_changed(value: float) -> void:
	value_text.text = "%.1f" % value
	%ImageProcessor.update_image()
