extends Node

export var bpm := 124
export var start_delay := 0.0
export var start_immediately := true
export var video_delay := 1.43

var start_time := 0.0
var time_delay := 0.0
var bps := 60.0 / bpm
var last_beat := 0
var multiplier := 1.0
var last_time := 0.0

onready var stream := $AudioStreamPlayer
onready var timer := $Timer
onready var sprite := $Sprite
onready var tween := $Tween


func _ready() -> void:
	if start_immediately:
		play_audio()


func play_audio() -> void:
	time_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	timer.start(time_delay+start_delay)
	yield(timer, "timeout")
	stream.play()


func _process(delta: float) -> void:
	var time: float = (
		stream.get_playback_position() + 
		AudioServer.get_time_since_last_mix() - 
		AudioServer.get_output_latency()
	)
	last_time = time
	var beat := int(time/bps)
	if beat > last_beat:
		last_beat = beat
		tween.interpolate_property(
			sprite,
			"scale",
			Vector2.ONE,
			Vector2.ONE*2, bps/32, Tween.TRANS_LINEAR, Tween.EASE_OUT)
		tween.interpolate_property(
			sprite,
			"scale",
			Vector2.ONE*2,
			Vector2.ONE, bps/4, Tween.TRANS_LINEAR, Tween.EASE_OUT, bps/32)
		tween.start()
	if Input.is_action_just_pressed("trigger_test"):
		print("Process: " + str(last_time - OS.get_ticks_usec()/1000000.0+video_delay))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("trigger_test"):
		print("Input: " + str(last_time - OS.get_ticks_usec()/1000000.0+video_delay))
