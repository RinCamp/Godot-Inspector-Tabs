@tool
extends EditorPlugin

const _Tabs = preload("res://addons/inspector_tabs/inspector_tabs.gd")
var plugin = _Tabs.new()

func _enter_tree():
    add_inspector_plugin(plugin)
    plugin.enter()


func _exit_tree():
    plugin.exit()
    remove_inspector_plugin(plugin)
