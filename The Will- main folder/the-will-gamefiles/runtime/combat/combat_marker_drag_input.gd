extends RefCounted

## Screen-space input valve, shared by all dragged scene markers. It does not
## modify body rules, node timing or camera input. Excess demand is discarded.
const DEFAULT_SPEED_PIXELS_PER_SECOND := 180.0
const MAX_SAMPLE_SECONDS := 1.0 / 60.0

var active := false
var target: StringName = StringName()
var pointer_position := Vector2.ZERO
var speed_pixels_per_second := DEFAULT_SPEED_PIXELS_PER_SECOND
var _pending_relative := Vector2.ZERO
var _sample_usec: int = 0

func begin(drag_target: StringName, position: Vector2, now_usec: int) -> void:
	active = true
	target = drag_target
	pointer_position = position
	_pending_relative = Vector2.ZERO
	_sample_usec = now_usec

func add_motion(screen_relative: Vector2) -> void:
	if active and screen_relative.is_finite():
		_pending_relative += screen_relative

func take_motion(now_usec: int) -> Vector2:
	var elapsed := clampf(float(now_usec - _sample_usec) / 1000000.0, 0.0, MAX_SAMPLE_SECONDS)
	_sample_usec = now_usec
	var requested := _pending_relative
	_pending_relative = Vector2.ZERO
	if not active or elapsed <= 0.0:
		return Vector2.ZERO
	# Never bank idle time or a stalled frame as permission for a large jump.
	return requested.limit_length(maxf(speed_pixels_per_second, 0.0) * elapsed)

func finish() -> void:
	active = false
	target = StringName()
	_pending_relative = Vector2.ZERO
	_sample_usec = 0
