This plugin lets you "globalize" plugins. It adds an Editor setting which holds a list of plugin paths. 
Then, whenever *this* plugin is loaded, *those* plugins are copied into the current project and are enabled.

Available in the asset library as ***Globalize Plugins***: 
https://godotengine.org/asset-library/asset/2681

## Globalizing a plugin from the asset library
1. Go to the AssetLib main tab
2. There is a new `Globalize...` button at the end of the search bar
3. Search for the asset by name and click `+ Add`
   - There's also a `Globalize` shortcut in each AssetLibrary Item's window, which searches the asset title automatically

## Globalizing a plugin from your PC
1. Go to **Editor > EditorSettings > Global Plugins > Paths**
2. Add a new item and click the folder icon
3. Locate the `plugin.cfg` of the plugin you want to globalize and select it

## Enabling global plugins for a project
1. Download and install `globalize-plugins` from the asset library
2. Now, whenever you load a project with this plugin enabled, all globalized plugins will automatically be copied into the project. This keeps them up to date, and adds any new plugins you may have globalized since the last load.

## Notes

- You can disable specific plugins for specific projects as you normally would (in Project > ProjectSettings > Plugins). This plugin won't try to force enable any plugins that already exist in the project.
- Any changes you make to a "globalized" plugin will be overwritten on the next load. Make all your changes in the plugin's project, so they won't be overwritten.
- Plugins downloaded from the Asset Library are located in your `"(Editor Settings directory)/globalized"`, which can be found here https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#editor-data-paths
  - Only the addons folder of an asset library plugin will be downloaded
  - An empty project.godot file is made for each asset library plugin. It will not appear in your project manager by default, but you can double click it to open the plugin as a project, and make edits that should be global
  - If an asset does not have a `plugin.cfg` in any addons folder, it will not be found and copied into projects. For now, you can just open the plugin's project.godot and add a dummy plugin into the addons folder you want
  - Your own local plugins can also go into this `globalized` folder, and it will automatically be global. Just make sure your plugin name does not begin with a number, as those number prefixes represent AssetLibrary ids
