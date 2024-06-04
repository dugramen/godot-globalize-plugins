@tool
extends PopupPanel

@onready var http := $HTTPRequest
@onready var item_container := %ItemContainer

# Called when the node enters the scene tree for the first time.
func _ready():
	#DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://addons/globalize-plugins/hello/word/there/pro/"))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


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
			button.pressed.connect(on_item_pressed.bind(item))
			
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
							var error = image.load_png_from_buffer(body)
							if error != OK:
								push_error("Couldn't load the image.")
							else:
								var texture = ImageTexture.create_from_image(image)
								button.icon = texture
				)

func on_item_pressed(item: Dictionary):
	var _http := HTTPRequest.new()
	add_child(_http)
	var err := _http.request("https://godotengine.org/asset-library/api/asset/%s" % item.asset_id)
	_http.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			if result != HTTPRequest.RESULT_SUCCESS:
				push_error("Failed to get asset ", item.asset_id, ' ', item.title)
				return
			var data = JSON.parse_string(body.get_string_from_utf8())
			print(data)
			on_asset_data(data)
	)

func on_asset_data(asset: Dictionary):
	var _http := HTTPRequest.new()
	add_child(_http)
	var err := _http.request(asset.download_url)
	_http.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			if result != HTTPRequest.RESULT_SUCCESS:
				push_error("Download failed from ", asset.download_url)
				return
			var base_path := "res://addons/globalize-plugins/temp/"
			var file_path: String = base_path + "download.zip"
			#var file_path: String = "res://addons/globalize-plugins/temp/" + asset.title + ".zip"
			var file := FileAccess.open(file_path, FileAccess.WRITE)
			file.store_buffer(body)
			file.close()
			var zipper := ZIPReader.new()
			zipper.open(file_path)
			var zipped_files := zipper.get_files()
			for path in zipped_files:
				var content := zipper.read_file(path)
				var final_path := base_path + path
				var g_path := ProjectSettings.globalize_path(final_path)
				print(final_path)
				DirAccess.remove_absolute(g_path)
				if final_path.ends_with("/"):
					print(g_path)
					err = DirAccess.make_dir_recursive_absolute(g_path)
					if err != OK:
						push_error("Could not make directory ", final_path)
				else:
					var zfile := FileAccess.open(base_path + path, FileAccess.WRITE)
					zfile.store_buffer(content)
					zfile.close()
			zipper.close()
	)
