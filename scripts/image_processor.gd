extends Node

@export var texture_material: ShaderMaterial

var _can_update: bool

func load_image(path: String) -> void:
	var source_img = Image.load_from_file(path)
	if source_img.get_width() != source_img.get_height():
		%TextureWarning.show()
		_can_update = false
	else:
		%TextureWarning.hide()
		texture_material.set_shader_parameter("sourceImage", ImageTexture.create_from_image(source_img))
		%PreviewViewport.size = source_img.get_size()
		%RenderViewport.size = source_img.get_size()
		_can_update = true
		update_image()

func load_side(path: String) -> void:
	var side_img = Image.load_from_file(path)
	var texture := ImageTexture.create_from_image(side_img)
	%SidePreview.texture = texture
	texture_material.set_shader_parameter("sideImage", texture)

func save_image(path: String) -> void:
	var img = %RenderViewport.get_texture().get_image()
	Thread.new().start(_save_image_thread.bind(img, path, %SavePath))

func update_image() -> void:
	var solidValue = int(%SolidValue.text)
	%SolidValue.text = str(solidValue)
	%SolidValue.caret_column = %SolidValue.text.length()
	
	var blendValue = int(%BlendValue.text)
	%BlendValue.text = str(blendValue)
	%BlendValue.caret_column = %BlendValue.text.length()
	
	if not _can_update: return
	
	texture_material.set_shader_parameter("imageMode", %InterpolationMode.current_tab)
	texture_material.set_shader_parameter("pixelMode", %PixelMode.selected)
	texture_material.set_shader_parameter("gradientMode", %GradientMode.selected)
	texture_material.set_shader_parameter("gradientPower", %LinearSlider.value)
	texture_material.set_shader_parameter("solidValue", solidValue)
	texture_material.set_shader_parameter("blendValue", blendValue)
	texture_material.set_shader_parameter("sideMode", %SideMode.selected)
	texture_material.set_shader_parameter("sidesBlend", %SidesBlend.value)

func _save_image_thread(img: Image, path: String, path_text: LineEdit) -> void:
	if not _can_update: return
	path_text.set_deferred("text", "Saving...")
	img.save_png(path)
	path_text.set_deferred("text", path)
