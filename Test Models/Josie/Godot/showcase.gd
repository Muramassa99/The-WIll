extends Node3D

var showcase = 0

func _input(event):
	if event.is_action_pressed("1"):
		showcase = 0
	elif event.is_action_pressed("2"):
		showcase = 1
	elif event.is_action_pressed("3"):
		showcase = 2
	elif event.is_action_pressed("4"):
		showcase = 3
	elif event.is_action_pressed("5"):
		showcase = 4
	elif event.is_action_pressed("6"):
		showcase = 5

func _process(delta):
	$Camera.rotation_degrees.y += 1
	
	if showcase == 1:
		$Josie.get_node("AnimationPlayer").play("Walk")
	elif showcase == 2:
		$Josie.get_node("AnimationPlayer").play("SlowRun")
	elif showcase == 3:
		$Josie.get_node("AnimationPlayer").play("Run")
	elif showcase == 4:
		$Josie.get_node("AnimationPlayer").play("Jump(Pose)")
	elif showcase == 5:
		$Josie.get_node("AnimationPlayer").play("Fall(Pose)")
	else:
		$Josie.get_node("AnimationPlayer").play("Idle")
