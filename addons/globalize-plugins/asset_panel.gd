@tool
extends PopupPanel

signal asset_id_pressed(asset_id: int)

@onready var http := $HTTPRequest
@onready var item_container := %ItemContainer
@onready var line_edit := $MarginContainer/VBoxContainer/LineEdit

var should_rescan := false

func _exit_tree():
	if should_rescan and Engine.has_singleton("EditorInterface"):
		var efs = EditorInterface.get_resource_filesystem()
		if efs:
			print("is scanning")
			efs.scan()


func _on_line_edit_text_submitted(new_text):
	var url := "https://godotengine.org/asset-library/api/asset?godot_version=%s&filter=%s" % [
		"%s.%s" % [Engine.get_version_info().major, Engine.get_version_info().minor],
		new_text
	]
	print("Getting line ", url)
	var error = http.request(url)
	if error != OK:
		push_error("request invalid")
	
	http.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			var json := JSON.new()
			var err = json.parse(body.get_string_from_utf8())
			var data = json.data
			#print(data)
			spawn_items(data.result)
	)

func spawn_items(items: Array):
	for child in item_container.get_children():
		child.queue_free()
	
	for item in items:
		var item_name = item.get("title", null)
		if item_name is String:
			var button := Button.new()
			button.text = item_name
			button.text += '\n- ' + item.get("author", "")
			item_container.add_child(button)
			#print(item)
			button.add_theme_constant_override("icon_max_width", 32)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func(): 
				asset_id_pressed.emit(item.asset_id)
				should_rescan = true
			)
			#button.pressed.connect(on_item_pressed.bind(item.asset_id))
			
			if item.has("icon_url"):
				var _http := HTTPRequest.new()
				button.add_child(_http)
				_http.request(item.icon_url)
				_http.request_completed.connect(
					func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
						if result != HTTPRequest.RESULT_SUCCESS:
							push_error("Couldn't get image at ", item.icon_url)
						else:
							var image = Image.new()
							var extension: String = item.icon_url.get_extension()
							var error;
							match extension:
								"png":
									error = image.load_png_from_buffer(body)
								"jpg":
									error = image.load_jpg_from_buffer(body)
								"svg":
									error = image.load_svg_from_buffer(body)
								"webp":
									error = image.load_webp_from_buffer(body)
								"bmp":
									error = image.load_bmp_from_buffer(body)
								_:
									error = image.load_png_from_buffer(body)
							if error != OK:
								push_error("Couldn't load the image.")
							else:
								var texture = ImageTexture.create_from_image(image)
								button.icon = texture
				)

