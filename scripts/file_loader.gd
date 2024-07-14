extends FileDialog

var _load_type := 0

func _ready() -> void:
	connect("file_selected", _on_file_selected)

func  _on_file_selected(path: String) -> void:
	if _load_type == 0:
		%ImagePath.text = path
		%ImageProcessor.load_image(path)
	else:
		%SidePath.text = path
		%ImageProcessor.load_side(path)

func _set_source_image_loading() -> void:
	_load_type = 0

func _set_side_image_loading() -> void:
	_load_type = 1
