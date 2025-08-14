@tool
extends EditorPlugin

const _Tabs = preload("res://addons/inspector_tabs/inspector_tabs.gd")
var plugin = _Tabs.new()


func _enter_tree():
    load_project_settings()
    add_inspector_plugin(plugin)
    plugin.enter()


func _exit_tree():
    # TODO
    # No method found to trigger this function when the plugin is closed.
    #clear_project_settings()
    remove_inspector_plugin(plugin)
    plugin.exit()


func _process(delta: float) -> void:
    plugin.process_update()


func load_project_settings():
    _set_project_cfg(
        _Tabs.KEY_TAB_LAYOUT, _Tabs.TabLayouts.Horizontal,
        TYPE_INT,  PROPERTY_HINT_ENUM, "Horizontal,Vertical"
    )

    _set_project_cfg(
        _Tabs.KEY_TAB_STYLE, _Tabs.TabStyles.Text_And_Icon,
        TYPE_INT,  PROPERTY_HINT_ENUM, "Text and Icon,Text Only,Icon Only"
    )

    _set_project_cfg(
        _Tabs.KEY_MERGE_ABSTRACT_CLASS_TABST, false,
        TYPE_BOOL,
    )

    _set_project_cfg(
        _Tabs.KEY_ENABLED_MEMORY_CHOICES, true,
        TYPE_BOOL,
    )

    ProjectSettings.save()


func clear_project_settings():
    var _all_settings = [
        _Tabs.KEY_TAB_LAYOUT,
        _Tabs.KEY_TAB_STYLE,
        _Tabs.KEY_MERGE_ABSTRACT_CLASS_TABST,
        _Tabs.KEY_ENABLED_MEMORY_CHOICES,
    ]
    for key in _all_settings:
        if ProjectSettings.has_setting(key):
            ProjectSettings.clear(key)
    ProjectSettings.save()


func _set_project_cfg(key: String, value, type: int, hint:int=PROPERTY_HINT_NONE, hint_string=""):
    if not ProjectSettings.has_setting(key):
        ProjectSettings.set(key, value)

    ProjectSettings.set_initial_value(key, value)
    ProjectSettings.add_property_info({
        "name": key,
        "type": type,
        "hint": hint,
        "hint_string": hint_string,
    })
