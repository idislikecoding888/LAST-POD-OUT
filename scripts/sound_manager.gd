
extends Node

## Runtime-generated audio for LAST POD OUT.
## Add as an autoload named SoundManager.

@export var sample_rate: int = 22050
@export var buffer_seconds: float = 0.3
@export var master_volume: float = 0.8

var _generator: AudioStreamGenerator
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

var _voices: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

var _lowpass: AudioEffectLowPassFilter
var _vacuum_active: bool = false

var _critical_players: Dictionary = {}
var _heartbeat_clock: float = 0.0


func _ready() -> void:
	_rng.randomize()

	# Create dynamic low-pass filter on the Master bus.
	var master_index := AudioServer.get_bus_index("Master")

	if master_index >= 0:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(master_index, _lowpass)

	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = float(sample_rate)
	_generator.buffer_length = buffer_seconds

	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralPCMPlayer"
	_player.stream = _generator
	_player.volume_db = linear_to_db(master_volume)
	add_child(_player)

	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null:
		return

	var available := _playback.get_frames_available()
	var frame_count := mini(available, 512)

	for frame_index in range(frame_count):
		var sample: float = 0.0

		# One-shot effect voices.
		for index in range(_voices.size() - 1, -1, -1):
			var voice: Dictionary = _voices[index]

			var elapsed: float = voice["elapsed"]
			var duration: float = voice["duration"]

			if elapsed >= duration:
				_voices.remove_at(index)
				continue

			var frequency: float = voice["frequency"]
			var amplitude: float = voice["amplitude"]
			var noise_mix: float = voice["noise_mix"]

			var phase: float = voice["phase"]
			var tone := sin(TAU * phase)
			var noise := _rng.randf_range(-1.0, 1.0)

			var attack := minf(1.0, elapsed * 70.0)
			var release := minf(1.0, (duration - elapsed) * 12.0)
			var envelope := attack * release

			var signal_value := lerpf(tone, noise, noise_mix)

			sample += signal_value * amplitude * envelope

			phase = fposmod(
				phase + frequency / float(sample_rate),
				1.0
			)

			voice["phase"] = phase
			voice["elapsed"] = elapsed + 1.0 / float(sample_rate)
			_voices[index] = voice

		# Continuous vacuum static.
		if _vacuum_active:
			sample += _rng.randf_range(-1.0, 1.0) * 0.065

		# Oxygen heartbeat.
		if not _critical_players.is_empty():
			_heartbeat_clock = fposmod(
				_heartbeat_clock + 1.0 / float(sample_rate),
				1.0
			)

			var beat := maxf(
				0.0,
				1.0 - absf(_heartbeat_clock - 0.10) * 12.0
			)

			var heartbeat := sin(
				TAU * 48.0 * _heartbeat_clock
			)

			sample += heartbeat * beat * 0.24

		sample = clampf(sample, -0.95, 0.95)

		_playback.push_frame(Vector2(sample, sample))


func _voice(
	frequency: float,
	duration: float,
	amplitude: float,
	noise_mix: float = 0.0
) -> void:

	_voices.append({
		"frequency": frequency,
		"duration": duration,
		"amplitude": amplitude,
		"noise_mix": noise_mix,
		"phase": 0.0,
		"elapsed": 0.0
	})


func play_impact() -> void:
	# Bass punch + metallic transient.
	_voice(68.0, 0.19, 0.65)
	_voice(950.0, 0.075, 0.34, 0.82)


func play_parry() -> void:
	# Rising metallic clink.
	_voice(1250.0, 0.075, 0.35)
	_voice(1950.0, 0.15, 0.28)


func play_intercom_beep() -> void:
	_voice(740.0, 0.08, 0.19)
	_voice(990.0, 0.13, 0.16)


func play_typewriter_tick() -> void:
	_voice(1800.0, 0.018, 0.07, 0.25)


func play_betrayal() -> void:
	_voice(180.0, 0.22, 0.35)
	_voice(280.0, 0.30, 0.25)
	_voice(75.0, 0.35, 0.45)


func play_tase() -> void:
	_voice(2100.0, 0.11, 0.32, 0.1)
	_voice(90.0, 0.18, 0.22)


func play_airlock_start() -> void:
	_voice(58.0, 0.6, 0.5)
	_voice(500.0, 0.4, 0.18, 0.9)
	set_vacuum_active(true)


func set_vacuum_active(active: bool) -> void:
	_vacuum_active = active
	_update_filter()


func set_critical_player(player_id: int, active: bool) -> void:
	if active:
		_critical_players[player_id] = true
	else:
		_critical_players.erase(player_id)

	_update_filter()


func _update_filter() -> void:
	if _lowpass == null:
		return

	if _vacuum_active:
		_lowpass.cutoff_hz = 650.0
	elif not _critical_players.is_empty():
		_lowpass.cutoff_hz = 1250.0
	else:
		_lowpass.cutoff_hz = 20500.0


func reset_round() -> void:
	_vacuum_active = false
	_critical_players.clear()
	_voices.clear()
	_heartbeat_clock = 0.0
	_update_filter()
