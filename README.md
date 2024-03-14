This plugin lets you "globalize" plugins. It adds an Editor setting which holds a list of plugin paths. 
Then, whenever *this* plugin is loaded, *those* plugins are copied into the current project and are enabled.

## Instructions:
1. Download and enable this plugin
2. Go to **Editor > EditorSettings > Global Plugins > Paths**
3. Add a new item and click the folder icon
4. Navigate to the `plugin.cfg` of the plugin you want to globalize and select it
5. In your other projects just add & enable this plugin (from the asset store if this gets approved, or by manually copying into projects)

Now, whenever you load a project with this plugin enabled, all globalized plugins will automatically be copied into the project. This keeps them up to date, and adds any new plugins you may have globalized since the last load.

***Note: You can disable specific plugins for specific projects as you normally would (in Project > ProjectSettings > Plugins). This plugin won't try to force enable any plugins that already exist in the project.***

***Note: Any changes you make to a "globalized" plugin will be overwritten on the next load. Make all your changes in the original project, as they won't be overwritten there.***
