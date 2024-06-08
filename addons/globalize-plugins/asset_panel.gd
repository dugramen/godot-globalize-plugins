@tool
extends PopupPanel

signal asset_id_pressed(asset: Dictionary)

#@onready var http := $HTTPRequest
@onready var item_container := %ItemContainer
@onready var line_edit := %SearchBrowse
@onready var globalized_items_container: GridContainer = %GlobalizedItems
@onready var tab_container: TabContainer = %TabContainer

const asset_item_scene := preload("res://addons/globalize-plugins/asset_item.tscn")
#const editor_key := "global_plugins/assets"
var editor_plugins := {}

func _ready():
	#if EditorInterface.get_editor_settings().has_setting(editor_key):
		#editor_plugins = EditorInterface.get_editor_settings().get_setting(editor_key)
	
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
			#var label_title = node.get_node("%Title") as Label
			#var label_author = node.get_node("%Author") as Label
			#var label_version = node.get_node("%Version") as Label
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
					globalize_item(item)
					handle_button_visibility.call()
			)
			button_delete.pressed.connect(
				func():
					unglobalize_item(item)
					handle_button_visibility.call()
			)
			
			var texture := await load_image(item.icon_url)
			if texture:
				icon.texture = texture

func get_asset_path(item) -> String:
	var config_path := EditorInterface.get_editor_paths().get_config_dir()
	var g_path: String = config_path + "/globalized/" + item.title
	return g_path

func globalize_item(item):
	var g_path := get_asset_path(item)
	#var version := Engine.get_version_info()
	#g_path += str(version.major) + "." + str(version.minor)
	print(g_path)
	DirAccess.make_dir_recursive_absolute(g_path)
	if !FileAccess.file_exists(g_path + "/project.godot"):
		var file := FileAccess.open(g_path + "/project.godot", FileAccess.WRITE)
		file.close()

func unglobalize_item(item):
	var item_path := get_asset_path(item)
	OS.move_to_trash(item_path)

func load_image(url) -> ImageTexture:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url)
	var response = await http.request_completed
	var handler := func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS:
			push_error("Couldn't get image at ", url)
			return null
		else:
			var image = Image.new()
			var extension: String = url.get_extension()
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
				return null
			else:
				return ImageTexture.create_from_image(image)
	return handler.callv(response)

func spawn_current_globalized_items():
	#if EditorInterface.get_editor_settings().has_setting(editor_key):
		#var data: Dictionary = EditorInterface.get_editor_settings().get_setting(editor_key)
		#print("found ", data.values())
	spawn_items(editor_plugins.values(), globalized_items_container, func(item): pass)

func _on_search_saved_text_changed(new_text):
	print(new_text)
	
