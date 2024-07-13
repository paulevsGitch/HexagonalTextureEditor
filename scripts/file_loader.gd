extends FileDialog

func _ready() -> void:
	connect("file_selected", _on_file_selected)

func  _on_file_selected(path: String) -> void:
	%ImagePath.text = path
	%ImageProcessor.load_image(path)
