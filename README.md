# HAUNTED KINGDOM: GHOST HUNTER

A 3D first-person horror game built with **Godot 4.7** and **GDScript**.

**Current state: STAGE 1 COMPLETE** — a fully playable first-person character in an
abandoned village level, with health, damage, death, pause, menus and sound.

---

## 1. WHAT IS INSTALLED

| Thing | Version | Where |
|---|---|---|
| Godot Engine | 4.7.2 stable | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\` |
| Python (preview server only) | 3.15 | already on the machine |

To open the editor: run **`play.bat`** to play, or open the Godot *Project Manager*
and click **Import** → point it at this folder.

---

## 2. HOW TO RUN

| What you want | What to do |
|---|---|
| **Play the game** | double-click **`play.bat`** |
| **Open the editor** | Godot Project Manager → Import → this folder → *Edit* |
| **Character Studio (browser)** | double-click **`serve.bat`**, then open <http://localhost:1200/> |

---

## 3. FOLDER STRUCTURE

```
HauntedKingdom/
├── project.godot            project settings, physics layers, gravity
├── icon.svg                 project icon
├── play.bat                 launches the game
├── serve.bat                starts the port 1200 preview server
├── index.html               browser landing page
│
├── autoload/                GLOBAL SINGLETONS (always loaded)
│   ├── game_manager.gd      input map, pause, level loading, fade, messages,
│   │                        on-screen overlay, saved settings
│   └── proc_audio.gd        synthesises ALL sound effects at runtime
│
├── player/
│   ├── player.tscn          the first-person character
│   └── player.gd            movement, look, crouch, jump, health, interaction
│
├── props/                   reusable level objects
│   ├── block.gd / .tscn     @tool box: `size` updates mesh + collision
│   ├── interactable.gd      base class for anything you press E on
│   ├── door.gd / .tscn      swinging door, can be locked
│   ├── note.gd / .tscn      readable page that advances the objective
│   ├── health_kit.gd/ .tscn press E to heal
│   ├── flicker_light.gd     candle that flickers and blacks out
│   ├── damage_zone.gd       Area3D that hurts the player over time
│   └── trigger_zone.gd      Area3D that shows a message once
│
├── ui/
│   ├── hud.tscn / hud.gd    health bar, crosshair, pause menu, death screen
│   └── main_menu.tscn/.gd   Play / Settings / Quit
│
├── levels/
│   ├── stage1_village.tscn  LEVEL 1 — abandoned village
│   └── stage1_village.gd    objectives + spawn point
│
└── preview/
    └── index.html           3D Character Studio (the four ghosts)
```

---

## 4. WHERE EVERY SCRIPT IS ATTACHED

| Script | Attached to | Scene |
|---|---|---|
| `autoload/game_manager.gd` | autoload `GameManager` | `project.godot` |
| `autoload/proc_audio.gd` | autoload `ProcAudio` | `project.godot` |
| `player/player.gd` | node `Player` (CharacterBody3D) | `player/player.tscn` |
| `props/block.gd` | node `Block` (StaticBody3D) | `props/block.tscn` |
| `props/door.gd` | node `Door` (StaticBody3D) | `props/door.tscn` |
| `props/note.gd` | node `Note` (StaticBody3D) | `props/note.tscn` |
| `props/health_kit.gd` | node `HealthKit` (StaticBody3D) | `props/health_kit.tscn` |
| `props/flicker_light.gd` | every `Candle1…Candle5` OmniLight3D | `levels/stage1_village.tscn` |
| `props/damage_zone.gd` | node `CursedMist` (Area3D) | `levels/stage1_village.tscn` |
| `props/trigger_zone.gd` | `GateTrigger`, `ChapelTrigger`, `WellTrigger` | `levels/stage1_village.tscn` |
| `ui/hud.gd` | node `HUD` (CanvasLayer) | `ui/hud.tscn` |
| `ui/main_menu.gd` | node `MainMenu` (Control) | `ui/main_menu.tscn` |
| `levels/stage1_village.gd` | root `Stage1Village` | `levels/stage1_village.tscn` |

---

## 5. CONTROLS

| Key | Action |
|---|---|
| `W A S D` | walk |
| `Shift` | run |
| `Ctrl` | crouch |
| `Space` | jump |
| Mouse | look |
| `E` | interact (doors, notes, health kits) |
| `Esc` | pause menu |
| `F3` | debug overlay (FPS, position, speed) |

**Shortcuts that exist now for later stages:** `F` lantern, `Q` heal,
`Left Mouse` attack, `Right Mouse` aim. They are mapped but nothing uses them yet.

### Changing the controls
All controls are registered in `autoload/game_manager.gd` → `_register_default_input()`.
Change the key there, **or** add the action in *Project Settings → Input Map* — the game
only creates an action if it does not already exist, so your own mapping wins.

---

## 6. PHYSICS LAYERS

| Layer | Name | Used by |
|---|---|---|
| 1 | `world` | ground, walls, houses, crates |
| 2 | `player` | the player body |
| 3 | `enemy` | reserved for the ghosts (Stage 3) |
| 4 | `interactable` | doors, notes, health kits |
| 5 | `pickup` | reserved for weapons |

* Player: layer `2`, mask `5` (world + enemy)
* Level blocks: layer `1`
* Doors / notes / kits: layer `9` (world + interactable)
* Interact ray: mask `9`
* Trigger / damage Area3D: layer `0`, mask `2` (watches the player)

---

## 7. IMPORTING REAL 3D MODELS (GLB / FBX)

Stage 1 uses only Godot primitives, so **nothing needs importing**. When you are
ready for real characters:

1. Get a **rigged humanoid** `.glb` or `.fbx`. Best free sources:
   * **Mixamo** (mixamo.com) — free rigged characters + hundreds of animations, Adobe licence, free for commercial use.
   * **Quaternius** (quaternius.com) — CC0 low-poly characters and monsters.
   * **Sketchfab** — filter by *CC0* or *CC-BY*.
   * **KayKit / Kenney** — CC0 asset packs.
2. Inside Godot, just **drag the `.glb` file into the FileSystem panel** into `assets/models/`.
   Godot imports it automatically — no extra step.
3. Click the arrow on the imported file to expand it. You get:
   * a mesh node,
   * a `Skeleton3D`,
   * an `AnimationPlayer` (all animations already inside).
4. Right-click the imported scene → **New Inherited Scene**, or simply drag the
   `.glb` into your level, then attach the ghost AI script to it.
5. Animations are played with:
   ```gdscript
   $AnimationPlayer.play("Walk")
   ```
   Mixamo names them things like `mixamo.com|Walk` — check the exact name in the
   AnimationPlayer and type it exactly.

**FBX note:** Godot 4 needs the *FBX2glTF* converter; Godot asks to download it the
first time you import an `.fbx`. `.glb`/`.gltf` avoids that entirely — prefer `.glb`.

---

## 8. THE FOUR GHOSTS — how they are built

The four ghosts from the reference sheets are implemented as **real 3D rigged
characters**, generated procedurally (geometry + materials + a joint hierarchy),
not as flat billboard images.

* **In the browser right now:** <http://localhost:1200/preview/>
  Drag to orbit, `1`–`4` to pick a ghost, `Space` to cycle
  **Idle → Walking → Attack → Summon** (the same four poses drawn on your
  reference sheets). `F` toggles fog, `L` toggles the lantern.
* **In Godot:** the same rigs are rebuilt as `Node3D` hierarchies with a
  `Skeleton3D`-style bone layout (`hips → torso → chest → neck → head`, plus
  shoulder/elbow and hip/knee pivots) so a single script can drive both the
  animation and the AI.

Why procedural: no modelling software exists in this environment, and a PNG is not a
mesh. The rigs give you correct silhouettes, proportions, palettes and animations
**today**, and each ghost's body is a separate function (`makeGhostKing()`,
`makeGhostQueen()`, …) so swapping in a downloaded Mixamo/Quaternius `.glb` later is
a one-line change — the AI, health, damage and animation code stay untouched.

---

## 9. TROUBLESHOOTING

| Symptom | Fix |
|---|---|
| `Vulkan` error / game won't start | Project Settings → Rendering → Renderer → **Compatibility**. Restart. |
| The screen is completely black | That is intended — it is a horror game. Press `F3`, walk towards the candle glow near the crates. |
| Nothing happens when I press `E` | You must be within **2.6 m** and looking at the object (watch for the yellow prompt under the crosshair). |
| No sound | Windows volume mixer → check Godot is not muted. `Esc` → Main Menu → Settings → Master volume. |
| Mouse doesn't look around | Click once inside the game window to capture the mouse. `Esc` releases it. |
| Mouse too fast / too slow | Main Menu → Settings → **Mouse sensitivity**. |
| Player falls through the world | The `Ground` node must stay at `y = -0.5` with size `90 × 1 × 90`. |
| `Invalid project path` when launching | Quote the path: `--path "C:\Users\chiranth n swamy\HauntedKingdom"` |
| Preview page is blank | It needs internet once for the Three.js CDN. Check the console (`F12`). |
| Port 1200 already in use | Change `1200` to another number in `serve.bat`. |
| Script errors after editing | Open the **Output** panel at the bottom of the editor; the first error line is the real one. |

**Debug checklist before reporting a bug:**
1. `F3` in game — is the player on the floor? speed > 0 when walking?
2. Godot editor → *Debugger → Errors* — any red lines?
3. `godot --headless --path <project> --import` — catches broken scene/property names.
4. `godot --headless --path <project> res://levels/stage1_village.tscn --quit-after 300` — catches runtime errors without opening a window.

---

## 10. STAGE ROADMAP

- [x] **Stage 1** — Godot setup, playable first-person player, abandoned village, health/damage/death, menus, procedural audio
- [ ] **Stage 2** — the haunted military barracks environment
- [ ] **Stage 3** — ghost AI: patrol → detect → chase → attack (state machine + NavigationRegion3D)
- [ ] **Stage 4** — bat + frying pan combat
- [ ] **Stage 5** — katana, Ghost Lantern, Spirit Trap, inventory
- [ ] **Stage 6** — Ghost Queen + both soldier ghosts
- [ ] **Stage 7** — connected levels, keys, puzzles
- [ ] **Stage 8** — Ghost King, multi-phase boss fight
- [ ] **Stage 9** — jumpscares, particles, real audio files, animations
- [ ] **Stage 10** — save/load, victory screen, polish
- [ ] **Stage 11** — testing, optimisation, playable build

---

## 11. PERFORMANCE NOTES (for later)

* Keep `DirectionalLight3D` shadows at **max 1**; enable `shadow_enabled` on only 2–3 OmniLights.
* Draw distance: `directional_shadow_max_distance = 60` is already set.
* Use `LevelBlock` (boxes) for blocking geometry, and only use real meshes for close-up detail.
* The procedural sounds are generated once at startup — if startup feels slow, drop
  `RATE` in `proc_audio.gd` from `22050` to `16000`.
