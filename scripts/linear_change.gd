extends Node

func _ready() -> void:
	%LinearSlider.connect("value_changed", _on_value_changed)

func _on_value_changed(value: float) -> void:
	%LinearValue.text = "%.1f" % value
	%ImageProcessor.update_image()
