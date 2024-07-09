@tool
extends EditorPlugin

var asset_lib: Node
var asset_panel_scene = preload("res://addons/globalize-plugins/asset_panel.tscn")
var globalize_popup_button: Button

const editor_local_key := "global_plugins/paths"
const editor_asset_key := "global_plugins/assets"
const project_settings_key := "global_plugins/saved"

var current_plugin_data: Dictionary = {}
var global_plugin_data: Dictionary = {}
var globalized_asset_path: String = ""

func get_global_asset_paths():
	if globalized_asset_path.is_empty(): return []
	var plugins := []
	for dir in DirAccess.get_directories_at(globalized_asset_path):
		dir = globalized_asset_path + dir
		for addon in DirAccess.get_directories_at(dir + "/addons/"):
			if FileAccess.file_exists(dir + "/addons/" + addon + "/plugin.cfg"):
				plugins.push_back(dir + "/addons/" + addon + "/plugin.cfg")
	return plugins

func globalize_local_plugins():
	var settings := EditorInterface.get_editor_settings()
	
	# Add property hints to the EditorSettings, for file picking
	var property_info = {
		"name": editor_local_key,
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:plugin.cfg" % [TYPE_STRING, PROPERTY_HINT_GLOBAL_FILE]
	}
	settings.add_property_info(property_info)
	if !settings.has_setting(editor_local_key):
		settings.set_setting(editor_local_key, [])
	
	var paths: Array = settings.get_setting(editor_local_key)
	var project_path := ProjectSettings.globalize_path("res://")
	
	paths = get_global_asset_paths() + paths
	var plugin_folders_to_enable := []
	
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
			
			if !already_exists:
				plugin_folders_to_enable.push_back(folder)
		
	# The FileSystem dock doesn't properly scan new files if scanned immediately
	var rfs := EditorInterface.get_resource_filesystem()
	await get_tree().process_frame
	#print('scan 1')
	rfs.scan()
	
	while rfs.is_scanning():
		#print('waiting while scanning')
		await get_tree().process_frame
	await get_tree().process_frame
	
	for folder in plugin_folders_to_enable:
		EditorInterface.set_plugin_enabled(folder, true)


func inject_globalize_button_assetlib():
	var main_screen := EditorInterface.get_editor_main_screen()
	for child in main_screen.get_children():
		if child.name.begins_with("@EditorAssetLibrary"):
			asset_lib = child
			asset_lib.child_entered_tree.connect(on_assetlib_child)
			
			var hbox: HBoxContainer = child.get_child(0, true).get_child(0, true)
			globalize_popup_button = Button.new()
			globalize_popup_button.text = "Globalize..."
			var panel := asset_panel_scene.instantiate()
			panel.plugin = self
			panel.hide()
			globalize_popup_button.pressed.connect(
				func():
					panel.popup_centered()
					panel.show()
			)
			hbox.add_child(globalize_popup_button)
			globalize_popup_button.add_child(panel)
			break

func on_assetlib_child(child: Node):
	if child.name.begins_with("@EditorAssetLibraryItemDescription"):
		await get_tree().process_frame
		
		var container: HBoxContainer = child.get_child(2, true)
		if container:
			# Insert Button
			var right_c := Control.new()
			var asset_button := Button.new()
			container.add_child(asset_button)
			container.add_child(right_c)
			asset_button.text = "Globalize"
			#asset_button.icon = globalize_icon
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
					#prints(title.text, title.uri)
			
			var asset_panel: PopupPanel = asset_panel_scene.instantiate()
			asset_panel.plugin = self
			asset_panel.visible = false
			asset_button.add_child(asset_panel)
			asset_button.pressed.connect(
				func():
					if asset_panel.line_edit.text != plugin_title:
						asset_panel.line_edit.text = plugin_title
						#asset_panel.line_edit.text_submitted.emit(plugin_title)
					asset_panel.popup_centered()
			)
			asset_panel.asset_id_pressed.connect(
				func(asset):
					var old_title := asset_panel.title
					asset_panel.title = "Downloading and Installing ..."
					asset_panel.gui_disable_input = true
					#globalize_asset_plugin(asset)
					asset_panel.gui_disable_input = false
					asset_panel.title = old_title
					#asset_panel.hide()
					print("Plugin ", asset.title, " was globalized")
					await get_tree().process_frame
					EditorInterface.get_resource_filesystem().scan()
			)

func setup_editor_settings():
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.has_setting(editor_asset_key):
		global_plugin_data = editor_settings.get_setting(editor_asset_key)
	else:
		global_plugin_data = {}
		editor_settings.set_setting(editor_asset_key, global_plugin_data)
	#editor_settings.set_setting(editor_asset_key, global_plugin_data)
	editor_settings.add_property_info({
		"name" = editor_asset_key,
		"type" = TYPE_DICTIONARY
	})
	editor_settings.set_initial_value(editor_asset_key, {}, false)

static func sync_asset_changes():
	var editor_plugins: Dictionary = EditorInterface.get_editor_settings().get_setting(editor_asset_key)
	var project_plugins: Dictionary = ProjectSettings.get_setting(project_settings_key)
	for asset_id in editor_plugins:
		if project_plugins.has(asset_id):
			var p_asset: Dictionary = project_plugins[asset_id]
			var e_asset: Dictionary = editor_plugins[asset_id]
			if e_asset.version_string != p_asset.version_string:
				for key in p_asset:
					p_asset[key] = e_asset[key]
		else:
			project_plugins[asset_id] = editor_plugins[asset_id]
			EditorInterface

func setup_globalized_project():
	var paths := EditorInterface.get_editor_paths()
	var path := paths.get_config_dir()
	globalized_asset_path = path + "/globalized/"
	DirAccess.make_dir_recursive_absolute(globalized_asset_path)

func _enter_tree():
	setup_editor_settings()
	setup_globalized_project()
	globalize_local_plugins()
	inject_globalize_button_assetlib()

func _exit_tree():
	if is_instance_valid(asset_lib):
		if asset_lib.child_entered_tree.is_connected(on_assetlib_child):
			asset_lib.child_entered_tree.disconnect(on_assetlib_child)
	if is_instance_valid(globalize_popup_button):
		globalize_popup_button.queue_free()
