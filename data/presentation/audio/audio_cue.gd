class_name AudioCue
extends Resource

## Presentation-only music metadata. The stream is resolved lazily from path so
## unavailable audio degrades to silence without blocking scene activation.

@export var id: StringName = &""
@export_file("*.ogg", "*.wav", "*.mp3") var stream_path: String = ""
@export var bpm: float = 120.0
@export_range(1, 12, 1) var beats_per_bar: int = 4
@export var loop: bool = true
@export_range(-24.0, 6.0, 0.1) var volume_db: float = 0.0
@export var approved_surfaces: Array[StringName] = []


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not stream_path.is_empty()
		and bpm > 0.0
		and beats_per_bar > 0
		and ResourceLoader.exists(stream_path)
	)


func seconds_per_bar() -> float:
	if bpm <= 0.0:
		return 0.0
	return (60.0 / bpm) * float(beats_per_bar)
