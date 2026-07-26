class_name AudioUtil
extends RefCounted
## Small shared helper for the team's placeholder sfx: single-note "boop"/"tick"
## samples rather than pre-looped ambience, so several of them need to be told
## to loop cleanly before they're used anywhere.

## Sets `stream` to loop across its full length. Computed from the actual
## sample data rather than assumed, so it holds regardless of the clip's rate,
## channel count or bit depth. Idempotent — safe to call more than once on the
## same (cached, shared) preloaded resource.
static func configure_loop(stream: AudioStreamWAV) -> void:
	if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		return

	var bytes_per_sample: int = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var channels: int = 2 if stream.stereo else 1

	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / (bytes_per_sample * channels)
