@tool
extends PopupPanel

signal asset_id_pressed(asset: Dictionary)

#@onready var http := $HTTPRequest
@onready var item_container := %ItemContainer
@onready var line_edit := %SearchBrowse
@onready var globalized_items_container: GridContainer = %GlobalizedItems
@onready var tab_container: TabContainer = %TabContainer

const asset_item_scene := preload("res://addons/globalize-plugins/asset_item.tscn")
const editor_key := "global_plugins/assets"
var editor_plugins := {}

func _ready():
	if EditorInterface.get_editor_settings().has_setting(editor_key):
		editor_plugins = EditorInterface.get_editor_settings().get_setting(editor_key)
	
	var spawned := false
	globalized_items_container.visibility_changed.connect(
		func():
			if spawned: return
			if globalized_items_container.visible:
				spawn_current_globalized_items()
				spawned = true
	)

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
			spawn_items(data.result, item_container, 
				func(item): 
					asset_id_pressed.emit(item)
					#tab_container.current_tab = 1
			)
	)

func spawn_items(items: Array, container: GridContainer, pressed_handler: Callable):
	for child in container.get_children():
		child.queue_free()
	
	for item in items:
		var item_name = item.get("title", null)
		if item_name is String:
			var node := asset_item_scene.instantiate()
			container.add_child(node)
			
			var info: RichTextLabel = node.get_node("%Info") as RichTextLabel
			var label_title = node.get_node("%Title") as Label
			var label_author = node.get_node("%Author") as Label
			var label_version = node.get_node("%Version") as Label
			var button_update = node.get_node("%Update") as Button
			var button_delete = node.get_node("%Delete") as Button
			var button_add = node.get_node("%Add") as Button
			var icon = node.get_node("%Icon") as TextureRect
			
			info.clear()
			info.add_text(item.title + "\n")
			info.push_font_size(12)
			info.push_color(Color(Color.WHITE, .5))
			info.add_text(item.author + "\n" + item.version_string)
			
			var handle_button_visibility := func():
				if editor_plugins.has(item.asset_id):
					button_add.visible = false
					button_delete.visible = true
					button_update.visible = true
				else:
					button_add.visible = true
					button_delete.visible = false
					button_update.visible = false
			
			handle_button_visibility.call()
			button_add.pressed.connect(
				func():
					editor_plugins[item.asset_id] = item
					handle_button_visibility.call()
			)
			button_delete.pressed.connect(
				func():
					editor_plugins.erase(item.asset_id)
					handle_button_visibility.call()
			)
			
			#label_title.text = item.title
			#label_author.text = item.author
			#label_version.text = item.version_string
			
			#var button := CheckButton.new()
			#button.text = item_name
			#button.text += '\n - ' + item.get("author", "")
			#container.add_child(button)
			##print(item)
			#button.add_theme_constant_override("icon_max_width", 32)
			#button.add_theme_constant_override("h_separation", 8)
			#button.add_theme_stylebox_override("normal", button.get_theme_stylebox("normal", "Button"))
			#button.add_theme_stylebox_override("pressed", button.get_theme_stylebox("pressed", "Button"))
			#button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			##button.pressed.connect(pressed_handler.bind(item))
			#button.button_pressed = editor_plugins.has(item.asset_id)
			#button.toggled.connect(
				#func(val):
					#if val:
						#editor_plugins[item.asset_id] = item
					#else:
						#editor_plugins.erase(item.asset_id)
			#)
			##button.pressed.connect(func(): 
				##asset_id_pressed.emit(item)
			##)
			#button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			#button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			##button.pressed.connect(on_item_pressed.bind(item.asset_id))
			
			var _http := HTTPRequest.new()
			add_child(_http)
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
							icon.texture = texture
			)

func spawn_current_globalized_items():
	#if EditorInterface.get_editor_settings().has_setting(editor_key):
		#var data: Dictionary = EditorInterface.get_editor_settings().get_setting(editor_key)
		#print("found ", data.values())
	spawn_items(editor_plugins.values(), globalized_items_container, func(item): pass)

func _on_search_saved_text_changed(new_text):
	print(new_text)
	
