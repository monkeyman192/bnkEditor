extends Node

onready var AudioPlayer: AudioStreamPlayer = $AudioPlayer
onready var NowPlayingLabel: Label = $NowPlayingLabel
onready var PlayProgressBar: ProgressBar = $PlayProgressBar
onready var ProgressLabel: Label = $ProgressLabel
onready var PlayPauseButton: TextureButton = $PlayPauseButton

var EXPORT_ON_PLAY: bool = false

var is_playing: bool = false
var current_audio_length: float = 0
enum STATE {STOPPED, PLAYING, PAUSED}
var play_state = STATE.STOPPED


func play_audio(file_name: String, wem: WEM):
	# play the specified audio.
	self.current_audio_length = wem.audio_length
	var ogg_data: PoolByteArray = wem.to_ogg()

	if EXPORT_ON_PLAY:
		var f = File.new()

		if f.open("exported/%s.ogg" % file_name.get_basename(), f.WRITE) != OK:
			print("Can't write to the file")

		f.store_buffer(ogg_data)
		f.close()

	NowPlayingLabel.text = "playing %s" % file_name
	var audio_stream := AudioStreamOGGVorbis.new()
	audio_stream.data = ogg_data
	AudioPlayer.stream = audio_stream
	self.is_playing = true
	PlayProgressBar.max_value = self.current_audio_length
	# Set the play button to pressed so that it shows the pause button.
	PlayPauseButton.pressed = true
	AudioPlayer.play()
	self.play_state = STATE.PLAYING


func _process(_delta):
	# Only update UI elements if the audio is playing.
	if self.is_playing:
		var audio_pos = AudioPlayer.get_playback_position()
		PlayProgressBar.value = audio_pos
		ProgressLabel.text = "%.2fs / %.2fs" % [audio_pos, self.current_audio_length]


func _on_AudioPlayer_finished():
	self.is_playing = false
	self.play_state = STATE.STOPPED


func _on_StopButton_pressed():
	AudioPlayer.stop()
	ProgressLabel.text = "%.2fs / %.2fs" % [0, self.current_audio_length]
	PlayProgressBar.value = 0
	PlayPauseButton.pressed = false
	self.is_playing = false
	self.play_state = STATE.STOPPED


func _on_PlayPauseButton_toggled(button_pressed):
	if button_pressed:
		# Play the audio
		AudioPlayer.stream_paused = false
		self.is_playing = true
		self.play_state = STATE.PLAYING
	else:
		# Pause the audio
		AudioPlayer.stream_paused = true
		self.is_playing = false
		self.play_state = STATE.PAUSED
