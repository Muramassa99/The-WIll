extends RefCounted
class_name PlayerRigLocomotionPresenter

var current_animation_name: StringName = StringName()

func get_current_animation_name() -> StringName:
	return current_animation_name

func has_animation_name(animation_player: AnimationPlayer, animation_name: StringName) -> bool:
	if animation_player == null or animation_name == StringName():
		return false
	return animation_player.has_animation(String(animation_name))

func play_default_animation(animation_player: AnimationPlayer, default_animation_name: StringName) -> void:
	play_animation(animation_player, default_animation_name, 0.18, 0.0)

func update_locomotion_state(
	animation_player: AnimationPlayer,
	horizontal_speed: float,
	target_horizontal_speed: float,
	grounded: bool,
	vertical_velocity: float,
	sprinting: bool,
	config: Dictionary
) -> void:
	var target_animation_name: StringName = resolve_locomotion_animation_name(
		horizontal_speed,
		target_horizontal_speed,
		grounded,
		vertical_velocity,
		sprinting,
		config
	)
	play_animation(
		animation_player,
		target_animation_name,
		float(config.get("animation_blend_seconds", 0.18))
	)

func resolve_locomotion_animation_name(
	horizontal_speed: float,
	target_horizontal_speed: float,
	grounded: bool,
	vertical_velocity: float,
	sprinting: bool,
	config: Dictionary
) -> StringName:
	var jump_vertical_velocity_threshold: float = float(config.get("jump_vertical_velocity_threshold", 0.12))
	if not grounded:
		if vertical_velocity >= jump_vertical_velocity_threshold:
			return config.get("jump_animation_name", &"Jump(Pose)")
		return config.get("fall_animation_name", &"Fall(Pose)")

	var idle_horizontal_speed_threshold: float = float(config.get("idle_horizontal_speed_threshold", 0.08))
	if horizontal_speed <= idle_horizontal_speed_threshold:
		return config.get("default_animation_name", &"Idle")

	var resolved_target_speed: float = maxf(target_horizontal_speed, 0.001)
	var speed_ratio: float = clampf(horizontal_speed / resolved_target_speed, 0.0, 1.5)
	if sprinting:
		return config.get("sprint_animation_name", &"Run")
	var walk_ratio_threshold: float = float(config.get("walk_ratio_threshold", 0.45))
	if speed_ratio < walk_ratio_threshold:
		return config.get("walk_animation_name", &"Walk")
	return config.get("jog_animation_name", &"SlowRun")

func play_animation(
	animation_player: AnimationPlayer,
	animation_name: StringName,
	animation_blend_seconds: float,
	custom_blend_seconds: float = -1.0
) -> void:
	if animation_player == null or animation_name == StringName():
		return
	if not animation_player.has_animation(String(animation_name)):
		return
	if current_animation_name == animation_name:
		return
	var blend_seconds: float = animation_blend_seconds if custom_blend_seconds < 0.0 else custom_blend_seconds
	animation_player.play(String(animation_name), blend_seconds)
	current_animation_name = animation_name
