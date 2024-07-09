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

var plugin

func _ready():
	transient = true
	exclusive = true
	popup_window = false
	
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.has_setting(editor_key):
		editor_plugins = editor_settings.get_setting(editor_key)
	
	var spawned := false
	globalized_items_container.visibility_changed.connect(
		func():
			if spawned: return
			if globalized_items_container.visible:
				spawn_current_globalized_items()
				spawned = true
	)

func _on_line_edit_text_submitted(txt = ""):
	var url := "https://godotengine.org/asset-library/api/asset?godot_version=%s&filter=%s" % [
		"%s.%s" % [Engine.get_version_info().major, Engine.get_version_info().minor],
		line_edit.text
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
			
			var buttons := [button_add, button_delete, button_update]
			
			var handle_button_visibility := func():
				button_add.disabled = false
				button_delete.disabled = false
				button_update.disabled = false
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
					for button in buttons:
						button.disabled = true
					await globalize_item(item)
					handle_button_visibility.call()
			)
			button_delete.pressed.connect(
				func():
					for button in buttons:
						button.disabled = true
					await unglobalize_item(item)
					handle_button_visibility.call()
			)
			
			var async_load_image := func():
				var texture := await load_image(item.icon_url)
				if texture:
					icon.texture = texture
			async_load_image.call()

func get_asset_path(item) -> String:
	var config_path := EditorInterface.get_editor_paths().get_config_dir()
	var g_path: String = config_path + "/globalized/" + str(item.asset_id) + " - " + item.title
	return g_path

func globalize_item(item):
	var g_path := get_asset_path(item)
	#var version := Engine.get_version_info()
	#g_path += str(version.major) + "." + str(version.minor)
	editor_plugins[item.asset_id] = item
	DirAccess.make_dir_recursive_absolute(g_path)
	if !FileAccess.file_exists(g_path + "/project.godot"):
		var file := FileAccess.open(g_path + "/project.godot", FileAccess.WRITE)
		file.close()
	await fetch_and_install_asset(item.asset_id)
	plugin.globalize_local_plugins()

func unglobalize_item(item):
	var item_path := get_asset_path(item)
	editor_plugins.erase(item.asset_id)
	await delete_dir_resursively(item_path)

func delete_dir_resursively(path: String):
	#print(path)
	#print(DirAccess.get_files_at(path))
	#print(DirAccess.get_directories_at(path))
	for file in DirAccess.get_files_at(path):
		#print(path + file)
		DirAccess.remove_absolute(path + '/' + file)
	for dir in DirAccess.get_directories_at(path):
		delete_dir_resursively(path + '/' + dir)
	DirAccess.remove_absolute(path)

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

func fetch_and_install_asset(asset_id):
	var _http := HTTPRequest.new()
	add_child(_http)
	var err := _http.request("https://godotengine.org/asset-library/api/asset/%s" % asset_id)
	var response = await _http.request_completed 
	var handler := func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS:
			push_error("Failed to get asset ", asset_id)
			return
		var asset = JSON.parse_string(body.get_string_from_utf8())
		#print(asset)
		await download_asset(asset)
	await handler.callv(response)

func download_asset(asset: Dictionary):
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(asset.download_url)
	var response = await http.request_completed
	var handler := func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS:
			push_error("Download failed from ", asset.download_url)
			return
		var file_path: String = "res://addons/globalize-plugins/temp/" + asset.title + ".zip"
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		file.store_buffer(body)
		file.close()
		await unzip_downloaded_asset(asset)
	await handler.callv(response)

func unzip_downloaded_asset(asset):
	var asset_path := get_asset_path(asset)
	var zipper := ZIPReader.new()
	var zip_path: String = "res://addons/globalize-plugins/temp/" + asset.title + ".zip"
	zipper.open(zip_path)
	var zipped_files := zipper.get_files()
	var download_to := asset_path + "/"
	#var download_to := asset_path + "/addons/"
	var prefix := zipped_files[0]
	var addon_prefix := prefix
	#var addon_prefix := prefix + "addons/"
	for path in zipped_files:
		if !path.begins_with(addon_prefix):
			continue
		var content := zipper.read_file(path)
		var stripped_path := path.trim_prefix(addon_prefix)
		var final_path := download_to + stripped_path
		var g_path := ProjectSettings.globalize_path(final_path)
		#prints(final_path)
		DirAccess.remove_absolute(g_path)
		if final_path.ends_with("/"):
			var err = DirAccess.make_dir_recursive_absolute(g_path)
			if err != OK:
				push_error("Could not make directory ", final_path)
		else:
			var zfile := FileAccess.open(final_path, FileAccess.WRITE)
			zfile.store_buffer(content)
			zfile.close()
	zipper.close()
	DirAccess.remove_absolute(zip_path)

func spawn_current_globalized_items():
	#if EditorInterface.get_editor_settings().has_setting(editor_key):
		#var data: Dictionary = EditorInterface.get_editor_settings().get_setting(editor_key)
		#print("found ", data.values())
	var global_path := EditorInterface.get_editor_paths().get_config_dir() + "/globalized"
	spawn_items(editor_plugins.values(), globalized_items_container, func(item): pass)

func _on_search_saved_text_changed(new_text):
	print(new_text)

func _on_about_to_popup():
	print("popping up")
	_on_line_edit_text_submitted()
