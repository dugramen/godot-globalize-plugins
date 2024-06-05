@tool
extends EditorPlugin

var asset_lib: Node
var globalize_icon := preload("res://addons/globalize-plugins/globalize-plugin.png")
var versions := preload("res://addons/globalize-plugins/saved_versions.tres")
var asset_panel_scene := preload("res://addons/globalize-plugins/asset_panel.tscn")
const project_settings_key := "global_plugins/saved"

var current_plugin_data: Dictionary = {}

func globalize_local_plugins():
	var settings := EditorInterface.get_editor_settings()
	
	# Add property hints to the EditorSettings, for file picking
	var property_info = {
		"name": "global_plugins/paths",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:plugin.cfg" % [TYPE_STRING, PROPERTY_HINT_GLOBAL_FILE]
	}
	settings.add_property_info(property_info)
	if !settings.has_setting("global_plugins/paths"):
		settings.set_setting("global_plugins/paths", [])
	
	var paths: Array = settings.get_setting("global_plugins/paths")
	var project_path := ProjectSettings.globalize_path("res://")
	
	# Load plugins at paths
	for path: String in paths:
		# Don't copy folders that are nested under each other
		if path.begins_with(project_path) or project_path.begins_with(path):
			prints("skipped -", path)
			continue
		
		var base_dir := path.get_base_dir()
		var base_file := path.get_file()
		
		# Check if plugin.cfg file exists
		if base_file != "plugin.cfg" or !FileAccess.file_exists(path):
			push_warning("A plugin.cfg file wasn't found at path ", path, ". Recheck EditorSettings > GlobalPlugins > paths for invalid paths.")
			continue
		
		var folder := base_dir.split("/", false)[-1]
		var base_path := base_dir.trim_suffix("/" + folder)
		
		# Check if the plugin already exists in the project
		var already_exists := FileAccess.file_exists("res://addons/" + folder + "/" + base_file)
		
		# Recursively copy the folder contents into this project
		var dirs := [folder]
		var i := 0
		while i < dirs.size():
			var dir: String = dirs[i]
			var cur_path := base_path + '/' + dir
			var local_path := project_path + "addons/" + dir
			DirAccess.make_dir_absolute(local_path)
			for file in DirAccess.get_files_at(cur_path):
				DirAccess.copy_absolute(cur_path + '/' + file, local_path + '/' + file)
			dirs.append_array( Array(DirAccess.get_directories_at(cur_path)).map(
				func(d): return dir + '/' + d) 
			)
			i += 1
		
		# The FileSystem dock doesn't properly scan new files if scanned immediately
		get_tree().process_frame.connect(
			func():
				EditorInterface.get_resource_filesystem().scan()
				# Don't override the enabled status if the plugin had already been added before
				if !already_exists:
					EditorInterface.set_plugin_enabled(folder, true)
		, CONNECT_ONE_SHOT)


func fetch_and_install_asset(asset_id):
	var _http := HTTPRequest.new()
	add_child(_http)
	var err := _http.request("https://godotengine.org/asset-library/api/asset/%s" % asset_id)
	var response = await _http.request_completed 
	var handler := func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS:
			push_error("Failed to get asset ", asset_id)
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		print(data)
		await download_asset(data)
	await handler.callv(response)
	
	#var result = response[0]
	#var body = response[3]
	#if result != HTTPRequest.RESULT_SUCCESS:
		#push_error("Failed to get asset ", asset_id)
		#return
	#var data = JSON.parse_string(body.get_string_from_utf8())
	#print(data)
	#await download_asset(data)
	#_http.request_completed.connect(
		#func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			#if result != HTTPRequest.RESULT_SUCCESS:
				#push_error("Failed to get asset ", asset_id)
				#return
			#var data = JSON.parse_string(body.get_string_from_utf8())
			#print(data)
			#download_asset(data)
	#)

func download_asset(asset: Dictionary):
	var _http := HTTPRequest.new()
	add_child(_http)
	var err := _http.request(asset.download_url)
	var response = await _http.request_completed
	var handler := func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS:
			push_error("Download failed from ", asset.download_url)
			return
		var file_path: String = "res://addons/globalize-plugins/temp/" + asset.title + ".zip"
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		file.store_buffer(body)
		file.close()
		await unzip_asset(file_path)
	await handler.callv(response)
	
	#_http.request_completed.connect(
		#func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			#if result != HTTPRequest.RESULT_SUCCESS:
				#push_error("Download failed from ", asset.download_url)
				#return
			##var file_path: String = base_path + "download.zip"
			#var file_path: String = "res://addons/globalize-plugins/temp/" + asset.title + ".zip"
			#var file := FileAccess.open(file_path, FileAccess.WRITE)
			#file.store_buffer(body)
			#file.close()
	#)

func unzip_asset(file_path):
	var zipper := ZIPReader.new()
	zipper.open(file_path)
	var zipped_files := zipper.get_files()
	var base_path := "res://addons/"
	var prefix := zipped_files[0]
	var addon_prefix := prefix + "addons/"
	for path in zipped_files:
		if !path.begins_with(addon_prefix):
			continue
		var content := zipper.read_file(path)
		var stripped_path := path.trim_prefix(addon_prefix)
		var final_path := base_path + stripped_path
		var g_path := ProjectSettings.globalize_path(final_path)
		prints(final_path)
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

func inject_globalize_button_assetlib():
	var main_screen := EditorInterface.get_editor_main_screen()
	for child in main_screen.get_children():
		if child.name.begins_with("@EditorAssetLibrary"):
			asset_lib = child
			asset_lib.child_entered_tree.connect(on_assetlib_child)
			break

func on_assetlib_child(child: Node):
	if child.name.begins_with("@EditorAssetLibraryItemDescription"):
		#print("asset window found")
		await get_tree().process_frame
		var container: HBoxContainer = child.get_child(2, true)
		if container:
			# Insert Button
			var right_c := Control.new()
			var asset_button := Button.new()
			container.add_child(asset_button)
			container.add_child(right_c)
			asset_button.text = "Globalize"
			asset_button.icon = globalize_icon
			asset_button.add_theme_constant_override("icon_max_width", 24)
			right_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Locate plugin title
			var plugin_title := ""
			var info_container: Node = child.get_child(3, true #hbox
				).get_child(0, true #vbox
				).get_child(0, true #EditorAssetLibraryItem
				).get_child(0, true #hbox
				).get_child(1, true #vbox
				)
			if info_container:
				var title = info_container.get_child(0, true)
				if title is LinkButton:
					plugin_title = title.text
					prints(title.text, title.uri)
			
			var asset_panel: PopupPanel = asset_panel_scene.instantiate() as PopupPanel
			asset_panel.visible = false
			asset_button.add_child(asset_panel)
			asset_button.pressed.connect(
				func():
					asset_panel.popup_centered()
					if asset_panel.line_edit.text != plugin_title:
						asset_panel.line_edit.text = plugin_title
						asset_panel.line_edit.text_submitted.emit(plugin_title)
			)
			asset_panel.asset_id_pressed.connect(
				func(id):
					var old_title := asset_panel.title
					asset_panel.title = "Downloading and Installing ..."
					asset_panel.gui_disable_input = true
					await fetch_and_install_asset(id)
					asset_panel.gui_disable_input = false
					asset_panel.title = old_title
					asset_panel.hide()
					await get_tree().process_frame
					EditorInterface.get_resource_filesystem().scan()
			)

func setup_project_settings():
	current_plugin_data = ProjectSettings.get_setting(project_settings_key, {})
	ProjectSettings.set_setting(project_settings_key, current_plugin_data)
	ProjectSettings.add_property_info({
		"name" = project_settings_key,
		"type" = TYPE_DICTIONARY,
	})
	ProjectSettings.set_initial_value(project_settings_key, {})
	ProjectSettings.set_as_internal(project_settings_key, true)

func _enter_tree():
	setup_project_settings()
	#globalize_local_plugins()
	inject_globalize_button_assetlib()
	pass

func _exit_tree():
	if is_instance_valid(asset_lib):
		if asset_lib.child_entered_tree.is_connected(on_assetlib_child):
			asset_lib.child_entered_tree.disconnect(on_assetlib_child)
	pass
