# Technical Notes

Godot 4.3 · GDScript · GL Compatibility renderer · 1600×900 · 60 physics ticks/s.

## Architecture

```
scenes/main.tscn ── Node + scripts/main.gd (GameManager, "ctx")
  ├─ GameEvents          signal hub (scripts/core/events.gd)
  ├─ Room                level geometry, props, fixtures   (scripts/world/)
  ├─ PlayerController    CharacterBody3D                   (scripts/player/)
  ├─ PhysicsRuleManager  the five rules                    (scripts/systems/physics_rules.gd)
  ├─ DeviationManager, ChainTracker, MutationManager, AnomalyManager,
  │  EnvEffects, MissionManager, ProgressionManager(+SaveManager),
  │  RoomObserver                                          (scripts/systems/)
  ├─ AudioManager        synthesized sounds                (scripts/audio/)
  ├─ Fx                  overlay shader, particles, lines  (scripts/fx/)
  └─ UIManager           HUD / rules menu / screens        (scripts/ui/)
```

- **No autoloads.** `main.gd` builds every subsystem in code, then calls `setup(ctx)` on each with
  itself as the context. Systems talk through `GameEvents` signals or through `ctx.<system>`.
  This keeps every system testable: the test runner instantiates `main.tscn` with
  `set_meta("test_mode", true)` and a separate save path.
- **Input map** is created in code (`main.gd`), so the project file stays minimal.
- **UI** is built entirely in code with `UiKit` helpers (theme, panels, buttons, labels).
  Chinese text uses a `SystemFont` with Microsoft JhengHei first, then fallbacks.
- **Data** lives in `scripts/data/`: anomaly cards, missions, mutations are plain dictionaries /
  small definition objects, so content can be added without touching systems.

## State machine (main.gd)

`MENU → CARDS → PLAYING → SHIFT_END → (CARDS … ×3) → RESULTS → MENU`

The scene tree is paused **only** by the Esc pause menu. Card pick and result screens keep the
tree running and gate gameplay with `ctx.is_playing()`. Pausing the tree at those moments caused
Godot "SelfList" error spam from physics bodies being freed while paused.

## Time

- `Engine.time_scale` implements the TIME rule (slow 0.35 / normal 1 / fast 1.75 / "unstable" oscillating 0.25–1.8).
- Mission timers, mutation durations and budgets use **real time**: `delta / Engine.time_scale`.
- `GameClock.ms` is a static millisecond counter advanced by Main only while the tree is not
  paused. All cooldowns use it instead of `Time.get_ticks_msec()` so pausing never expires them.
- The player gets partial compensation for time scale so slow-motion is not unplayable.

## The five rules

| Rule | Implementation |
|---|---|
| Gravity | `PhysicsServer3D.area_set_param` on the default space (direction + magnitude). Player has "grip boots" and uses its own gravity. |
| Bounce | Per-prop `PhysicsMaterial.bounce` scaled by level; re-applied to new spawns via `apply_to_prop`. |
| Magnetism | Custom pairwise force in `_physics_process` every 2nd tick (see below). |
| Friction | Per-prop material friction and per-floor-tile metadata; PATCHWORK assigns random friction per tile. Player acceleration reads the tile under it. |
| Time | `Engine.time_scale`. |

### Magnetism model

Pairs within 6.5 m are considered (O(n²) with n ≈ 70–90, every other tick). Per pair the
force is `k / (d² + 0.8)`, weighted by the partner's mass (clamped 0.3–2). Forces are **summed per
prop and then capped** (Δv ≤ 0.9 per tick). Magnetism will not accelerate a prop that already moves
faster than 3.5 m/s along the push, will not keep pulling pairs that are already closing at
> 2 m/s, and damps props within 0.95 m of a partner so they settle into a clump instead of
bouncing apart and back (this was the main source of runaway breakage with high bounce).

## Deviation (anti-farming)

- Impacts, chain links and breaks each draw from their own refilling budget
  (5 / 6 / 6, refilling 1.2 / 0.75 / 0.4 per real second).
- The same striker–victim pair scores at most once per 2 s; every prop accumulates "boredom"
  that divides later gains.
- Rule changes add 5 (1.5 when returning to normal), reduced by fatigue when spamming.
- **Soft cap:** room-driven gains (impacts, chains, breaks) are multiplied by a factor that
  falls from 1 to 0 over the 12 points above `soft_cap() = 32 + 7 × bent_rules + 14 (if the
  player threw / pulsed / changed a rule / pressed a device in the last 4 s)`. Rule changes and
  mutations are not capped. Leaving one rule on and walking away settles around DISTORTED;
  reaching CATASTROPHIC needs several bent rules and continuous action.
- With no gain for 3 s, the value decays toward a floor set by bent rules, active anomalies and
  mutations.

## Chain tracker

- `start_chain(origin, props)` tags props with a chain id and depth.
- **Environmental** causes (rule change, mutation) use `env = true`: instead of tagging every
  prop, a 2.5 s window lets any untagged prop that hits something become a root of that chain.
- A prop that carries an active chain and hits another prop passes the chain on (depth + 1).
  Each victim joins a chain at most once; each pair counts once; a chain is capped at 30 links
  and closes after 3.5 s with no new link. Devices (`on_device`) and springs add steps too.
- Only the striker reports prop–prop impacts, with a 120 ms per-body cooldown.

## Missions

`MissionManager` picks a mission type from `mission_data.gd` weighted by stage difficulty,
picks a target and zone, then **validates** it (reachable zone, target light enough for
NO_TOUCH, no BALANCE under wind, etc.). After failed attempts it falls back to a mission that
is always solvable. Markers are `Label3D` with `fixed_size`.

## Save system (save_manager.gd)

- JSON in `user://misrule_save.json`.
- Write to `*.tmp`, then rename over the real file; the previous file is kept as `*.bak`.
- On parse failure the broken file is moved to `*.corrupt`, then `.bak` is tried, then defaults.
- `_merge` adds keys introduced by newer versions to old saves.

## Audio

All sounds are generated at startup into `AudioStreamWAV` (noise bursts, sine/square sweeps,
FM clicks, a looping hum and drone). There are pooled 3D players for impacts and UI players for
interface sounds; `play_rule(rule)` gives each rule its own cue.

## Expansion systems (0.2.0)

- **ComboManager** (`scripts/systems/combo_manager.gd`, data in `scripts/data/combo_data.gd`): each combo lists
  the rule levels it needs. A combo counts as active once it has held for 2.5 s; effects run in
  `_physics_process` every 2nd tick on `_movable()` props (not held, ≤60 kg, not paper, not frozen).
  Discovery is stored as codex `rcombo:<ID>`. The `combo:` prefix is already used by anomaly-card combos.
  First activation in a shift adds 4 Deviation (outside the soft cap) and opens an environmental chain.
- **ClauseManager**: clauses are `forbid` (start kept, can break) or `require` (start unmet).
  `ClauseManager.fits()` filters by `excl_types` and `needs_target`. Clauses never gate mission
  completion; `finalize()` feeds `ScoringManager` (+7 creativity per kept or met clause, +10 for the hidden one,
  −6 efficiency per broken clause). A forbid clause only counts as kept if the primary mission was done.
- **IncidentManager**: deterministic triggers (idle time, device activations in 12 s, printer uses,
  time spent at tier ≥ 3, Deviation ≥ 82). Rules: at most 2 per shift (the inspection is exempt),
  30 s apart, none in the first 15 s, each at most once per shift. `enabled` lets tests turn
  automatic triggers off. Spawned props carry the `no_respawn` meta so the room does not respawn them.
- **IncidentReport**: built by a static function from `main.run_stats` (a full copy of each shift's stats).
  Comment and case pools are filtered by flags. The comment indices used last time are saved in
  `last_comments` so the next report avoids them. `last_incident` feeds the TV replay.
- **Save keys added:** `incident_counter`, `last_incident`, `last_comments`. Old saves get them
  through `SaveManager._merge` (defaults first, loaded values on top).
- **Fonts:** `UiKit.font()` is a shared SystemFont. Label3D does not use the UI theme, so every
  Label3D sets `font` explicitly.

## Testing

```
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
```

`tests/run_tests.gd` (160 checks) runs against the real main scene. Headless output includes
harmless `mesh_get_surface_count` errors and an "ObjectDB leaked" warning from the dummy renderer.

`tools/balance_probe.gd -- <CARD_ID> [verbose] [casual] [magnet] [idle]` simulates 90 s of play
and prints deviation, breaks, chains and broken prop kinds. `tools/screenshot.gd -- <dir>` needs a
real renderer (`xvfb-run … --rendering-driver opengl3`).

## Performance notes

- Debris and paper have hard caps; broken props respawn through a queue (20 s).
- Fans and magnetism run every second physics tick.
- Headless in the dev container: ~10–12 ms per physics frame under heavy chaos. Not yet measured
  on Windows with a GPU.
