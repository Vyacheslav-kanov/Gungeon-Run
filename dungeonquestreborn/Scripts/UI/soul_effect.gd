extends Node2D

@onready var label = $Label
@onready var anim = $AnimationPlayer

func show_amount(amount: int, is_large: bool = false):
	label.text = "+%d" % amount
	
	if is_large:
		label.modulate = Color(1, 0.8, 0)  # Золотой для больших душ
		label.scale = Vector2(1.3, 1.3)
	else:
		label.modulate = Color.WHITE
		label.scale = Vector2(1.0, 1.0)
	
	anim.play("float_up")

func _on_AnimationPlayer_animation_finished(anim_name):
	queue_free()
