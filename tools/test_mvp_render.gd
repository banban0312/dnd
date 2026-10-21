extends SceneTree
## Native rendering sample; not a human playtest or a long-term benchmark.
var game: Node
var report: Array[Dictionary] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    game = load("res://mvp.tscn").instantiate()
    root.add_child(game)
    game.start_run()
    game.player.invuln_timer = 1000
    await _sample("floor1_entry")
    game.gate_open = true
    game.ui.show_gate()
    game.descend()
    game.player.invuln_timer = 1000
    game.player.position = game.world.boss_position + Vector2(-160, 90)
    await _sample("floor2_boss")
    var output := FileAccess.open("res://_test/render-profile.json", FileAccess.WRITE)
    output.store_string(JSON.stringify({"resolution": root.size, "samples": report, "scope": "local native scripted sample; not human timing or cold machine verification"}, "  "))
    output.close()
    print("Native render profile: ", JSON.stringify(report))
    for node in root.get_node("Sfx").get_children():
        if node is AudioStreamPlayer:
            node.stop()
            node.queue_free()
    await process_frame
    await create_timer(0.25).timeout
    quit()

func _sample(label: String) -> void:
    for i in 60:
        await process_frame
    var samples: Array[float] = []
    var previous := Time.get_ticks_usec()
    for i in 180:
        await process_frame
        var current := Time.get_ticks_usec()
        samples.append(float(current - previous) / 1000.0)
        previous = current
    var sum := 0.0
    for value in samples:
        sum += value
    samples.sort()
    report.append({"scene": label, "frames": samples.size(), "fps_mean": 1000.0 / (sum / samples.size()), "p95_ms": samples[int(samples.size() * 0.95)], "max_ms": samples.back()})
