extends EditorInspectorPlugin

const KEY_TAB_STYLE = "inspector_tabs/tab_style"
const KEY_MERGE_ABSTRACT_CLASS_TABST = "inspector_tabs/merge_abstract_class_tabs"
const KEY_ENABLED_MEMORY_CHOICES = "inspector_tabs/enabled_memory_choices"

# 标签样式枚举
enum TabStyles {
    Text_And_Icon,  # 文本和图标
    Text_Only,      # 仅文本
    Icon_Only,      # 仅图标
}

var _BASE_CONTROL: Panel = EditorInterface.get_base_control()
var _INSPECTOR: EditorInspector = EditorInterface.get_inspector()
var _PROPERTY_CONTAINER: BoxContainer = _INSPECTOR.get_child(0).get_child(2)
var _FILTER_BAR: LineEdit = _INSPECTOR.get_parent().get_child(2).get_child(0)

var _SCROLL_BOX: ScrollContainer
var _SCROLL_TAB_BAR: TabBar

# 模式设置
var enabled_memory_choices: bool:
    get():
        return ProjectSettings.get_setting(KEY_ENABLED_MEMORY_CHOICES, true)

# 是否正在使用搜索过滤
var is_filtering = false

var current_parse_category: String = ""
# 检查器中所有的类别/子类
var categories = []
# 检查器中所有的标签页
var tabs = []
# 是否已完成添加类别
var categories_finish = false

var UNKNOWN_ICON: Texture2D = EditorInterface.get_base_control().get_theme_icon("", "EditorIcons")
var icon_cache: Dictionary
# 记忆节点位置数据
var memory_choices_data: Dictionary = {}

# 进入函数 - 初始化连接和配置
func enter():

    if not _INSPECTOR.gui_input.is_connected(_on_inspector_gui_input):
        _INSPECTOR.gui_input.connect(_on_inspector_gui_input)

    _FILTER_BAR.text_changed.connect(_on_filter_text_changed)
    _INSPECTOR.edited_object_changed.connect(_on_edited_object_changed)

    _init_config()
    load_project_settings()

# 退出函数 - 清理资源
func exit():
    if _INSPECTOR.gui_input.is_connected(_on_inspector_gui_input):
        _INSPECTOR.gui_input.disconnect(_on_inspector_gui_input)

    _SCROLL_BOX.queue_free()
    categories.clear()
    tabs.clear()

# 检查是否可以处理对象
func _can_handle(object):
    if object:
        return true
    return false

# 从检查器解析类别
func _parse_category(_object: Object, category: String) -> void:
    if category == "Atlas":
        return  # 不确定这是什么类，但似乎会破坏功能

    # 如果是第一个类别，重置列表
    if categories_finish:
        categories_finish = false
        categories.clear()
        tabs.clear()
        _SCROLL_TAB_BAR.clear_tabs()

    # 当选择多个节点时，RefCounted类将是最后一个标签页，需要这行代码
    if current_parse_category != "Node":
        current_parse_category = category

# 完成解析检查器类别
func _parse_end(_object: Object) -> void:
    if current_parse_category != "Node":
        return  # 错误的完成

    current_parse_category = ""

    for i in _PROPERTY_CONTAINER.get_children():
        if i.get_class() == "EditorInspectorCategory":
            # 获取节点名称
            var category = i.get("tooltip_text").split("|")

            if category.size() > 1:
                category = category[1]
            else:
                category = category[0]

            if category.split('"').size() > 1:
                category = category.split('"')[1]

            # 添加到类别和标签页列表
            categories.append(category)
            if _is_new_tab(category):
                tabs.append(category)

        elif categories.size() == 0:  # 如果检查器顶部有没有自己类别的属性
            # 添加到类别和标签页列表
            var category = "Unknown"
            tabs.append(category)
            categories.append(category)

    categories_finish = true
    update_tabs()  # 加载标签页

# 初始化配置
func _init_config():
    if _SCROLL_BOX:
        _SCROLL_BOX.queue_free()

    _SCROLL_BOX = ScrollContainer.new()
    _SCROLL_BOX.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
    _SCROLL_BOX.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
    _SCROLL_BOX.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _SCROLL_BOX.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

    var tab_background = Panel.new()
    tab_background.size_flags_horizontal = Control.SIZE_EXPAND
    tab_background.size_flags_vertical = Control.SIZE_EXPAND
    tab_background.show_behind_parent = true
    tab_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tab_background.set_anchors_preset(Control.PRESET_FULL_RECT)

    _SCROLL_TAB_BAR = TabBar.new()
    _SCROLL_TAB_BAR.clip_tabs = false
    _SCROLL_TAB_BAR.rotation = PI / 2
    _SCROLL_TAB_BAR.mouse_filter = Control.MOUSE_FILTER_PASS
    _SCROLL_TAB_BAR.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _SCROLL_TAB_BAR.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _SCROLL_TAB_BAR.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

    _SCROLL_TAB_BAR.tab_clicked.connect(tab_clicked)
    _SCROLL_TAB_BAR.gui_input.connect(_on_inspector_gui_input)
    _SCROLL_TAB_BAR.add_child(tab_background)

    _SCROLL_BOX.add_child(_SCROLL_TAB_BAR)

    var inspector = _INSPECTOR.get_parent()
    inspector.add_child(_SCROLL_BOX)
    inspector.move_child(_SCROLL_BOX, 3)

    update_tabs()

# 更新标签页
func update_tabs() -> void:
    _SCROLL_TAB_BAR.clear_tabs()

    for tab: String in tabs:
        var load_icon = get_tab_icon(tab)
        var tab_name = tab.split("/")[-1]
        _add_tab_category(tab_name, load_icon)

    var icon = EditorInterface.get_base_control().get_theme_icon("DebugNext", "EditorIcons")
    _add_tab_category("All", icon)  # 添加"全部"标签页
    _SCROLL_TAB_BAR.move_tab(_SCROLL_TAB_BAR.tab_count - 1, 0)
    tabs.insert(0, "All")

    if enabled_memory_choices and tabs.size() > 1:
        var memory_idx = memory_choices_data.get(tabs[1], 0)
        scroll_to_tab(memory_idx)
    else:
        scroll_to_tab(0)

# 当编辑的对象改变时
func _on_edited_object_changed():
    if not _INSPECTOR.get_edited_object():
        _SCROLL_TAB_BAR.clear_tabs()

# 是否需要创建新标签页
func _is_new_tab(category: String) -> bool:
    if ProjectSettings.get_setting(KEY_MERGE_ABSTRACT_CLASS_TABST):
        if ClassDB.class_exists(category) and not ClassDB.can_instantiate(category):
            if categories[0] == category:
                print(category)
                return true
            return false
    return true

# 添加标签页
func _add_tab_category(tab_name, load_icon):
    match ProjectSettings.get_setting(KEY_TAB_STYLE):
        TabStyles.Text_Only:  # 仅文本
            _SCROLL_TAB_BAR.add_tab(tab_name, null)
        TabStyles.Icon_Only:  # 仅图标
            _SCROLL_TAB_BAR.add_tab("", load_icon)
        TabStyles.Text_And_Icon:  # 文本和图标
            _SCROLL_TAB_BAR.add_tab(tab_name, load_icon)
    _SCROLL_TAB_BAR.set_tab_tooltip(_SCROLL_TAB_BAR.tab_count - 1, tab_name)

# 点击标签页时
func tab_clicked(idx: int) -> void:
    if enabled_memory_choices:
        if tabs.size() > 1:
            var tab_name = tabs[1]
            memory_choices_data.set(tab_name, idx)

    # 0为"全部"，显示所有属性
    if idx == 0:
        for i in _PROPERTY_CONTAINER.get_children():
            i.visible = true
        return

    if is_filtering:
        return

    var category_idx = -1
    var tab_idx = 0

    # 显示属性
    for i in _PROPERTY_CONTAINER.get_children():
        if i.get_class() == "EditorInspectorCategory" or tab_idx == 0:
            category_idx += 1
            if _is_new_tab(categories[category_idx]):
                tab_idx += 1

        if tab_idx != idx:
            i.visible = false
        else:
            i.visible = true

# 滚动到目标标签页
func scroll_to_tab(idx: int = 0):
    if idx >= _SCROLL_TAB_BAR.tab_count:
        idx = 0

    _SCROLL_TAB_BAR.current_tab = idx

    if _SCROLL_BOX:
        var tab_rect = _SCROLL_TAB_BAR.get_tab_rect(idx)
        var max_tab_rect = _SCROLL_TAB_BAR.get_tab_rect(_SCROLL_TAB_BAR.tab_count - 1)
        var target_position = min(tab_rect.position.x, max_tab_rect.position.x)

        # 计算滚动距离
        var distance = abs(_SCROLL_BOX.scroll_horizontal - target_position)
        var scroll_speed = 800.0
        var duration = distance / scroll_speed

        var tween = _SCROLL_BOX.create_tween()
        tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
        tween.tween_property(_SCROLL_BOX, "scroll_horizontal", target_position, duration).from_current()
        tab_clicked(idx)

# 检查器GUI输入处理
func _on_inspector_gui_input(event):
    if _SCROLL_TAB_BAR.current_tab < 0:
        return

    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if Input.is_key_pressed(KEY_CTRL):
                match event.button_index:
                    MOUSE_BUTTON_WHEEL_UP:  # 滚轮向上
                        _SCROLL_TAB_BAR.current_tab = max(0, _SCROLL_TAB_BAR.current_tab - 1)
                        tab_clicked(_SCROLL_TAB_BAR.current_tab)
                    MOUSE_BUTTON_WHEEL_DOWN:  # 滚轮向下
                        _SCROLL_TAB_BAR.current_tab = min(_SCROLL_TAB_BAR.tab_count - 1, _SCROLL_TAB_BAR.current_tab + 1)
                        tab_clicked(_SCROLL_TAB_BAR.current_tab)

                scroll_to_tab(_SCROLL_TAB_BAR.current_tab)

# 搜索过滤文本改变
func _on_filter_text_changed(text: String):
    if text != "":
        for i in _PROPERTY_CONTAINER.get_children():
            i.visible = true
        is_filtering = true
    else:
        is_filtering = false

        if enabled_memory_choices and tabs.size() > 1:
            var memory_idx = memory_choices_data.get(tabs[1], 0)
            scroll_to_tab(memory_idx)
        else:
            scroll_to_tab(0)

## 获取图标

# 获取标签页图标
func get_tab_icon(tab) -> Texture2D:
    var load_icon: Texture2D

    if tab.ends_with(".gd"):
        load_icon = get_script_icon(tab)  # 获取脚本自定义图标或GDScript图标
    elif ClassDB.class_exists(tab):
        if ClassDB.class_get_api_type(tab) == ClassDB.APIType.API_EXTENSION:
            load_icon = get_extension_class_icon(tab)  # 获取GDExtension节点图标
        else:
            load_icon = _BASE_CONTROL.get_theme_icon(tab, "EditorIcons")  # 获取编辑器节点图标
    else:
        load_icon = get_script_class_icon(tab)  # 获取脚本类图标

    if load_icon == UNKNOWN_ICON:
        load_icon = _BASE_CONTROL.get_theme_icon("NodeDisabled", "EditorIcons")

    return load_icon

# 获取自定义类名
func get_custom_class_name(_script: GDScript) -> String:
    var _name: String = ""
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

# 获取脚本类图标
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
            image.resize(UNKNOWN_ICON.get_width(), UNKNOWN_ICON.get_height())

            var icon = ImageTexture.create_from_image(image)
            icon_cache = {tab: icon}
            return icon
    return _BASE_CONTROL.get_theme_icon("ArrowLeft", "EditorIcons")

# 获取扩展类图标
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
                image.resize(UNKNOWN_ICON.get_width(), UNKNOWN_ICON.get_height())

                var icon = ImageTexture.create_from_image(image)
                icon_cache = {tab: icon}
                return icon

    return _BASE_CONTROL.get_theme_icon("NodeDisabled", "EditorIcons")

# 获取脚本图标
func get_script_icon(script_path: String) -> Texture2D:
    if !script_path.begins_with("res://"):
        script_path = "res://" + script_path

    var file := FileAccess.open(script_path, FileAccess.READ)
    if not file:
        return _BASE_CONTROL.get_theme_icon("GDScript", "EditorIcons")
    while not file.eof_reached():
        var line := file.get_line().strip_edges()
        if line.begins_with("@icon("):
            var start = line.find("\"") + 1
            var end = line.rfind("\"")
            if start > 0 and end > start:
                var img_path = line.substr(start, end - start)

                if !img_path.begins_with("res://"):  # 如果路径是绝对路径
                    img_path = script_path.substr(0, script_path.rfind("/")) + "/" + img_path

                var texture: Texture2D = load(img_path)
                var image = texture.get_image()
                image.resize(UNKNOWN_ICON.get_width(), UNKNOWN_ICON.get_height())
                return ImageTexture.create_from_image(image)
    return _BASE_CONTROL.get_theme_icon("GDScript", "EditorIcons")

# 加载GDExtension配置文件
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

## 项目配置

# 加载项目配置
func load_project_settings():
    _set_project_cfg(
        KEY_TAB_STYLE, TabStyles.Text_And_Icon,
        TYPE_INT,  PROPERTY_HINT_ENUM, "Text and Icon,Text Only,Icon Only"
    )

    _set_project_cfg(
        KEY_MERGE_ABSTRACT_CLASS_TABST, false,
        TYPE_BOOL,
    )

    _set_project_cfg(
        KEY_ENABLED_MEMORY_CHOICES, true,
        TYPE_BOOL,
    )

    ProjectSettings.save()

# TODO 这是删除项目配置的函数, 目前还没有仅限于关闭插件的信号
func clear_project_settings():
    var _all_settings = [
        KEY_TAB_STYLE,
        KEY_MERGE_ABSTRACT_CLASS_TABST,
        KEY_ENABLED_MEMORY_CHOICES,
    ]
    for key in _all_settings:
        if ProjectSettings.has_setting(key):
            ProjectSettings.clear(key)
    ProjectSettings.save()

# 设置项目配置
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
