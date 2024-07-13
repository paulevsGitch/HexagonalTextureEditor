extends Node

const _rot_angle_a := deg_to_rad(30)
const _rot_angle_b := deg_to_rad(90)
const _sqrt_3 := 1.0 / sqrt(3.0)
const _width_scale := 3.0 / (2.0 * sqrt(3.0))
const _preview_size := 150

var _source_image: Image
var _preview: Image
var _prev_scale: float

var _image_mode: int
var _pixel_mode: int
var _gradient_mode: int
var _power: float
var _offset: int
var _blend: int

func load_image(path: String) -> void:
	_source_image = Image.load_from_file(path)
	if _source_image.get_width() != _source_image.get_height():
		%TextureWarning.show()
		_source_image = null
	else:
		%TextureWarning.hide()
		var side = _source_image.get_width()
		var prev_side = min(_preview_size, side)
		_preview = Image.create(prev_side, prev_side, false, Image.FORMAT_RGBA8)
		_prev_scale = float(side) / float(prev_side)
		print(prev_side, " ", side, " ", _prev_scale)
		for x in range(prev_side):
			var px = int(float(x) * _prev_scale)
			for y in range(prev_side):
				var py = int(float(y) * _prev_scale)
				var color = _source_image.get_pixel(px, py)
				_preview.set_pixel(x, y, color)
		update_image()

func save_image(path: String) -> void:
	Thread.new().start(_save_image_thread.bind(path, %SavePath))

func update_image() -> void:
	_offset = int(%SolidValue.text)
	%SolidValue.text = str(_offset)
	%SolidValue.caret_column = %SolidValue.text.length()
	
	_blend = int(%BlendValue.text)
	%BlendValue.text = str(_blend)
	%BlendValue.caret_column = %BlendValue.text.length()
	
	if _source_image == null: return
	
	_image_mode = %InterpolationMode.current_tab
	_pixel_mode = %PixelMode.selected
	_gradient_mode = %GradientMode.selected
	_power = %LinearSlider.value
	
	%TextureUpdating.show()
	Thread.new().start(_update_image_thread.bind(%MainTexture, %TextureUpdating))

func _save_image_thread(path: String, path_text: LineEdit) -> void:
	path_text.set_deferred("text", "Saving...")
	var result := _process_image(_source_image, 1.0)
	result.save_png(path)
	path_text.set_deferred("text", path)

func _update_image_thread(main_texture: TextureRect, texture_update: Control) -> void:
	var result := _process_image(_preview, 1.0 / _prev_scale)
	main_texture.set_deferred("texture", ImageTexture.create_from_image(result))
	texture_update.call_deferred("hide")

func _process_image(img: Image, scale: float) -> Image:
	var sides = _copy_image(img)
	var result = _copy_image(img)
	
	match _image_mode:
		0:
			_apply_gradient(sides)
		1:
			_apply_remove(sides, scale)
	
	sides = _merge_image_down(sides)
	_apply_triangle(sides)
	
	var sides_rot = _rotate_image(sides, _rot_angle_a)
	_blend_images(result, sides_rot)
	
	sides_rot = _rotate_image(sides, -_rot_angle_a)
	_blend_images(result, sides_rot)
	
	sides_rot = _rotate_image(sides, _rot_angle_b)
	_blend_images(result, sides_rot)
	
	return result

func _copy_image(img: Image) -> Image:
	var side := img.get_width()
	var result = Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in range(side):
		for x in range(side):
			result.set_pixel(x, y, img.get_pixel(x, y))
	return result

func _apply_gradient(img: Image) -> void:
	var side := img.get_width()
	var half = side * 0.5
	if _gradient_mode == 0:
		for y in range(0, side):
			var grad = abs(y - half) / half
			grad = max(grad * 1.5 - 0.5, 0.0)
			grad = pow(grad, _power)
			for x in range(side):
				var color := img.get_pixel(x, y)
				color.a *= grad
				img.set_pixel(x, y, color)
	else:
		for y in range(0, half):
			var y2 = y / half# * 3.0
			y2 *= y2
			for x in range(side):
				var x2 = x / half - 1.0
				x2 *= x2
				var color := img.get_pixel(x, y)
				color.a *= pow(1.0 - min(sqrt(y2 + x2), 1.0), _power)
				img.set_pixel(x, y, color)
		for y in range(half, side):
			var y2 = (side - y - 1) / half# * 3.0
			y2 *= y2
			for x in range(side):
				var x2 = x / half - 1.0
				x2 *= x2
				var color := img.get_pixel(x, y)
				color.a *= pow(1.0 - min(sqrt(y2 + x2), 1.0), _power)
				img.set_pixel(x, y, color)

func _apply_remove(img: Image, scale: float) -> void:
	var side := img.get_width()
	var half = side >> 1
	var offset = _offset * scale
	var last_y = side - offset
	for y in range(offset, last_y):
		var blend := 0.0
		if _blend > 0:
			if y < half:
				blend = max(0.0, 1.0 - float(y - offset) / _blend)
			else:
				blend = max(0.0, 1.0 - float(last_y - y) / _blend)
		for x in range(side):
			var color := img.get_pixel(x, y)
			color.a *= blend
			img.set_pixel(x, y, color)

func _apply_triangle(img: Image) -> void:
	var side := img.get_width()
	var max_side := side - 1
	var half = side >> 1 | 1
	
	for y in range(0, side):
		var t_side = floor(abs(half - y) * _sqrt_3)
		var xmin = max(0, half - t_side - 1)
		var xmax = min(max_side, half + t_side + 1)
		for x in range(0, xmin):
			var color := img.get_pixel(x, y)
			color.a = 0.0
			img.set_pixel(x, y, color)
		for x in range(xmax, side):
			var color := img.get_pixel(x, y)
			color.a = 0.0
			img.set_pixel(x, y, color)

func _merge_image_down(img: Image) -> Image:
	var side := img.get_width()
	var result := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var max_side := side - 1
	var half = side >> 1
	var offset = floor((side - side * _width_scale) * 0.5)
	var max_offset = side - offset - 1
	var color: Color
	var y2: int
	
	for y in range(half, -1, -1):
		if _pixel_mode == 1:
			y2 = wrap(y - offset, 0, max_side)
		else:
			y2 = clamp(y - offset, 0, max_side)
		for x in range(side):
			color = img.get_pixel(x, y2)
			if _pixel_mode == 2 and y <= offset: color.a = 0
			result.set_pixel(x, y, color)
	
	for y in range(half, side):
		if _pixel_mode == 1:
			y2 = wrap(y + offset, 0, max_side)
		else:
			y2 = clamp(y + offset, 0, max_side)
		for x in range(side):
			color = img.get_pixel(x, y2)
			if _pixel_mode == 2 and y >= max_offset: color.a = 0
			result.set_pixel(x, y, color)
	
	return result

func _get_color(img: Image, pos: Vector2, max_side: int) -> Color:
	var x1 = floor(pos.x)
	var y1 = floor(pos.y)
	var dx = pos.x - x1
	var dy = pos.y - y1
	var x2 = x1 + 1
	var y2 = y1 + 1
	
	if _pixel_mode == 1:
		x1 = wrap(x1, 0, max_side)
		y1 = wrap(y1, 0, max_side)
		x2 = wrap(x2, 0, max_side)
		y2 = wrap(y2, 0, max_side)
	else:
		x1 = clamp(x1, 0, max_side)
		y1 = clamp(y1, 0, max_side)
		x2 = clamp(x2, 0, max_side)
		y2 = clamp(y2, 0, max_side)
	
	var a = img.get_pixel(x1, y1)
	var b = img.get_pixel(x2, y1)
	var c = img.get_pixel(x1, y2)
	var d = img.get_pixel(x2, y2)
	
	a = a + (b - a) * dx
	b = c + (d - c) * dx
	
	return a + (b - a) * dy

func _rotate_image(img: Image, angle: float) -> Image:
	var side := img.get_width()
	var result := Image.create(side, side, false, img.get_format())
	var offset := side * 0.5
	var offsetV := Vector2(offset, offset)
	var transform := Transform2D.IDENTITY.translated_local(offsetV).rotated_local(angle).translated_local(-offsetV);
	var max_side := side - 1
	
	for x in range(side):
		for y in range(side):
			var pixelPos := transform * Vector2(x, y)
			var color := _get_color(img, pixelPos, max_side)
			result.set_pixel(x, y, color)
	
	return result

func _blend_images(imgBottom: Image, imgTop: Image) -> void:
	var side := imgBottom.get_width()
	for x in range(side):
		for y in range(side):
			var color1 = imgBottom.get_pixel(x, y)
			var color2 = imgTop.get_pixel(x, y)
			color1.a = max(color1.a, color2.a)
			color1.r = lerp(color1.r, color2.r, color2.a)
			color1.g = lerp(color1.g, color2.g, color2.a)
			color1.b = lerp(color1.b, color2.b, color2.a)
			imgBottom.set_pixel(x, y, color1)
