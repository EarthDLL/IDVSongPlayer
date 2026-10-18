extends Control

@onready var label: Label = $Label
@onready var songs: Button = $Box/Songs

var is_music_enabled := true

func _ready() -> void:
	OS.request_permissions()
	if !FileAccess.file_exists("user://config.json"):
		songs.hide()
		is_music_enabled = false
	if !DirAccess.dir_exists_absolute("user://songs/"):
		DirAccess.make_dir_absolute("user://songs/")

func test() -> void:
	var click := GodotClickPluginInterface.new(get_viewport())
	label.text = "是否可用:"
	if click.is_available():
		label.text += "✔"
	else:
		label.text += "✘"
	label.text += "      无障碍功能开启:"
	if click.is_service_enabled():
		label.text += "✔"
	else:
		label.text += "✘"
	label.text += "\n最大模拟数：%s(推荐使用>=8的设备，模拟数较小时播放教复杂歌曲可能会产生部分部分混乱)" % [str(click.get_max_strokes())]
	if click.is_available() && !click.is_service_enabled():
		click.open_accessibility_settings()
		

func _on_screen_pressed() -> void:
	get_tree().change_scene_to_file("res://Screen.tscn")
	
func _on_songs_pressed() -> void:
	get_tree().change_scene_to_file("res://Songs.tscn")

	

			
#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventScreenTouch:
		#var sprite := Sprite2D.new()
		#sprite.texture = load("res://icon.svg")
		#sprite.position = event.get_position()
		#sprite.scale = Vector2(0.3,0.3)
		#add_child(sprite)
