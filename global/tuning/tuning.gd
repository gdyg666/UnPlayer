extends Resource
class_name Tuning

@export var attack_rate:float = 1.2 #被注视时注意值增速
@export var decay_rate:float = 0.8 #安全时注意值衰减
@export var catch_threshold:float = 1.0 #注意值到此被抓
