extends Node

func _ready() -> void:
	%LinearSlider.connect("drag_ended", _on_drag_ended)
	%LinearSlider.connect("value_changed", _on_value_changed)

func _on_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	%ImageProcessor.update_image()

func _on_value_changed(value: float) -> void:
	%LinearValue.text = "%.1f" % value
