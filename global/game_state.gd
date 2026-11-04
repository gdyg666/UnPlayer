extends Node

signal caught
signal won

enum Phase{PLAYING,PAUSED,WON,CAUGHT}

var phase:Phase

func set_phase(p:Phase) -> void:
	if p == phase:return
	phase_changed(p)
	
func is_playing():
	return phase == Phase.PLAYING

func reset() -> void:
	phase = Phase.PLAYING
	
func phase_changed(new:Phase) -> void:
	phase = new
