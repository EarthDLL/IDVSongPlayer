extends Control

const MIN = 48
const MAX = 83

@onready var import_box: VBoxContainer = %ImportBox
@onready var song_list: VBoxContainer = %SongList
@onready var song_info: PanelContainer = %SongInfo
@onready var song_waiter: HBoxContainer = %SongWaiter
@onready var play_panel: Panel = %Play

var infos := {}
var infos_needed : PackedStringArray  = []

var play_tween : Tween

var click : GodotClickPluginInterface
var screen_size := size
var config := {}
var played := 0
var max_strokes := 20
var has_music := false

func _ready() -> void:
	var file := FileAccess.open("user://config.json",FileAccess.READ)
	if is_instance_valid(file):
		config = JSON.parse_string(file.get_as_text())
		screen_size = Vector2(config.size[0],config.size[1])
		file.close()
	click = GodotClickPluginInterface.new(get_viewport())
	update_songs()

func update_songs() -> void:
	for child : Control in song_list.get_children():
		if child.visible && child.name != "Label":
			child.queue_free()
	await get_tree().create_timer(0.2).timeout
	var files := DirAccess.get_files_at("user://songs/")
	for file_name : String in files:
		if !file_name.ends_with(".json"):
			continue
		var song_name = file_name.replace(".json","")
		var path := "user://songs/" + file_name
		var node := song_info.duplicate()
		song_list.add_child(node)
		node.get_node("Box/Name").text = song_name
		node.get_node("Box/Delete").pressed.connect(delete_song_confirm.bind(song_name,file_name,node.name))
		node.get_node("Box/Play").pressed.connect(play_song.bind(path))
		node.get_node("Box/Info").pressed.connect(info_song.bind(song_name,path))
		node.show()
		
var need_update := -1
#-1 未进入页面 0-不需要更新 1-更新信息 2-更新名字
func info_song(song_name : String,path : String) -> void:
	var song := FileAccess.open(path,FileAccess.READ)
	if !is_instance_valid(song):
		return
	var info := JSON.parse_string(song.get_as_text()) as Dictionary
	if !info.has("length"):
		return
	
	%InfoLabel.text = "时长：%ss\n命中率：%s%%\n音符量：%s\n文件大小：%skb" % [
		str(roundi(info.length/1000.0)),str(roundi(100.0 - (float(info.fixs)/float(info.size))*100.0)),str(info.size),roundi(song.get_length()/1024.0)
	]
	%NameEdit.text = song_name
	%OffestEdit.value = info.offest
	if info.music == "":
		%SongEdit.text = "录入歌曲"
	else:
		%SongEdit.text = "已选择音乐"
	%MusicOffestEdit.value = info.music_offest
	song.close()
	need_update = 0
	%Info.show_out(path)
	
func info_update(path : String , song_path : String) -> void:
	if need_update <= 0:
		return
	var song := FileAccess.open(path,FileAccess.READ)
	if !is_instance_valid(song):
		return
	var info := JSON.parse_string(song.get_as_text()) as Dictionary
	if !info.has("length"):
		return
	info.offest = %OffestEdit.value
	if song_path != "":
		if song_path == "!":
			info.music = ""
		else:
			info.music = song_path
	info.music_offest = %MusicOffestEdit.value
	song = FileAccess.open(path,FileAccess.WRITE)
	song.store_string(JSON.stringify(info))
	song.close()
	if need_update == 2:
		var text : String = %NameEdit.text
		if text.is_valid_filename():
			DirAccess.rename_absolute(path,path.get_base_dir() + "/" + text + ".json")
			update_songs()
	need_update = -1
	
func play_notes(notes : PackedStringArray ,start : PackedInt64Array , time : PackedInt64Array) -> void:
	played += notes.size()
	var positions : PackedFloat32Array = []
	for note : String in notes:
		if config.has(note):
			positions.append(roundf(config[note][0] * screen_size.x))
			positions.append(roundf(config[note][1] * screen_size.y))
	click.multi_touch(positions,start,time)
	#print("positions:%s , start:%s , time :%s" % [str(positions),str(start),str(time)])
		
func play_song(path : String) -> void:
	if OS.get_name() == "Android":
		max_strokes = click.get_max_strokes()
	play_panel.show()
	if is_instance_valid(play_tween):
		if play_tween.is_running():
			play_tween.kill()
	var song := FileAccess.open(path ,FileAccess.READ)
	if !is_instance_valid(song):
		quit()
		return
	has_music = false
	timer = null
	%Audio.stream = null
	var info := JSON.parse_string(song.get_as_text()) as Dictionary
	song.close()
	play_tween = create_tween()
	var actual_start := 0
	var start_time := 0
	var finish_time := 0
	var repeat_count := 0
	var total_note := 0.0
	var offest : float = info.offest
	
	var notes : PackedStringArray = []
	var start : PackedInt64Array = []
	var time : PackedInt64Array = []
	
	for index in info.tracks.size():
		var track : Dictionary = info.tracks[index]
		if notes.size() != 0:
			if track.start < finish_time  && repeat_count < min(max_strokes,8):
				repeat_count += 1
				notes.append(track.note)
				var this_start := int(track.start - start_time)
				for i in start.size():
					if this_start == start[i] + time[i]:
						this_start += 1
				start.append(this_start)
				time.append(int(track.duration))
				finish_time = max((this_start + start_time) + track.duration,finish_time)
			else:
				play_tween.tween_interval(max(((start_time - actual_start)/1000.0) + offest/1000.0,0.001))
				total_note += notes.size()
				#print("total note:",total_note)
				#print("notes:%s , start:%s , time :%s" % [str(notes),str(start),str(time)])
				play_tween.tween_callback(play_notes.bind(notes,start,time))
				repeat_count = 1
				notes = [track.note]
				start = [0]
				time = [int(track.duration)]
				actual_start = start_time
				start_time = track.start
				finish_time = start_time + track.duration
		if notes.size() == 0:
			repeat_count = 1
			start_time = track.start
			finish_time = start_time + track.duration
			notes.append(track.note)
			start.append(0)
			time.append(int(track.duration))
		if index == info.tracks.size()-1:
			play_tween.tween_interval(max(((start_time - actual_start)/1000.0) + offest,0.001))
			total_note += notes.size()
			print("total note:",total_note)
			play_tween.tween_callback(play_notes.bind(notes,start,time))
				
	play_tween.finished.connect(quit)
	
	if info.music != "" && FileAccess.file_exists(info.music):
		var audio := AudioStreamMP3.load_from_file(info.music)
		if is_instance_valid(audio):
			has_music = true
			%Audio.set_stream(audio)
			var start_point := 0.0
			if info.music_offest < 0:
				start_point = -info.music_offest
			if info.music_offest > 0:
				timer = create_tween()
				timer.tween_interval(info.music_offest)
				timer.pause()
				timer.finished.connect(start_play)
			%Audio.play(start_point)
			%Audio.set_stream_paused(true)
	
	change_status(1)
	
func conti() -> void:
	if status == 0:
		change_status(1)
		
var wait : Tween
var timer : Tween 

var status := 0
func change_status(_status : int) -> void:
	status = _status
	match _status:
		0:
			%Status.text = "暂停"
			play_tween.pause()
			if is_instance_valid(wait) && wait.is_running():
				wait.kill()
			if has_music:
				if is_instance_valid(timer):
					timer.pause()
				else:
					%Audio.set_stream_paused(true)
		1:
			%Status.text = "等待程序进入后台中(5s)"
			play_tween.pause()
			if is_instance_valid(wait) && wait.is_running():
				wait.kill()
			wait = create_tween()
			wait.tween_interval(5.0)
			wait.finished.connect(change_status.bind(2))
		2:
			%Status.text = "播放中"
			if has_music:
				if is_instance_valid(timer):
					timer.play()
				else:
					%Audio.set_stream_paused(false)
			play_tween.play()
			
func _physics_process(_delta: float) -> void:
	if status == 2:
		%Status.text = "播放中...\n已播放：%s" % [str(played)]
	
func start_play() ->void:
	%Audio.stream_paused = false
	timer = null
	
func quit() -> void:
	play_panel.hide()
	played = 0
	change_status(0)
	if is_instance_valid(play_tween):
		if play_tween.is_running():
			play_tween.kill()
	if is_instance_valid(wait) && wait.is_running():
		wait.kill()
		
var will_delete_song := []

func delete_song_confirm(song_name : String,file_name : String , node_name : String) -> void:
	var path := "user://songs/"+file_name
	will_delete_song.resize(0)
	will_delete_song.append(path)
	will_delete_song.append(node_name)
	%DeleteInfoLabel.text  = "你确定要删除歌曲\"%s\"？" % [song_name]
	%DeleteConfirm.show()

func delete_song() ->void:
	if FileAccess.file_exists(will_delete_song[0]):
		DirAccess.remove_absolute(will_delete_song[0])
	var node := song_list.get_node(will_delete_song[1])
	if is_instance_valid(node):
		node.queue_free()

func _on_import_pressed() -> void:
	DisplayServer.file_dialog_show("Open",OS.get_system_dir(OS.SYSTEM_DIR_MUSIC),"",true,DisplayServer.FILE_DIALOG_MODE_OPEN_FILES,[],import_songs)
		
func import_songs(_status: bool, selected_paths: PackedStringArray, _selected_filter_index: int) ->void:
	if ! _status:
		return
	for path : String in selected_paths:
		var info := parse_song(path)
		if info.has("length"):
			var file_name := path.get_basename().replace(path.get_base_dir(),"").right(-1)
			info["name"] = file_name
			infos[file_name] = info
		import_panel()
			
func import_panel() -> void:
	for child : Control in import_box.get_children():
		if child.visible:
			child.queue_free()
	for key : String in infos:
		var info : Dictionary = infos[key]
		var node := song_waiter.duplicate()
		var btn : CheckBox = node.get_node("Button")
		btn.text = info.name
		btn.toggled.connect(add_needed.bind(info.name))
		node.get_node("Label").text = "命中率:%s%%;时长:%ss" % [str(roundi(100.0 - (float(info.fixs)/float(info.size))*100.0)),str(roundi(info.length/1000.0))]
		import_box.add_child(node)
		node.show()
	%ImportPanel.show() 
		
func add_needed(_status : bool , song_name : String) -> void:
	if _status:
		if !infos_needed.has(song_name):
			infos_needed.append(song_name)
	else:
		infos_needed.erase(song_name)
		
func import(all : bool) -> void:
	if all:
		infos_needed = PackedStringArray(infos.keys())
	%ImportPanel.hide()
	for file_name : String in infos_needed: 
		var file := FileAccess.open("user://songs/"+file_name+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(infos[file_name]))
		file.close()
	update_songs()
	infos = {}
	infos_needed = []
		
func parse_song(path : String) -> Dictionary:
	var parser = MidiFileParser.load_file(path)
	var dic := {}
	if parser.tracks.size() == 0:
		return dic
	
	# 遍历所有音轨（通常选第一个主旋律轨）
	var tracks := []
	var fixs := 0
	
	var ms_per_tick : float = 60000.0 / (120 * 480.0)
	# 遍历该音轨的 Meta 事件，找到速度变化
	for meta in parser.tracks[0].meta:
		if meta.type == MidiFileParser.Meta.Type.SET_TEMPO:
		# 插件在解析时已经算好了这个值！
			ms_per_tick = meta.ms_per_tick
			break 
	for track in parser.tracks:
		var note_on_events = {}  # 用来配对 NOTE_ON 和 NOTE_OFF，计算时长
		for midi in track.midi:
			var is_repeat := false
			var is_abnormal := false #特殊p2 = 0 => NOTE_OFF
			if midi.status == MidiFileParser.Midi.Status.NOTE_ON:
				if midi.param2 == 0:
					is_abnormal = true
				elif note_on_events.has(midi.param1):
					is_repeat = true
				else:
					note_on_events[midi.param1] = midi.absolute_ticks
			if midi.status == MidiFileParser.Midi.Status.NOTE_OFF || is_repeat || is_abnormal:
				var pitch = midi.param1
				if note_on_events.has(pitch):
					var start = note_on_events[pitch]
					var duration = (midi.absolute_ticks - start)
					# 将音高编号转为简谱数字
					var note_num = pitch
					var is_fixed := false
					while note_num > MAX:
						note_num -=12
						is_fixed = true
					while note_num < MIN:
						note_num += 12
						is_fixed = true
					
					
					start = start * ms_per_tick
					duration = duration * ms_per_tick
					if is_repeat :
						duration -= 20
					
					#print("%d\t%s\t%d\t%d" % [start, midi.note_name, note_num, duration])
					tracks.append({
						"start" : int(start),
						"duration" : int(duration),
						"note" : str(note_num),
						"fixed" : is_fixed
					})
					if is_fixed:
						fixs += 1
					# 你可以写入文件
					if is_repeat:
						note_on_events[midi.param1] = midi.absolute_ticks
					else:
						note_on_events.erase(pitch)
	tracks.sort_custom(func(a,b):return a["start"] < b["start"])
	var length : float = 0
	length = tracks[tracks.size()-1].start + tracks[tracks.size()-1].duration
	dic["length"] = length
	dic["fixs"] = fixs
	dic["size"] = tracks.size()
	dic["tracks"] = tracks
	dic["offest"] = 0
	dic["music"] = ""
	dic["music_offest"] = 0
	return dic


func pause() -> void:
	change_status(0)

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_delete_confirm_pressed() -> void:
	delete_song()
	%DeleteConfirm.hide()

func _on_delete_cancel_pressed() -> void:
	%DeleteConfirm.hide()

func update(value : float = 0 , is_name : bool = false) ->void:
	if need_update == -1 || need_update == 2:
		return
	if is_name:
		need_update = 2
	else:
		need_update = 1
		
func _on_music_drag_ended(value_changed: bool) -> void:
	if value_changed:
		%Audio.volume_db = linear_to_db(%Music.value)
