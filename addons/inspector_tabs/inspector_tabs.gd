extends EditorInspectorPlugin

const KEY_TAB_LAYOUT = "inspector_tabs/tab_layout"
const KEY_TAB_STYLE = "inspector_tabs/tab_style"
const KEY_MERGE_ABSTRACT_CLASS_TABST = "inspector_tabs/merge_abstract_class_tabs"
const KEY_ENABLED_MEMORY_CHOICES = "inspector_tabs/enabled_memory_choices"


enum TabLayouts{
    Horizontal,
    Vertical,
}

enum TabStyles{
    Text_And_Icon,
    Text_Only,
    Icon_Only,
}


# Inspector
var base_control = EditorInterface.get_base_control()
# path to the editor inspector list of properties
var property_container = EditorInterface.get_inspector().get_child(0).get_child(2)
# path to the editor inspector favorite list.
var favorite_container = EditorInterface.get_inspector().get_child(0).get_child(1)
# path to the editor inspector "viewer" area. (camera viewer or skeleton3D bone tree)
var viewer_container = EditorInterface.get_inspector().get_child(0).get_child(0)

var filter_bar = EditorInterface.get_inspector().get_parent().get_child(2).get_child(0)
var property_scroll_bar : VScrollBar = EditorInterface.get_inspector().get_node("_v_scroll")

var scroll_area : ScrollContainer
var tab_bar : TabBar

# Mode
var tab_layout : int
var tab_style : int
var merge_abstract_class_tabs : bool
var enabled_memory_choices : bool

# Tab position
var vertical_mode : bool = true
# 0:left; 1:Right;
var vertical_tab_side = 1
# are the search bar in use
var is_filtering = false

var current_parse_category:String = ""


# All categories/subclasses in the inspector
var categories = []
# All tabs in the inspector
var tabs = []
# Finish adding categories
var categories_finish = false

var UNKNOWN_ICON : Texture2D = EditorInterface.get_base_control().get_theme_icon("", "EditorIcons")
var icon_cache : Dictionary

var current_node_class = ""
var memory_choices_data : Dictionary = {}


func enter():
    if not EditorInterface.get_inspector().gui_input.is_connected(_on_inspector_gui_input):
        EditorInterface.get_inspector().gui_input.connect(_on_inspector_gui_input)
    if not EditorInterface.get_inspector().resized.is_connected(_on_inspector_resized):
        EditorInterface.get_inspector().resized.connect(_on_inspector_resized)

    ProjectSettings.settings_changed.connect(_on_project_settings_changed)
    if ProjectSettings.get_setting(KEY_TAB_LAYOUT, 0) == TabLayouts.Horizontal:
        change_vertical_mode(false)
    else:
        change_vertical_mode(true)

    tab_layout = ProjectSettings.get_setting(KEY_TAB_LAYOUT, 0)
    tab_style = ProjectSettings.get_setting(KEY_TAB_STYLE)
    merge_abstract_class_tabs = ProjectSettings.get_setting(KEY_MERGE_ABSTRACT_CLASS_TABST)
    enabled_memory_choices = ProjectSettings.get_setting(KEY_ENABLED_MEMORY_CHOICES)

    filter_bar.text_changed.connect(_on_filter_text_changed)


func exit():
    if EditorInterface.get_inspector().resized.is_connected(_on_inspector_resized):
        EditorInterface.get_inspector().resized.disconnect(_on_inspector_resized)
    if EditorInterface.get_inspector().gui_input.is_connected(_on_inspector_gui_input):
        EditorInterface.get_inspector().gui_input.disconnect(_on_inspector_gui_input)

    scroll_area.queue_free()

    property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    favorite_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    property_container.custom_minimum_size.x = 0
    favorite_container.custom_minimum_size.x = 0
    viewer_container.custom_minimum_size.x = 0


func process_update():
    # Reposition UI
    if vertical_mode:
        tab_bar.size.x = EditorInterface.get_inspector().size.y
        if vertical_tab_side == 0:#Left side
            tab_bar.global_position = EditorInterface.get_inspector().global_position+Vector2(0,tab_bar.size.x)
            tab_bar.rotation = -PI/2
            property_container.custom_minimum_size.x = property_container.get_parent_area_size().x - tab_bar.size.y - 5
            favorite_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
            viewer_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
            property_container.position.x = tab_bar.size.y + 5
            favorite_container.position.x = tab_bar.size.y + 5
            viewer_container.position.x = tab_bar.size.y + 5
        else:#Right side
            tab_bar.global_position = EditorInterface.get_inspector().global_position+Vector2(favorite_container.get_parent_area_size().x+tab_bar.size.y/2,0)
            if property_scroll_bar.visible:
                property_scroll_bar.position.x = property_container.get_parent_area_size().x - tab_bar.size.y+property_scroll_bar.size.x/2
                tab_bar.global_position.x += property_scroll_bar.size.x
            tab_bar.rotation = PI/2
            property_container.custom_minimum_size.x = property_container.get_parent_area_size().x - tab_bar.size.y - 5
            favorite_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
            viewer_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
            property_container.position.x = 0
            favorite_container.position.x = 0
            viewer_container.position.x = 0

    if EditorInterface.get_inspector().global_position.x < EditorInterface.get_inspector().get_viewport().size.x/2 -EditorInterface.get_inspector().size.x/2:
        if vertical_tab_side != 1:
            vertical_tab_side = 1
            change_vertical_mode()
    else:
        if vertical_tab_side != 0:
            vertical_tab_side = 0
            change_vertical_mode()

    if tab_bar.tab_count != 0:
        if EditorInterface.get_inspector().get_edited_object() == null:
            tab_bar.clear_tabs()


func _can_handle(object):
    # We support all objects in this example.
    return true

# getting the category from the inspector
func _parse_category(object: Object, category: String) -> void:
    if category == "Atlas": return # Not sure what class this is. But it seems to break things.

    # reset the list if its the first category
    if categories_finish:
        categories_finish = false
        categories.clear()
        tabs.clear()

        tab_bar.clear_tabs()
    # This line is needed because when selecting multiple nodes the refcounted class will be the last tab.
    if current_parse_category != "Node":
        current_parse_category = category

# Finished getting inspector categories
func _parse_end(object: Object) -> void:
    if current_parse_category != "Node":
        return # False finish

    current_parse_category = ""

    for i in property_container.get_children():
        if i.get_class() == "EditorInspectorCategory":

            # Get Node Name
            var category = i.get("tooltip_text").split("|")

            if category.size() > 1:
                category = category[1]
            else:
                category = category[0]

            if category.split('"').size() > 1:
                category = category.split('"')[1]

            # Add it to the list of categories and tabs
            categories.append(category)
            if is_new_tab(category):
                tabs.append(category)

        elif categories.size() == 0:# If theres properties at the top of the inspector without its own category.
            # Add it to the list of categories and tabs
            var category = "Unknown"
            tabs.append(category)
            categories.append(category)

    categories_finish = true
    update_tabs() # load tab


func is_new_tab(category:String) -> bool:
    if merge_abstract_class_tabs:
        if ClassDB.class_exists(category) and not ClassDB.can_instantiate(category):
            if categories[0] == category:
                return true
            return false
    return true

# Change position mode
func change_vertical_mode(mode:bool = vertical_mode):
    vertical_mode = mode

    if scroll_area:
        scroll_area.queue_free()

    var panel = Panel.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND
    panel.size_flags_vertical = Control.SIZE_EXPAND
    panel.show_behind_parent = true
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)

    tab_bar = TabBar.new()
    tab_bar.clip_tabs = false
    tab_bar.rotation = PI/2
    tab_bar.mouse_filter = Control.MOUSE_FILTER_PASS
    tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if vertical_mode:
        tab_bar.clip_tabs = true

    tab_bar.tab_clicked.connect(tab_clicked)
    tab_bar.gui_input.connect(_on_tab_bar_gui_input)
    tab_bar.resized.connect(_on_tab_resized)

    update_tabs()

    scroll_area = ScrollContainer.new()
    scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
    scroll_area.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

    tab_bar.add_child(panel)
    scroll_area.add_child(tab_bar)

    if vertical_mode:
        EditorInterface.get_inspector().add_child(scroll_area)
        scroll_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    else:
        scroll_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll_area.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        var inspector = EditorInterface.get_inspector().get_parent()
        inspector.add_child(scroll_area)
        inspector.move_child(scroll_area, 3)


    if vertical_mode:
        tab_bar.top_level = true
        if vertical_tab_side == 0:
            tab_bar.layout_direction = Control.LAYOUT_DIRECTION_RTL
        else:
            tab_bar.layout_direction = Control.LAYOUT_DIRECTION_LTR

        property_container.size_flags_horizontal = Control.SIZE_SHRINK_END
        favorite_container.size_flags_horizontal = Control.SIZE_SHRINK_END
        viewer_container.size_flags_horizontal = Control.SIZE_SHRINK_END
    else:
        property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        favorite_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        viewer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        property_container.custom_minimum_size.x = 0
        favorite_container.custom_minimum_size.x = 0
        viewer_container.custom_minimum_size.x = 0


func add_tab_category(tab_name, load_icon):
    if vertical_mode:
        # Rotate the image for the vertical tab
        if vertical_tab_side == 0:
            var rotated_image = load_icon.get_image().duplicate()
            rotated_image.rotate_90(CLOCKWISE)
            load_icon = ImageTexture.create_from_image(rotated_image)
        else:
            var rotated_image = load_icon.get_image().duplicate()
            rotated_image.rotate_90(COUNTERCLOCKWISE)
            load_icon = ImageTexture.create_from_image(rotated_image)

    match tab_style:
        TabStyles.Text_Only:
            tab_bar.add_tab(tab_name,null)
        TabStyles.Icon_Only:
            tab_bar.add_tab("",load_icon)
        TabStyles.Text_And_Icon:
            tab_bar.add_tab(tab_name,load_icon)
    tab_bar.set_tab_tooltip(tab_bar.tab_count-1, tab_name)

# add tabs
func update_tabs() -> void:
    tab_bar.clear_tabs()

    for tab : String in tabs:
        var load_icon = get_tab_icon(tab)
        var tab_name = tab.split("/")[-1]
        add_tab_category(tab_name, load_icon)

    var icon = EditorInterface.get_base_control().get_theme_icon("DebugNext", "EditorIcons")
    add_tab_category("All", icon)
    tab_bar.move_tab(tab_bar.tab_count-1, 0)
    tabs.insert(0, "All")

    if enabled_memory_choices and tabs.size() > 1:
        var memory_idx = memory_choices_data.get(tabs[1], 0)
        scroll_to_tab(memory_idx)
    else:
        scroll_to_tab(0)


func tab_clicked(idx: int) -> void:
    if enabled_memory_choices:
        if tabs.size() > 1:
            var tab_name = tabs[1]
            memory_choices_data.set(tab_name, idx)

    if idx == 0:
        # Show all properties
        for i in property_container.get_children():
            i.visible = true
        return

    if is_filtering:
        return

    var category_idx = -1
    var tab_idx = 0

    # Show nececary properties
    for i in property_container.get_children():
        if i.get_class() == "EditorInspectorCategory":
            category_idx += 1
            if is_new_tab(categories[category_idx]):
                tab_idx += 1

        elif tab_idx == 0: # If theres properties at the top of the inspector without its own category.
            category_idx += 1
            if is_new_tab(categories[category_idx]):
                tab_idx += 1
        if tab_idx != idx:
            i.visible = false
        else:
            i.visible = true

## Signal

func scroll_to_tab(idx:int=0):
    if idx >= tab_bar.tab_count:
        idx = 0

    tab_bar.current_tab = idx

    if scroll_area:
        var tab_rect = tab_bar.get_tab_rect(idx)
        var max_tab_rect = tab_bar.get_tab_rect(tab_bar.tab_count - 1)
        var target_position = min(tab_rect.position.x, max_tab_rect.position.x)

        var distance = abs(scroll_area.scroll_horizontal - target_position)
        var scroll_speed = 800.0
        var duration = distance / scroll_speed

        var tween = scroll_area.create_tween()
        tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
        tween.tween_property(scroll_area, "scroll_horizontal", target_position, duration).from_current()
        tab_clicked(idx)


func _swtich_tab(event):
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if Input.is_key_pressed(KEY_CTRL):
                match event.button_index:
                    MOUSE_BUTTON_WHEEL_UP:
                        tab_bar.current_tab = max(0, tab_bar.current_tab-1)
                        tab_clicked(tab_bar.current_tab)
                    MOUSE_BUTTON_WHEEL_DOWN:
                        tab_bar.current_tab = min(tab_bar.tab_count-1, tab_bar.current_tab+1)
                        tab_clicked(tab_bar.current_tab)

                scroll_to_tab(tab_bar.current_tab)


func _on_tab_bar_gui_input(event):
    if vertical_mode:
        return
    if tab_bar.current_tab < 0:
        return
    _swtich_tab(event)


func _on_inspector_gui_input(event):
    if tab_bar.current_tab < 0:
        return
    _swtich_tab(event)

# Is searching
func _on_filter_text_changed(text:String):
    if text != "":
        for i in property_container.get_children():
            i.visible = true
        is_filtering = true
    else:
        is_filtering = false

        if enabled_memory_choices and tabs.size() > 1:
            var memory_idx = memory_choices_data.get(tabs[1], 0)
            scroll_to_tab(memory_idx)
        else:
            scroll_to_tab(0)


func _on_inspector_resized():
    if vertical_mode:
        tab_bar.custom_minimum_size.x = tab_bar.size.y
        tab_bar.reset_size()


func _on_project_settings_changed() -> void:
    tab_layout = ProjectSettings.get_setting(KEY_TAB_LAYOUT, 0)
    tab_style = ProjectSettings.get_setting(KEY_TAB_STYLE)
    merge_abstract_class_tabs = ProjectSettings.get_setting(KEY_MERGE_ABSTRACT_CLASS_TABST)

    if tab_layout == 0:
        if vertical_mode != false:
            change_vertical_mode(false)
    else:
        if vertical_mode != true:
            change_vertical_mode(true)


func _on_tab_resized():
    if vertical_mode:
        tab_bar.custom_minimum_size.x = tab_bar.size.x
        scroll_area.size.x = tab_bar.size.y
    else:
        tab_bar.custom_minimum_size.y = tab_bar.size.y


## Get Icon


func get_tab_icon(tab) -> Texture2D:
    var load_icon : Texture2D

    if tab.ends_with(".gd"):
        load_icon = get_script_icon(tab) ## Get script custom icon or the GDScript icon
    elif ClassDB.class_exists(tab):
        if ClassDB.class_get_api_type(tab) == ClassDB.APIType.API_EXTENSION:
            load_icon = get_extension_class_icon(tab)  ## Get GDExtension node icon
        else:
            load_icon = base_control.get_theme_icon(tab, "EditorIcons") ## Get editor node icon
    else:
        load_icon = get_script_class_icon(tab) ## Get script class icon

    if load_icon == UNKNOWN_ICON:
        load_icon = base_control.get_theme_icon("NodeDisabled", "EditorIcons")

    return load_icon


func get_custom_class_name(_script:GDScript) -> String:
    var _name : String = ""
    if _script.get_base_script():
        _name = _script.get_base_script().get_global_name()
        for class_info in ProjectSettings.get_global_class_list():
            if class_info["class"] == _name:
                if ResourceLoader.exists(class_info["icon"]) == false:
                    return get_custom_class_name(load(class_info["path"]))
    else:
        var _node = _script.new() as Node
        _name = _node.get_class()
        _node.free()
    return _name


func get_script_class_icon(tab) -> Texture2D:
    if icon_cache.has(tab):
        return icon_cache.get(tab)

    for class_info in ProjectSettings.get_global_class_list():
        if class_info["class"] == tab:
            if ResourceLoader.exists(class_info["icon"]) == false:
                var cls_name = get_custom_class_name(load(class_info["path"]))
                return get_tab_icon(cls_name)

            var texture: Texture2D = ResourceLoader.load(class_info["icon"])
            var image = texture.get_image()
            image.resize(UNKNOWN_ICON.get_width(),UNKNOWN_ICON.get_height())

            var icon = ImageTexture.create_from_image(image)
            icon_cache = {tab:icon}
            return icon
    if vertical_mode:
        return base_control.get_theme_icon("ArrowUp", "EditorIcons")
    return base_control.get_theme_icon("ArrowLeft", "EditorIcons")


func get_extension_class_icon(tab) -> Texture2D:
    if icon_cache.has(tab):
        return icon_cache.get(tab)

    for i in GDExtensionManager.get_loaded_extensions():
        var cfg = _load_gdextension_config(i)
        var icons = cfg.get("icons")
        if icons:
            var path = icons.get(tab, "")
            if ResourceLoader.exists(path):
                var texture: Texture2D = ResourceLoader.load(path)
                var image = texture.get_image()
                image.resize(UNKNOWN_ICON.get_width(),UNKNOWN_ICON.get_height())

                var icon = ImageTexture.create_from_image(image)
                icon_cache = {tab : icon}
                return icon

    return base_control.get_theme_icon("NodeDisabled", "EditorIcons")


func get_script_icon(script_path:String) -> Texture2D:
    if !script_path.begins_with("res://"):
        script_path = "res://" + script_path

    var file := FileAccess.open(script_path, FileAccess.READ)
    if not file:
        return base_control.get_theme_icon("GDScript", "EditorIcons")
    while not file.eof_reached():
        var line := file.get_line().strip_edges()
        if line.begins_with("@icon("):
            var start = line.find("\"") + 1
            var end = line.rfind("\"")
            if start > 0 and end > start:
                var img_path = line.substr(start, end - start)

                if !img_path.begins_with("res://"): ## If path is absolute
                    img_path = script_path.substr(0, script_path.rfind("/")) + "/" + img_path

                var texture: Texture2D = load(img_path)
                var image = texture.get_image()
                image.resize(UNKNOWN_ICON.get_width(),UNKNOWN_ICON.get_height())
                return ImageTexture.create_from_image(image)
    return base_control.get_theme_icon("GDScript", "EditorIcons")


func _load_gdextension_config(path: String) -> Dictionary:
    var config = ConfigFile.new()
    var err = config.load(path)
    if err != OK:
        print("Failed to load .gdextension file:", path)
        return {}

    var data = {}
    for section in config.get_sections():
        data[section] = {}
        for key in config.get_section_keys(section):
            data[section][key] = config.get_value(section, key)

    return data
