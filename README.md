# Godot 检查器标签页 (这是一个分支版本)
Godot 编辑器插件，用于将检查器属性分类到独立标签页中，从而缩短面板长度，减少滚动操作。

垂直模式           |  水平模式
:-------------------------:|:-------------------------:
![V](https://github.com/user-attachments/assets/b9aec875-a6c5-4532-8b10-1b076e1875b7)  |  ![H](https://github.com/user-attachments/assets/2b3549a1-0e04-42a5-850b-33d104675a1f)



- 支持水平/垂直标签页布局（项目设置/inspector_tabs/tab_layout）
- 可自定义标签页是否显示文字和图标（项目设置/inspector_tabs/tab_style）
- 跳转滚动模式：不同标签页的属性不会隐藏（项目设置/inspector_tabs/tab_property_mode）

- 可将抽象类属性合并到子类标签页，便于查找（项目设置/inspector_tabs/merge_abstract_class_tabs）
- 内置属性过滤器支持跨标签页搜索
- 支持自定义脚本类和GDExtension类
- 收藏的属性会在所有标签页中显示
- 在检查器区域使用Ctrl+滚轮快速切换标签页
- 节点标签页记忆功能，不会因为切换不同类型节点而失去当前类型聚焦的标签页(可在项目设置中禁用此功能)

安装方法：
- 下载文件
- 将插件文件夹放置于项目根目录
- 在项目中进入项目设置/插件界面启用`inspector_tabs`


当你在某个项目移除插件时，可能需要清理`project.godot`里的条目, 以确保项目设置整洁干净
