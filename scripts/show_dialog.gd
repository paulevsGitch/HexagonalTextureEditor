extends Button

@export var dialog: FileDialog

func _ready() -> void:
	connect("pressed", _on_pressed)

func _on_pressed() -> void:
	dialog.show()