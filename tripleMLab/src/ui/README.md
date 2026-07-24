# UI Architecture

How the UI layer fits together, and the rules that keep it simple as the game grows.

## The big picture

```
MainGame (GamePhase state machine: MENU / MAP / LEVEL / RUN_END)
├── World            (PAUSABLE)    gameplay + the Map
├── UILayer  z10     (PAUSABLE)    one screen at a time: StartMenu | MapHud | LevelHud | RunEndScreen
├── PauseLayer z20   (WHEN_PAUSED) PauseMenu (+ Settings as submenu) — animates while the tree is paused
├── TransitionLayer z100 (ALWAYS)  ScreenTransition fade — covers everything, swallows input mid-fade
└── DebugLayer z128  (ALWAYS)     debug overlay
```

**One rule above all: UI screens emit intent signals; `MainGame` is the only
place that changes state.** Screens never call `get_tree().paused`, never load
levels, never touch each other. This is what keeps every flow (pause, abandon,
death, retry) testable and race-free.

## Key pieces

- **`src/ui/core/ui_screen.gd` (`UIScreen`)** — base class for every menu.
  Gives each screen a fade-in, an awaitable `dismiss()`, `initial_focus` (so
  keyboard/controller can always navigate), and uniform back handling:
  `ui_cancel` emits `back_requested` and is consumed by the topmost screen.
  Submenus use `open_submenu(scene)`: the parent hides, the child takes over,
  `back` restores the parent with focus. That's the whole "menu stack".

- **`src/ui/theme/game_theme.tres`** — project default theme
  (`gui/theme/custom`). All colors, fonts and styleboxes live here; scenes
  stay unstyled and use `theme_type_variation` (`TitleLabel`, `HeaderLabel`,
  `DimLabel`, `DangerButton`, `HudPanel`) for anything non-default. Never
  hand-color a Control in a scene.

- **`src/ui/transition/ScreenTransition`** — permanent overlay on the
  TransitionLayer. `MainGame` does `await transition.fade_out()` → swap scenes
  → `await transition.fade_in()`. The `_busy` flag in MainGame guards every
  flow-changing entry point against re-entry (double-clicks, pausing
  mid-fade).

- **Pause** — `MainGame.toggle_pause()` on the `pause` action, valid only in
  MAP/LEVEL phases. Pausing sets `get_tree().paused` and loads PauseMenu onto
  the PauseLayer (WHEN_PAUSED, so it still animates). ESC follows
  "close the topmost layer": settings → pause menu → resume. Controller Start
  closes the whole pause stack from anywhere. Abandoning asks for
  confirmation, with focus on the safe option.

- **Settings** — `Settings` autoload owns the values (audio volumes per bus,
  fullscreen, screen shake), applies them on set, persists to
  `user://settings.cfg` on menu close. `SettingsMenu` is a dumb view; it is
  opened as a submenu from both StartMenu and PauseMenu. Gameplay code reads
  `Settings.screen_shake` etc., and must never touch AudioServer directly.

- **Run end** — `RunState.time_expired` → defeat; clearing the FINAL map node
  → victory. Both funnel through `MainGame._show_run_end()` into
  `RunEndScreen` (one scene, two moods) with run stats, retry and menu.

## Map screen (Slay-the-Spire view)

`src/gameplay/map/map.gd` owns the camera:

- wheel scrolls, click-drag pans (1:1 under the cursor), arrows/stick scroll,
  all clamped to the map's content bounds
- camera glides toward `_target_y` (exponential smoothing) — wheel and
  focus jumps feel soft, dragging writes the camera directly
- when the map opens or a room is cleared, the camera auto-focuses the
  current row, placed in the lower third so upcoming branches get the space
- nodes: available ones pulse (AnimationPlayer), hover scales them up with a
  pointing-hand cursor, rows you passed dim to 35%, and the path you actually
  walked is drawn in gold (`_update_traveled_lines`)
- clicking selects on *release* within a 6px slop — starting a drag on top of
  a node pans the map instead of committing to the node
- hovering a candidate node also brightens the specific edge you'd walk to
  reach it (`hover_changed` → `_on_node_hover_changed`)

## Testing

`godot --headless res://src/debug/UiSmokeTest.tscn` drives the full loop
(boot → run → pause stack → settings → level → time-out → retry → abandon)
and exits non-zero on failure. Run it after touching game flow. The shop has
its own: `ShopSmokeTest.tscn`.

## Future polish backlog (from UX research)

- **Per-type node silhouettes**: distinct shape AND color per room type — small
  same-shape icons are the #1 readability complaint about the StS map. Blocked
  on real art; `TYPE_COLORS`/`ICONS` in map_node.gd are the hook.
- **Token-moves-to-node beat**: a short animated marker traveling to the picked
  node before the room fade. StS lacks it and gets dinged for it.
- **Menu SFX**: hover-change and confirm (distinct from cancel) cues, routed
  through the SFX bus so they respect settings. Audio is half of perceived juice.
- **Pixel font**: if text ever looks soft, swap SF Mono for a true pixel font
  (or disable antialiasing in the .otf import) and keep sizes on its native grid.

## Adding a new screen

1. Scene root = `Control` with a script extending `UIScreen`; build the layout
   from containers; set `initial_focus` to the primary button.
2. Style only through the theme (add a variation if genuinely new).
3. Emit intent signals; wire them in `MainGame`.
4. Load it via `MainGame.load_scene(..., SceneContainer.UI)` (or PAUSE), never
   `add_child` from another screen — except `open_submenu` for child menus.
5. Extend the smoke test with the new flow.
