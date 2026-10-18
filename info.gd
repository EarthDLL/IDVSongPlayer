extends Panel

signal quit

var path := ""
var song_path := ""

func show_out(_path : String) -> void:
	path = _path
	song_path = ""
	show()
	update_offest(%OffestEdit.value)
	update_music_offest(%MusicOffestEdit.value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch && event.is_pressed():
		hide()
		emit_signal("quit",path,song_path)
	
func change_song_path() -> void:
	DisplayServer.file_dialog_show("打开音乐文件",OS.get_system_dir(OS.SYSTEM_DIR_MUSIC),"",true,DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,["*.mp3"],
	func(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int):
		if status && selected_paths.size() == 1:
			song_path = selected_paths[0]
			%SongEdit.text = "已选择音乐"
		else:
			song_path = "!"
		)

func update_offest(value : float) -> void:
	%OffestLabel.text = "音符间隔:%sms" % [str(value)]
func update_music_offest(value : float) -> void:
	%MusicOffestLabel.text = "歌曲播放时间偏移:%ss" % [str(value)]
