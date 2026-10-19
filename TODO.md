# HAUNTED KINGDOM — BUILD TODO

Legend: `[x]` done & verified · `[~]` written, not yet verified · `[ ]` not started
Verified = loaded by Godot 4.7.2 (`--import` / headless scene run) with zero errors.

---

## STAGE 1 — Player + Abandoned Village  ✅ COMPLETE
- [x] `project.godot` (layers, gravity, autoloads, Forward+)
- [x] `autoload/game_manager.gd` — input map, pause, level loading, fade, overlay, settings
- [x] `autoload/proc_audio.gd` — all SOUND EFFECTS synthesised at runtime (no audio assets)
- [x] `autoload/music.gd` + `audio/music/baanali_jaarida.ogg` — looping background music
      ("Baanali Jaarida", Premada Oorali). Autoload, so it fades in at the main menu and
      runs unbroken through level changes. Balance with `MUSIC_DB`.
- [x] Background ambience bed REMOVED on request. It was a synthesised brown-noise
      wind + 46/69 Hz drone ("a cloudy hum") sitting under the music. The song is
      now the ONLY continuous sound; footsteps, strikes, doors and ghost whispers
      are untouched.
- [x] Volume mix lives in the `DB_*` constants at the top of `proc_audio.gd`.
      Combat sounds turned down on request: swing -1 → -8, impact +1.5 → -7,
      ghost whisper 0 → -12, hurt +2 → -6 dB. Rebalance the whole game there.
- [x] `player/player.gd` + `player.tscn` — walk/run/crouch/jump, look, health, interact, death
- [x] Player is armed and lethal: melee sweep, windup, cooldown, wall guard, 6 weapon slots
- [x] `player/flashlight.gd` — the torch: a SpotLight3D on the camera, so the beam
      always points where you look. `F` toggles it, it flickers and stutters, and
      it casts real shadows. Also raised both levels' ambient + moonlight floor and
      added a short-range `TorchFill` light, so the game reads as DARK, not BLACK.
- [x] `props/block.gd|tscn` — @tool box, size drives mesh + collision
- [x] `props/interactable.gd` — base class (+ float/spin + hide_and_disable)
- [x] `props/door.gd|tscn` — hinged door, lockable, unlocks from a key
- [x] `props/note.gd|tscn`, `props/health_kit.gd|tscn`
- [x] `props/flicker_light.gd`, `damage_zone.gd`, `trigger_zone.gd`
- [x] `ui/hud.tscn|gd` — health, crosshair, pause, death screen, right-hand map + TODO box
- [x] `ui/main_menu.tscn|gd` — Play / Settings / Quit
- [x] `levels/stage1_village.tscn|gd` — chapel, cursed well, platform, candles, 3 roaming ghosts
- [x] Verified: import clean, headless run of stage1 with zero errors

## CHARACTER RIGS — the four reference ghosts  ✅ COMPLETE
- [x] `enemies/ghost_rig.gd` — procedural joint rig, 4 body types, 4 poses, glow lights, fade-out
- [x] `enemies/ghost_rig.tscn`
- [x] `enemies/enemy_ghost.gd` — AI state machine, senses, combat, banish, health bar, knockback, stun
- [x] `enemies/enemy_ghost.tscn`
- [x] `enemies/ghost_db.gd` — THE DIFFICULTY LADDER (see below)
- [x] Verified: import clean, 150 headless frames of enemy_ghost.tscn, zero errors

### Difficulty ladder (easiest → hardest)
| # | Character | GhostDB id | Health | Damage | Chase | Resist | Teleport |
|---|-----------|-----------|--------|--------|-------|--------|----------|
| 1 | Girl soldier | `SOLDIER_FEMALE` | 60 | 6 | 2.9 | 0% | no |
| 2 | Boy soldier | `SOLDIER_MALE` | 95 | 10 | 3.2 | 5% | no |
| 3 | Girl queen | `GHOST_QUEEN` | 110 | 18 | 3.7 | 15% | no |
| 4 | Boy king | `GHOST_KING` | 150 | 13 | 3.8 | 0% | no |

## WEAPONS + COMBAT  ✅ COMPLETE
- [x] `weapons/weapon_db.gd` — 6 weapons as data (damage/range/arc/cooldown/windup/stun/knockback)
- [x] `weapons/weapon_view.gd` — procedural first-person viewmodel + swing animation + static mesh factory
- [x] `player/player.gd` — melee sweep, cooldown, windup, through-wall guard, weapon switching
- [x] `ProcAudio.play_swing()` + `play_impact()` — synthesised whoosh and crunch
- [x] `props/key_item.gd|tscn` — collectible key with procedural shape
- [x] `props/weapon_pickup.gd|tscn` — bat / pan / katana / lantern / trap on the floor
- [x] `autoload/game_manager.gd` — key + weapon inventory, kill counting, score, map data, slot keys 1-6
- [x] `ui/minimap.gd` — top-down map: floors, walls, player arrow, ghosts with difficulty rings, pickups
- [x] `tests/combat_arena.tscn` + `tests/combat_test.gd` — headless combat proof, 0 failures
- [x] **Verified: the player kills ghosts.** End-to-end through the real attack
      input: girl soldier dies in **3 wooden-bat swings**, first connect on swing 1
- [x] Verified: a wall between you and the ghost stops the blade (no hitting through walls)
- [x] Verified: identical katana hits needed — girl 2 · boy 3 · queen 3 · king 4
- [x] Verified: every ghost can kill you — girl 17 hits · boy 10 · queen 6 · king 8
- [x] The bosses were tuned down three times after play-testing. Queen 220 → 110 hp,
      King 400 → 150 hp (12 → 4 katana hits), resist 25% → 0%, damage 26 → 13,
      teleport removed entirely. Short fights, still the hardest ghost.

## MAP + HUD  ✅ COMPLETE
- [x] `ui/hud.tscn` + `ui/hud.gd` — right-hand panel: minimap, hunt status, **TODO/task list**, weapon list
- [x] Right-hand TODO box ticks each ghost off as you banish it, easiest-first
- [x] Minimap picks up `GameManager.set_map()` from the level automatically
- [x] **THE MAP: `levels/stage2_barracks.tscn|gd`** — walled compound: entry yard,
      corridor, dormitory, locked armoury, mess hall, cellar, parade ground,
      chapel, generator room. 6 roaming ghosts, 4 notes, 4 kits, 5 weapons.
- [x] `levels/stage1_village.gd` is now a `HauntedLevel` hunt: 2 girl soldiers + 1 boy soldier, bat + pan
- [x] `ui/main_menu.gd` — calls `GameManager.reset_run_state()` on Play
- [x] `levels/level_base.gd` — `HauntedLevel` builders (`add_wall`, `add_wall_with_gap`,
      `spawn_ghost`, `spawn_weapon`, `spawn_key`, `spawn_light`...) so a level is a
      readable list of instructions
- [x] `tests/level_check.tscn` + `tests/level_check.gd` — headless map validator
      (flood-fills the real geometry). 0 failures on the barracks.
- [x] Verified: every ghost, weapon, key and kit is reachable on foot
- [x] Verified: the katana is the ONLY thing behind the locked door, so the
      armoury key is genuinely required — and no key or ghost is ever sealed away

## STAGE 3 — Ghost AI proper
- [x] Direct steering + move_and_slide (works now, ghosts slide along walls)
- [ ] NavigationRegion3D baked navmesh + NavigationAgent3D pathing
- [ ] Per-ghost unique AI personalities (Queen illusions, King summons)
- [ ] Ghost hears your footsteps while sprinting

## STAGE 4 — Melee combat polish
- [x] Weapon data, viewmodel, swing, hit detection, stagger, knockback, impact FX
- [ ] Hit sparks / blood particles / floating damage numbers
- [ ] Block + parry with the frying pan

## STAGE 5 — Supernatural equipment
- [x] Ghost Lantern + Spirit Trap exist in WeaponDB and can be picked up
- [ ] Lantern reveals invisible ghosts; trap actually roots a ghost to the spot
- [ ] Inventory UI screen (currently a HUD list)

## STAGE 6 — Boss encounters
- [ ] Ghost Queen boss fight (illusions, teleports, secret room)
- [ ] Boss health bar across the screen with phases
- [ ] Ghost King arena + summon minions

## STAGE 7 — Levels, keys, puzzles
- [x] Barracks map with a locked armoury + key (Stage 2)
- [ ] Palace level (red lighting, haunted paintings, illusions)
- [ ] Underground dungeon
- [ ] Key/lock chain across all five levels

## STAGE 8 — Ghost King final boss
- [ ] Throne room level, cinematic intro, multi-phase fight, victory screen

## STAGE 9 — Horror polish
- [ ] Jumpscares, random ghost appearances, particles, fog volume, blood decals
- [ ] Real audio files alongside the procedural ones
- [ ] Imported Mixamo/Quaternius GLB characters replacing the procedural rigs

## STAGE 10 — Menus, saving, victory
- [x] Main menu, pause menu, death screen
- [ ] Save/load, victory screen, level select

## STAGE 11 — Test, optimise, ship
- [x] `tests/combat_arena.tscn` + `tests/combat_test.gd` — proves the player kills ghosts
      through the real attack input, that walls block the blade, and that the
      difficulty ladder holds. **0 failures.**
- [x] `tests/level_check.tscn` + `tests/level_check.gd` — proves a level is
      playable: simulates a 1.8 m player who can step/jump 1.9 m, then
      flood-fills the real geometry. Catches sealed rooms, unreachable
      pickups, and locked doors that can be walked around. **0 failures on
      Stage 1 and Stage 2.** Run with `-- res://levels/<name>.tscn` (add
      `--dump` for ASCII maps, AABBs and per-cell heights).
- [ ] MultiMesh / mesh merging for the ghost rigs (~40-80 meshes each)
- [ ] Occlusion culling, LOD, shadow budget
- [ ] Export presets (Windows + Android touch controls)

## WEB / VERCEL BUILD  ✅ BUILT & VERIFIED
- [x] `export_presets.cfg` — Web preset. Excludes `audio/music/melancholia.*`,
      the old song, which cut the download from 51 MB to 42.6 MB.
- [x] `project.godot` — `rendering_method.web="gl_compatibility"`. A browser only
      has WebGL2, which cannot run Forward+. This override changes ONLY the web
      build; `play.bat` still runs Forward+ with full lighting.
- [x] `export_web.bat` — one double-click to rebuild `build/web`
- [x] `deploy/vercel.json` — COOP/COEP headers + correct `.wasm` MIME type
- [x] `PUBLISH_VERCEL.md` — the full walkthrough
- [x] Verified in real headless Chrome, not just "it exported": Godot 4.7.2
      boots, reports "OpenGL ES 3.0 (WebGL 2.0) - Compatibility", the main menu
      draws, Stage 1 loads, and the HUD / minimap / ghosts / torch all render.
      **0 console errors, 3 info lines.**
- [x] Build size 42.6 MB = index.wasm 37.7 + index.pck 4.6 + index.js 0.27
- [ ] Publish — needs `vercel login` on your account, which only you can do

## HOW TO PLAY IT RIGHT NOW
Run `play.bat` (or open the project in Godot and press F5).
- **W A S D** move · **SHIFT** sprint · **CTRL** crouch · **SPACE** jump
- **MOUSE** look · **LEFT CLICK** swing your weapon
- **E** interact (pick up weapons, keys, bandages, read notes, open doors)
- **1-6** or **MOUSE WHEEL** switch weapon · **ESC** pause
- The right-hand HUD panel shows the MAP and the **TODO list** - each ghost
  is a task, ticked off the moment you banish it.
- Stage 2's katana is locked in the armoury: find the **Rusted Armoury Key**
  in the dormitory first. The minimap marks ghosts by difficulty colour:
  green (girl soldier, easiest) → blue → pink → gold (king, hardest).

