extends Node3D
class_name Player

enum State{PLAYING,HIDE}

signal finished #被发现，游戏结束
@export var mouse_sensitivity: float = 0.002 #镜头移动速度
@export var transition_time:float = 0.35 #抬起/放下手机的过渡时长（秒）
@export var exposure_hidden:float = 0.0 #收手时暴露度
@export var exposure_phone:float =1.0 # 举着手机时暴露度
@export var exposure_transition:float = 0.6 #过渡中的暴露度（主题所在）
@export var cam_pitch_hidden:float = 0 #抬头时的相机俯角
@export var cam_pithc_phone:float = -40.0 #低头时的相机俯角
@export var play_phone_pos:Vector3 = Vector3(0,-0.05,-0.4) #玩手机时手机高度
@export var hide_phone_pos:Vector3 = Vector3(0,-0.4,-0.3) #隐藏手机时手机高度
@export var play_phone_fov:float = 30 #玩手机时镜头广角
@export var hide_phone_fov:float = 75 #隐藏手机时镜头广角

@onready var camera: Camera3D = %Camera3D
@onready var phone_rig: Node3D = %PhoneRig

var exposure:float = 0.0 #暴露度数
var playing:bool = false #是否游玩
var progress:float = 0.0#完成进度
var state:State = State.HIDE

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("is_play"):
		if not playing:
			state = State.PLAYING
			playing = true
		else:
			state = State.HIDE
			playing = false
	check_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not playing:
		# 水平旋转：绕Y轴旋转整个角色
		rotate_y(-event.relative.x * mouse_sensitivity)

func check_camera() -> void:
	if state == State.HIDE:
		camera.rotation_degrees.x = cam_pitch_hidden
		phone_rig.global_position = camera.global_position +(camera.global_basis * hide_phone_pos)
		camera.fov = hide_phone_fov
	elif state == State.PLAYING:
		camera.rotation_degrees.x = cam_pithc_phone
		phone_rig.global_position = camera.global_position  +(camera.global_basis * play_phone_pos)
		camera.fov = play_phone_fov
