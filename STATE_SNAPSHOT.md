# Current task

current_phase: review_build_ready

## Active: MVP art and direction playtest

- Default mvp.tscn; launch start-test.cmd / start-test.ps1. Title includes equipment fitting.
- Implemented two floors, six items, finite encounters, telegraphed boss/enemies, equipment comparisons, extraction/descent/results and restart.
- No legacy save writes; high score is session-only. Original main.tscn remains available.
- Actual captures: docs/review/*.png. Read docs/MVP_PLAYTEST.md for controls and scope.
- Verified flow smoke, real equipment/arrow collision tests, legacy startup, native D3D12 rendering.
- Pending: user art/direction review, human balancing, standalone executable and cold-start verification.
- Prior 3-floor/18-item plans remain candidate future scope, not active implementation promises.

## Active task: short-term development plan

- User requested a feasible development schedule, deeper gameplay and a coherent visual direction; delegation was explicitly authorized.
- Planning only: no gameplay code or art assets changed in this turn.
- Deliverables: PROJECT.md, TASK_QUEUE.md, DECISIONS.md, docs/SHORT_TERM_ROADMAP.md.
- Scope: 10 working days / about 80 hours, 3-floor 12–18 minute slice, 4 relics, 2 enemy types, 1 boss; last 2 days reserved for verification and buffer.
- Next: P1 graybox run loop and floor lifecycle; D3 scope gate reduces to 2 floors if necessary.
- Existing uncommitted rename/startup fixes remain intact; baseline rollback commit remains 4b183e9.

## Previous task: startup fixes

- Base commit / rollback point: `4b183e9577a3aaab6553b9f4e71001fbaff7fc2a`.
- Scope: rename game to `deeper and deeper`, inspect repository and startup.
- Remote: `https://github.com/banban0312/dnd`, remote main matches base commit.
- Reproduced: AI chat opens while the continue menu owns the pause; closing it resumes an uninitialized world.
- Fix: do not open chat while another modal owns the pause; closing unopened chat is a no-op.
- Regression: `tools/test_startup.tscn` checks startup modal isolation, world creation, player/enemy initialization and normal chat pause/resume. `-- --new` checks new-world initialization without deleting existing saves.
- Limitation: clean-cache editor import encountered filesystem safe-save errors in the execution sandbox; existing-cache gameplay is tested separately.


## Art pass 0.2 — Ashen Kingdom (2026-10-21)

- Replaced abstract lift title with an animated procedural gothic portal illustration: ruined castle, dragon silhouette, moon, crimson sword standards, torch embers and a steel-clad wanderer.
- Title typography and Chinese entry copy now introduce the medieval fantasy setting; modal palette uses dark leather, brass and parchment.
- Both floors now share sword heraldry and processional carpets, with a blue variant on floor two. Combat geometry and progression remain unchanged.
- Verified existing MVP smoke flow and actual OpenGL review captures in `_test/mvp_*.png`.
- Sandbox test runtime needs APPDATA redirected to a temporary directory; default roaming folder was unavailable. No launcher or save paths changed.
- This is a procedural art direction pass; existing pixel character sprites remain and need a later matching character art pass.


## Art pass 0.3 — textured medieval pixel art (2026-10-21)

- User explicitly rejected the geometric illustration style in favor of detailed medieval pixel textures.
- Replaced title illustration with generated pixel fantasy artwork at assets/pixel_title.png; original lettering and interactive menu remain separate, with nearest filtering and animated square embers.
- Replaced flat floor/wall/pillar/chest drawings with existing project pixel textures. Added woven carpet/banner detail and textured stone panels/buttons.
- Existing ranger and enemy animation assets and all combat rules remain unchanged.
- Verified full MVP smoke and real OpenGL screenshots; title, game, equipment, gate and boss captures are under _test/.
