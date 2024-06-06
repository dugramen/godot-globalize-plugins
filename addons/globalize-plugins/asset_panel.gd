@tool
extends PopupPanel

signal asset_id_pressed(asset: Dictionary)

#@onready var http := $HTTPRequest
@onready var item_container := %ItemContainer
@onready var line_edit := %SearchBrowse
@onready var globalized_items_container: GridContainer = %GlobalizedItems

func _on_line_edit_text_submitted(new_text):
	var url := "https://godotengine.org/asset-library/api/asset?godot_version=%s&filter=%s" % [
		"%s.%s" % [Engine.get_version_info().major, Engine.get_version_info().minor],
		new_text
	]
	print("Getting line ", url)
	var http := HTTPRequest.new()
	add_child(http)
	var error = http.request(url)
	if error != OK:
		push_error("request invalid")
		return
	
	http.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			var json := JSON.new()
			var err = json.parse(body.get_string_from_utf8())
			var data = json.data
			#print(data)
			spawn_items(data.result, item_container, func(item): asset_id_pressed.emit(item))
	)

func spawn_items(items: Array, container: GridContainer, pressed_handler: Callable):
	for child in container.get_children():
		child.queue_free()
	
	for item in items:
		var item_name = item.get("title", null)
		if item_name is String:
			var button := Button.new()
			button.text = item_name
			button.text += '\n - ' + item.get("author", "")
			container.add_child(button)
			#print(item)
			button.add_theme_constant_override("icon_max_width", 32)
			button.add_theme_constant_override("h_separation", 8)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(pressed_handler.bind(item))
			#button.pressed.connect(func(): 
				#asset_id_pressed.emit(item)
			#)
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func _on_search_saved_text_changed(new_text):
	print(new_text)
	if EditorInterface.get_editor_settings().has_setting("global_plugins/assets"):
		var data: Dictionary = EditorInterface.get_editor_settings().get_setting("global_plugins/assets")
		print("found ", data.values())
		spawn_items(data.values(), globalized_items_container, func(item): pass)
