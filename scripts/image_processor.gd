extends Node

const _rot_angle_a = deg_to_rad(30)
const _rot_angle_b = deg_to_rad(90)
const _sqrt_3 = 1.0 / sqrt(3.0)
const _width_scale = 3.0 / (2.0 * sqrt(3.0))

var source_image : Image
var result : Image
var _thread : Thread

var _image_mode: int
var _pixel_mode: int
var _gradient_mode: int
var _power: float
var _offset: int
var _blend: int

func load_image(path: String) -> void:
	source_image = Image.load_from_file(path)
	if source_image.get_width() != source_image.get_height():
		%TextureWarning.show()
		source_image = null
	else:
		%TextureWarning.hide()
		update_image()

func save_image(path: String) -> void:
	result.save_png(path)

func update_image() -> void:
	_offset = int(%SolidValue.text)
	%SolidValue.text = str(_offset)
	
	_blend = int(%BlendValue.text)
	%BlendValue.text = str(_blend)
	
	if source_image == null: return
	
	_image_mode = %InterpolationMode.current_tab
	_pixel_mode = %PixelMode.selected
	_gradient_mode = %GradientMode.selected
	_power = %LinearSlider.value
	
	#if _thread != null and _thread.is_alive(): OS.kill(_thread)
	_thread = Thread.new()
	
	%TextureUpdating.show()
	_thread.start(_update_image_thread.bind(%MainTexture, %TextureUpdating))

func _update_image_thread(main_texture: TextureRect, texture_update: Control) -> void:
	var sides = _copy_image(source_image)
	result = _copy_image(source_image)
	
	match _image_mode:
		0:
			_apply_gradient(sides)
		1:
			_apply_remove(sides)
	
	sides = _merge_image_down(sides)
	_apply_triangle(sides)
	
	var sides_rot = _rotate_image(sides, _rot_angle_a)
	_blend_images(result, sides_rot)
	
	sides_rot = _rotate_image(sides, -_rot_angle_a)
	_blend_images(result, sides_rot)
	
	sides_rot = _rotate_image(sides, _rot_angle_b)
	_blend_images(result, sides_rot)
	
	main_texture.set_deferred("texture", ImageTexture.create_from_image(result))
	texture_update.call_deferred("hide")

func _copy_image(img: Image) -> Image:
	var side := img.get_width()
	var result = Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in range(0, side):
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

func _apply_remove(img: Image) -> void:
	var side := img.get_width()
	var half = side >> 1
	var last_y = side - _offset
	for y in range(_offset, last_y):
		var blend := 0.0
		if _blend > 0:
			if y < half:
				blend = max(0.0, 1.0 - float(y - _offset) / _blend)
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
