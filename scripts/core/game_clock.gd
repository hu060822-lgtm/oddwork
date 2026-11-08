class_name GameClock
extends RefCounted
## Unpaused real-time clock in milliseconds. Advanced by Main every frame.
## Used instead of the OS clock so cooldowns freeze while paused and tests
## running with --fixed-fps stay deterministic.

static var ms: int = 0
static var _acc: float = 0.0


static func advance(real_dt: float) -> void:
	_acc += real_dt * 1000.0
	var whole := int(_acc)
	ms += whole
	_acc -= whole
