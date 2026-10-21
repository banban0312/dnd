extends Node
## Original looping music, independent of world pause and sound-effect players.
const EXPLORATION_PATH := "res://assets/audio/exploration_medieval.wav"
const BOSS_PATH := "res://assets/audio/boss_electronic.wav"
var game: Node
var muted := false
var mode := "silent"
var exploration_player: AudioStreamPlayer
var boss_player: AudioStreamPlayer
var exploration_gain := 0.0
var boss_gain := 0.0
var duck_gain := 1.0

func setup(owner_game: Node) -> void:
	game = owner_game

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	exploration_player = _make_player(EXPLORATION_PATH, "ExplorationMusic")
	boss_player = _make_player(BOSS_PATH, "BossMusic")

func _make_player(path: String, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	var track := load(path).duplicate() as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = track.data.size() / (4 if track.stereo else 2)
	player.stream = track
	player.volume_db = -80
	add_child(player)
	return player

func set_muted(value: bool) -> void:
	muted = value
	_apply_volumes()

func _process(delta: float) -> void:
	if exploration_player == null or boss_player == null:
		return
	var desired := "silent"
	var ducked := false
	if is_instance_valid(game):
		var state: String = game.run_state
		ducked = state in ["pause", "inventory", "reward", "gate"]
		if state not in ["title", "result", "loading"]:
			if ducked and mode != "silent":
				desired = mode
			else:
				var fighting: bool = is_instance_valid(game.boss) and not game.boss.dead and game.boss.arena_active
				desired = "boss" if fighting else "exploration"
	if desired != mode:
		mode = desired
		if mode == "boss" and boss_gain <= 0.001:
			boss_player.play(0.0)
		elif mode == "exploration" and exploration_gain <= 0.001:
			exploration_player.play(0.0)
	# Linear amplitude ramps complete a full crossfade in one second.
	exploration_gain = move_toward(exploration_gain, 1.0 if mode == "exploration" else 0.0, delta)
	boss_gain = move_toward(boss_gain, 1.0 if mode == "boss" else 0.0, delta)
	duck_gain = move_toward(duck_gain, 0.4 if ducked else 1.0, delta * 2)
	_apply_volumes()
	if exploration_gain == 0 and mode != "exploration" and exploration_player.playing:
		exploration_player.stop()
	if boss_gain == 0 and mode != "boss" and boss_player.playing:
		boss_player.stop()

func _apply_volumes() -> void:
	if exploration_player == null or boss_player == null:
		return
	exploration_player.volume_db = -80.0 if muted or exploration_gain <= 0 else -18.0 + linear_to_db(exploration_gain * duck_gain)
	boss_player.volume_db = -80.0 if muted or boss_gain <= 0 else -14.0 + linear_to_db(boss_gain * duck_gain)
