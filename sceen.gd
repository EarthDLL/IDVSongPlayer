extends Control

const CIRCLE_SIZE = 10
const MIN = 48
const MAX = 83
const white_table : PackedInt32Array = [0,2,4,5,7,9,11]
const black_table : PackedInt32Array = [1,3,99999,6,8,10,11]

@onready var white_weight: HSlider = %WhiteWeight
@onready var white_height: HSlider = %WhiteHeight
@onready var black_height: HSlider = %BlackHeight
@onready var black_weight: HSlider = %BlackWeight

@onready var white_offest_x: HSlider = %WhiteOffestX
@onready var black_offest_x: HSlider = %BlackOffestX
@onready var black_offest_y: HSlider = %BlackOffestY
@onready var white_offest_y: HSlider = %WhiteOffestY


@onready var bg: TextureRect = $BG

var file : FileAccess
var screen = {}

func save(changed : bool = true) -> void:
	if !changed:
		return
		
	screen["white_weight"] = white_weight.value
	screen["white_height"] = white_height.value
	screen["black_height"] = black_height.value
	screen["black_weight"] = black_weight.value
	
	screen["black_offest_x"] = black_offest_x.value
	screen["black_offest_y"] = black_offest_y.value
	screen["white_offest_x"] = white_offest_x.value
	screen["white_offest_y"] = white_offest_y.value
		
	file = FileAccess.open("user://screen.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(screen))
	file.close()
	
	var config := {}
	config["size"] = [get_tree().root.size.x,get_tree().root.size.y]
	
	var white_offest := Vector2(white_offest_x.value,white_offest_y.value)
	var black_offest := Vector2(black_offest_x.value,black_offest_y.value)
	var center_pos := get_size()/2.0
	#白键
	for y in range(-1,2,1):
		for x : int in range(-3,4,1):
			var index := MIN + (y+1) * 12 + white_table[x + 3]
			var pos := center_pos + white_offest + Vector2(x * white_weight.value,-y * white_height.value)
			var result := pos/size
			config[index] = [result.x,result.y]
			#print("index:",index, "  " ,"pos:", pos/size)
			
	#黑键
	for x in range(-2,4,1):
		for y in range(-1,2,1):
			if x != 0:
				var index := MIN + (y+1) * 12 + black_table[x + 2]
				var pos := center_pos + black_offest + Vector2(x * black_weight.value,-y * black_height.value)
				var result := pos/size
				config[index] = [result.x,result.y]
				#print("index:",index, "  " ,"pos:", pos/size)
				
	file = FileAccess.open("user://config.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(config))
	file.close()
	
func _draw() -> void:
	var center_pos := get_size()/2.0
	var white_offest := Vector2(white_offest_x.value,white_offest_y.value)
	for x in range(-3,4,1):
		for y in range(-1,2,1):
			draw_circle(center_pos + white_offest + Vector2(x * white_weight.value,y * white_height.value),CIRCLE_SIZE,Color.WHITE,true)
	
	var black_offest := Vector2(black_offest_x.value,black_offest_y.value)
	for x in range(-2,4,1):
		for y in range(-1,2,1):
			if x != 0:
				draw_circle(center_pos + black_offest + Vector2(x * black_weight.value,y * black_height.value),CIRCLE_SIZE,Color.RED,true)
	
func value_changed(_value : float) -> void:
	queue_redraw()

func _ready() -> void:
	get_tree().get_root().size_changed.connect(queue_redraw)
	white_weight.connect("value_changed",value_changed)
	white_height.connect("value_changed",value_changed)
	black_height.connect("value_changed",value_changed)
	black_weight.connect("value_changed",value_changed)
	white_offest_x.connect("value_changed",value_changed)
	white_offest_y.connect("value_changed",value_changed)
	black_offest_x.connect("value_changed",value_changed)
	black_offest_y.connect("value_changed",value_changed)
	
	white_weight.connect("drag_ended",save)
	white_height.connect("drag_ended",save)
	white_offest_x.connect("drag_ended",save)
	white_offest_y.connect("drag_ended",save)
	black_offest_x.connect("drag_ended",save)
	black_offest_y.connect("drag_ended",save)
	black_weight.connect("drag_ended",save)
	black_height.connect("drag_ended",save)

	
	file = FileAccess.open("user://screen.json",FileAccess.READ)
	if is_instance_valid(file):
		var dic : Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
		if dic.has("white_weight"):
			white_height.value = dic.white_height
			white_weight.value = dic.white_weight
			black_height.value = dic.black_height
			black_weight.value = dic.black_weight
			white_offest_x.value = dic.white_offest_x
			white_offest_y.value = dic.white_offest_y
			black_offest_x.value = dic.black_offest_x
			black_offest_y.value = dic.black_offest_y
		if dic.has("bg"):
			var image := Image.load_from_file(dic.bg)
			if is_instance_valid(image):
				bg.texture = ImageTexture.create_from_image(image)
		file.close()
		screen = dic
	
func import_bg() -> void:
	DisplayServer.file_dialog_show("打开图片",OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),"",true,DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,["*.jpg,*.png"],
	func(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int):
		if status && selected_paths.size() == 1:
			var path := selected_paths[0]
			var image := Image.load_from_file(path)
			if is_instance_valid(image):
				bg.texture = ImageTexture.create_from_image(image)
				var final_path := "user://" + path.get_file()
				DirAccess.copy_absolute(path,final_path)
				screen["bg"] = final_path
				save()
		)


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")
