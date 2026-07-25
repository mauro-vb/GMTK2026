# The Workshop

The shop room is now a **workshop**: a bench between levels with three modifiers laid out
on it, and the player takes one.

The interesting part isn't the room — it's that the workshop never asks *which* modifiers
the player is carrying. Every number it runs on is a question put to the modifiers
themselves, so a modifier that widens the bench or buys a second pick is **a `.tres` file,
not a change to the workshop**.

This document covers that extension point, the offer pool and its draw, the room's flow,
the UI's design language, and why each makes the choices it does.

---

## 1. The extension point

### 1.1 The pattern it copies

`Modifier` already had two passive hooks that let a modifier answer a question without
being triggered — the mechanism behind "Coating" swallowing hot orbs:

```gdscript
func blocks_orb(_orb_trigger: Type) -> bool
func modify_orb_value(_orb_trigger: Type, value: float) -> float
```

`Orb` doesn't know Coating exists. It asks `ModifiersSystem`, which asks every held
modifier in turn. The workshop hooks are the same shape, added alongside them:

```gdscript
## How many modifiers get laid out on the bench.
func modify_workshop_offers(count: int) -> int:                        return count
## How many of those the player is allowed to walk away with.
func modify_workshop_picks(count: int) -> int:                         return count
## How many times the bench can be swept and re-laid.
func modify_workshop_rerolls(count: int) -> int:                       return count
## Rebalances the draw — the hook behind "offers skew rare".
func modify_workshop_offer_weight(w: float, _t: Rarity.Tier) -> float: return w
## Seconds paid out for walking away without taking anything.
func modify_workshop_skip_bonus(seconds: float) -> float:              return seconds
## Return true to be dropped — how a one-shot perk spends itself.
func on_workshop_visited(_picks_taken: int) -> bool:                   return false
```

Every one is pass-through by default, so **all 27 pre-existing modifiers inherit "changes
nothing about a bench" for free** and none of their `.tres` files were touched.

### 1.2 The aggregation side

`ModifiersSystem` folds each hook across everything held, exactly as it already does for
`modify_orb_value`:

```gdscript
func get_workshop_offers(base: int) -> int:
    var count: int = base
    for modifier: Modifier in modifiers:
        count = modifier.modify_workshop_offers(count)
    return maxi(count, 1)
```

Each getter clamps at the end (`offers ≥ 1`, `picks ≥ 0`, `rerolls ≥ 0`, `weight ≥ 0`,
`skip bonus ≥ 0`), so stacked downgrades can't drive a bench negative.

`notify_workshop_visited(picks_taken)` closes a visit out, dropping any modifier that says
it has spent itself. It iterates a **copy** of `modifiers`, because removing from the list
mutates it mid-loop — the same precaution `_tick_second_durations()` already takes.

### 1.3 `WorkshopModifier`

One new modifier class answers all six hooks. One class rather than six because these are
the same kind of thing — numbers the workshop asks for before it lays out — and because a
single modifier often wants two of them at once (a wider bench that skews cheap).

| export | default | effect |
|---|---|---|
| `extra_offers` | 0 | cards on the bench. Negative narrows it. |
| `extra_picks` | 0 | how many may be taken. **This is the pick-two perk.** |
| `extra_rerolls` | 0 | sweeps of the bench |
| `skip_bonus_seconds` | 0.0 | paid for leaving empty-handed |
| `common_weight_scale` | 1.0 | multiplier on commons' share of the draw |
| `rare_weight_scale` | 1.0 | …on rares' |
| `exotic_weight_scale` | 1.0 | …on exotics' |
| `consume_on_use` | false | spend itself after a visit the player took from |

Nothing here triggers. `trigger_modifier()` is left as the base no-op — these are answered
passively, the same way Coating answers orb hooks.

**`consume_on_use` only fires when `picks_taken > 0`.** Walking away empty-handed doesn't
burn a one-shot perk, because it didn't do anything.

### 1.4 `Rarity`

A dependency-free namespace (`RefCounted`, never instantiated) holding the shared
vocabulary: the `Tier` enum, its display names, its colours, and the base/depth draw
weights.

It exists as its own class because of a **cyclic dependency**. `WorkshopEntry` needs a
`Modifier`; `Modifier`'s weight hook needs a rarity type. If the enum lived on
`WorkshopEntry`, the two scripts would reference each other and GDScript would refuse to
compile either. `Rarity` depends on nothing, so both can depend on it.

> The static accessors are named `display_name()` / `display_color()`, not `get_name()` /
> `get_color()`. A static `get_name` on a class is shadowed by GDScript's own `get_name`
> on the script object — it resolves at parse time and fails at runtime with an
> argument-count error. This cost an hour; don't rename them back.

---

## 2. The offer pool

### 2.1 `WorkshopEntry` — a modifier plus its terms

```gdscript
@export var modifier: Modifier
@export var tier: Rarity.Tier = Rarity.Tier.COMMON
@export var weight: float = 1.0   # relative draw weight *within* the tier
@export var min_depth: int = 0    # map row before which this never appears
```

Terms are kept off the modifier deliberately. "How good is this?" belongs to the modifier;
"how often does it turn up on a bench, and how early" belongs to the run's pacing — and
the same modifier can arrive by other routes (Lucky Find, a linked trade-off) that these
terms have no say over.

`is_available(depth, system)` filters out anything gated deeper than the current row, and
anything the player already holds unless the modifier is `stackable`.

### 2.2 Depth scaling

Draw weight is `entry.weight × Rarity.depth_weight(tier, depth)`, then run past the
player's own modifiers via `get_workshop_offer_weight()`.

| tier | base share | per-row gain | at row 0 | at row 8 |
|---|---|---|---|---|
| COMMON | 1.00 | −0.045 | 1.00 | 0.64 |
| RARE | 0.50 | +0.05 | 0.50 | 0.70 |
| EXOTIC | 0.15 | +0.14 | 0.15 | 0.32 |

Commons thin out slowly while the good stuff climbs, so a late bench reads as a reward for
getting there rather than as the same bench with different names on it. Commons never
vanish (`MIN_WEIGHT = 0.02`) — a bench with nothing plain on it has no floor for the rare
things to stand out against.

### 2.3 The draw

`WorkshopPool.draw(count, depth, modifiers_system)` is weighted and **without
replacement**: the winner is removed from the candidate list and its weight subtracted
from the running total rather than the whole list being re-summed each round.

Running short of candidates lays out a **smaller bench** rather than repeating itself or
failing, and pushes a warning. Asking for zero returns empty rather than erroring.

### 2.4 `default_pool.tres`

28 entries — 12 common, 13 rare, 3 exotic.

Only upgrades and sideways trades are in the pool. **Pure downgrades are not offered**;
they reach the player as `linked_modifier` trade-offs attached to something strong, which
is the convention "Kick Start" already established.

---

## 3. The room

### 3.1 `SHOP` → `WORKSHOP`

`Room.Type.SHOP` is now `Room.Type.WORKSHOP`, in the same enum position — enum values
serialise as ints, so no existing `.tres` was invalidated. `MapGenerator`'s weight constant
and no-consecutive rule renamed with it. The map icon is unchanged (`shop_cart.png`).

### 3.2 Rooms now know what scene they load

`Room.scene_uid` defaulted to `TEST_LEVEL_UID` for **every** room type, and nothing ever
overwrote it — so a workshop node would have loaded the test level. Added:

```gdscript
func apply_type_scene() -> void:
    match type:
        Type.WORKSHOP:
            scene_uid = UIDs.WORKSHOP_SCENE_UID
```

called by `MapGenerator._apply_scene_uids()` once types are assigned. Types not listed keep
whatever they have — LEVEL rooms are meant to vary, so they stay the level pool's business.

> This can't be a `const Dictionary`: `UIDs.WORKSHOP_SCENE_UID` is an autoload member
> access, which is not a constant expression. It parses and then fails at load.

### 3.3 `MainGame.enter_workshop()`

```gdscript
func enter_workshop(workshop_uid: String) -> void:
    unload_scene(SceneContainer.UI)
    _current_room = load_scene(workshop_uid, SceneContainer.LEVEL) as Workshop
```

- **Loads into `SceneContainer.LEVEL`**, so the existing `exit_room()` tears it down like
  any other room with no special-casing. `exit_room`'s `if _current_room is BaseLevel`
  guard already skips the player-removal and `EXIT_LEVEL` modifier pass.
- **The HUD comes down.** The map HUD anchors its clock into the top-left and its modifier
  row into the bottom-right — the same corners the bench uses. The Workshop carries its own
  copy of both instead, and `exit_room()` already restores the map HUD on the way out.
- `Workshop` is a `RoomScene` (`Node2D`) whose UI lives on a **`CanvasLayer`**, so it needs
  no camera of its own — the map's camera leaves with the map.

`should_tick_time = false` in the scene, so choosing is never a time trial. A player
carrying **Live Wire** is the exception: it switches the clock back on, which is exactly
why the workshop shows a clock at all.

### 3.4 Flow

```
_ready()
 ├── _read_terms()        ← asks ModifiersSystem for offers/picks/rerolls/skip bonus
 ├── _build_strip()       ← clock + carried-modifier row
 └── _open()
      ├── fade backdrop + UI in
      └── _lay_out_bench()
           ├── pool.draw(offers, depth, system)
           ├── build cards, width computed from the count
           └── _deal_cards()   staggered
```

- **Terms are read once, on arrival.** The bench a player is standing at does not change
  underneath them because the card they just took widened future benches.
- **Depth** is `Global.main_game.map.progress`, defaulting to 0 if there is no map.
- Taking a card **banks the modifier before the animation** — the player pressed the
  button, so it's theirs regardless of what happens next.
- `_busy` guards every entry point, so a second click during the take animation can't spend
  a pick that isn't there. `_closing` makes `_close()` idempotent.
- Spending the last pick closes the bench automatically; the skip bonus is paid only if
  `_picks_taken == 0`.
- `notify_workshop_visited()` is the **last** thing before the fade, so one-shot perks see
  the true final pick count.

---

## 4. The UI

### 4.1 The constraint

The viewport is **320×180** with integer scaling. That single number drove every layout
decision: three cards get ~84px each, five get ~55px, and there is no room for a
description on a card at either size.

`window/stretch/aspect` is `expand`, so the play area grows past 180px on some window
aspects. The layout is budgeted against the 180px **minimum** and verified there.

### 4.2 `WorkshopStyle` — one place for the design language

Palette, metrics, timings and the styleboxes built from them. Everything visual resolves
through it, so the screen can be re-tuned — or handed to real art — without card-hunting.

**Palette** — deep indigo ink, one step up for panels, one step up again for ribbons.
`PARCHMENT` is lifted straight from `main_theme.tres`'s button font colour so the workshop
and the rest of the game speak the same off-white. `EMBER` is the run's accent — a burning
fuse — and is reserved for the thing the player is about to do, never for decoration.

**Type** — two faces already in the project. Josefin Bold for headings and card names, SF
Mono for descriptions, ribbons and counters: a mono holds its shape at 6–7px where the
display face closes up, and reads as the workshop's paperwork.

> Labels have no entry in `main_theme.tres`. Without an explicit override every one of
> them renders at Godot's default 16px — three times too big for this screen. That's what
> `WorkshopStyle.apply_text()` is for.

**Every number is whole pixels.** The project renders at integer scale; a half-pixel margin
is a row of blurred pixels on a 6× screen. The hover lift is `roundf`-ed for the same
reason.

### 4.3 Rarity is never colour alone

| tier | colour | word |
|---|---|---|
| COMMON | slate | `COMMON` |
| RARE | brass | `RARE` |
| EXOTIC | fuse-green | `EXOTIC` |

Brass and fuse-green are close enough for a red-green colourblind player that the word has
to be on the ribbon too. It is, on every card.

### 4.4 `WorkshopCard`

A `Button` underneath, so focus, keyboard/gamepad confirmation and click handling are the
engine's problem. All five theme button styleboxes are overridden with `StyleBoxEmpty` and
the drawing handed to an inner `PanelContainer`.

**Hover and focus are deliberately the same state.** Pointing at a card calls `grab_focus()`
on it, so there is only ever one card lit and the mouse and the stick can never disagree
about which one it is. That single state rides on `_emphasis` (0 at rest, 1 lit) and
*everything* is a read of it — border alpha, glow, lift, scale, shadow depth, `z_index`.

```gdscript
func _apply_emphasis(value: float) -> void:
    frame.add_theme_stylebox_override(&"panel", WorkshopStyle.card_frame(entry.tier, value))
    glow.modulate.a = value
    visual.position.y = -roundf(WorkshopStyle.HOVER_LIFT * value)
    visual.scale = Vector2.ONE * lerpf(1.0, WorkshopStyle.HOVER_SCALE, value)
    z_index = 1 if value > 0.01 else 0
```

The animated node is an inner `Visual` control, not the card itself — the card's own size
belongs to the `HBoxContainer`.

**Motion** — every beat is a delayed *parallel* tweener rather than a chained sequence. The
stagger is just a delay, and there is no ordering left to get wrong.

| beat | shape |
|---|---|
| deal in | rise + fade + scale up, 0.05s stagger per card, `TRANS_BACK` |
| hover / focus | 0.10s, lift 3px, scale 1.06, `TRANS_BACK` |
| take | punch to 1.16 → flash white at the peak → settle, `TRANS_ELASTIC` |
| sweep | drop + fade, staggered |
| pass over | unchosen cards sink 2px and lose colour |

The take animation borrows `MapNode.detonate()`'s beats on purpose, down to a flash colour
in the same family — taking a modifier reads as the same kind of event as a charge going
off on the map.

**A taken card sets `focus_mode = FOCUS_NONE`**, not just `disabled`. Godot's focus
navigation walks `focus_mode`; a disabled-but-focusable card still stops the stick.

### 4.5 The description panel

Cards carry ribbon, icon and name only. The description lives in a fixed panel below the
bench that cross-fades as the lit card changes (0.06s out, write, 0.12s in) — at this size
a hard text swap reads as a flicker, not as new information.

The panel is the one part of the column allowed to absorb the screen's spare vertical
space, and it never changes size as the player moves along the bench. A box that resized
per card would be the twitchiest thing on screen.

It also prints the small print in the order it matters — rarity, then chance, then
duration, then `STACKS` — and, critically:

```gdscript
if modifier.linked_modifier != null:
    text += "\nComes with: %s." % modifier.linked_modifier.modifier_name
```

A modifier that drags a trade-off along has to say so **on the bench**. Finding out
afterwards is a gotcha, not a decision.

### 4.6 Vertical budget

| band | px |
|---|---|
| margins (4 top, 4 bottom) | 8 |
| strip — clock + carried modifiers | 16 |
| title + subtitle | ~22 |
| card row | 54 |
| description panel (minimum; absorbs slack) | 44 |
| footer — Sweep / Leave | ~21 |
| separations (2 × 5) | 10 |
| **total** | **~175 of 180** |

Card width is computed from the bench size, floored to whole pixels:

```gdscript
static func card_width(count: int, available: float) -> float:
    var each: float = (available - CARD_GAP * (count - 1)) / count
    return floorf(clampf(each, CARD_MIN_WIDTH, CARD_MAX_WIDTH))
```

Three cards sit at the 84px cap; five give ground to 55px — which is itself the visual tell
that the bench got bigger. Cards are `SIZE_SHRINK_CENTER` so they keep their drawn
proportions instead of stretching into whatever slack the row has.

---

## 5. New modifiers

12 new `.tres`. Only one needed a new script; the rest reuse existing modifier classes.

### 5.1 Workshop terms

| name | id | effect | tier |
|---|---|---|---|
| Second Set of Hands | `second_set_of_hands` | **take two instead of one**, spent on use | EXOTIC |
| Open Bench | `open_bench` | **+2 options**, permanent | RARE |
| Blueprints | `blueprints` | draw skews rare (×0.5 / ×1.8 / ×3.0); links Cluttered Bench | RARE |
| Cluttered Bench | `cluttered_bench` | −1 option — trade-off partner, not offered directly | — |
| Scrap Heap | `scrap_heap` | one sweep of the bench per workshop | COMMON |
| Union Break | `union_break` | +8s for leaving empty-handed | COMMON |

### 5.2 General

| name | class reused | effect | tier |
|---|---|---|---|
| Frost Grip | `OrbWindowModifier` | cold orbs worth 4s for a level's first 6s; links Cold Storage | RARE |
| Chain Reaction | `GainModifierModifier` | 6% chance per cold orb of a new modifier | EXOTIC |
| Wet Wick | `TickRateModifier` | 40% slower for 2 levels | COMMON |
| Dead Man's Switch | `ConditionalTimeModifier` | clear under 10s → +14s; links Punctured Tank | RARE |
| Cold Storage | `FreezeModifier` | frozen 3s at level start — trade-off partner | — |
| Punctured Tank | `AddMaxTimeModifier` | −10s max time — trade-off partner | — |

Frost Grip and Chain Reaction fill genuine gaps: nothing previously touched cold orbs, and
**nothing at all used the `COLD_ORB_TOUCHED` trigger**.

---

## 6. Tunables

`Workshop` (`workshop.gd`) — what a bench is worth before any modifier has its say:

| const | default |
|---|---|
| `BASE_OFFERS` | 3 |
| `BASE_PICKS` | 1 |
| `BASE_REROLLS` | 0 |
| `BASE_SKIP_BONUS` | 0.0 |

`MapGenerator.WORKSHOP_ROOM_WEIGHT` is 2.5 against levels' 10.0 — see §8.

Per-entry pacing lives in `default_pool.tres` (`tier`, `weight`, `min_depth`); global
rarity pacing in `Rarity.BASE_WEIGHT` / `DEPTH_GAIN`; everything visual in `WorkshopStyle`.

---

## 7. Verified behaviour

`src/debug/WorkshopCheck.tscn` — 50 checks, all passing:

```
godot --headless res://src/debug/WorkshopCheck.tscn
```

It runs as a **scene, not via `--script`**: autoloads only exist for a scene run, and half
of it touches `Global`. It boots the real `MainGame`, equips real perks and walks two full
visits.

| group | covers |
|---|---|
| pool | all 28 entries resolve a named, uniquely-ided modifier; both scenes load |
| draw | 3 offers at depths 0/4/8, no duplicates, nothing gated deeper leaks through, zero-draw is empty not an error, oversized draw caps at pool size |
| hooks | each perk's arithmetic; one-shot spends on a pick but keeps on an empty exit; a plain modifier changes nothing |
| live visit 1 | Open Bench + Second Set of Hands → 5 cards, 2 picks; take one (bench stays open) then the second (bench closes); modifiers granted; one-shot spent; permanent kept |
| live visit 2 | Scrap Heap's sweep lays a genuinely different bench and is spent; leaving empty-handed pays Union Break's 8s (30.0 → 38.0) |

The layout was also rendered at a true 320×180 and inspected at three, five and taken-card
states, including the worst-case description (a body plus a `Comes with:` line).

**Five real bugs were caught this way**, all fixed: a `const Dictionary` built from an
autoload member; `Rarity.get_name` shadowed by a built-in; `Label.clip_text` zeroing the
card name's minimum size so names never rendered; the subtitle reading "THE BENCH IS BARE"
during the opening fade; and the map HUD overlapping the bench.

---

## 8. Known limitations

- **`enter_rest` / `enter_event` are still unimplemented** (pre-existing). Selecting a HEAL
  room dead-ends the run — the map is already removed and `_current_room` stays null, so
  nothing can hand the room back. `MapGenerator` forces an entire row of HEAL rooms at row
  4, so any run reaching row 3+ will meet one. This blocks *playtesting* the workshop more
  than the workshop itself; it was left alone as an unrelated system.
- **Workshop rooms are rare.** Weight 2.5 against levels' 10.0, never consecutive, never on
  row 0. A run can finish without meeting one. Worth raising while the room is being
  tested.
- **Terms are fixed on arrival** (§3.4). Gaining Open Bench *from* a bench doesn't widen
  that same bench. Deliberate, but it surprises people.
- **A sweep re-rolls the whole bench**, including slots whose cards were already taken.
  Already-taken modifiers can't reappear (the draw filters held non-stackables), so this is
  safe — just worth knowing it isn't a partial re-roll.
- **No sound.** Signals and animation seams are in place for it; nothing is wired.
- **All visuals are procedural placeholders.** Every stylebox that a sprite should replace
  is marked `## ART:` in `workshop_style.gd`. A modifier with its `icon` set already renders
  it — the icon is the one place real art drops straight in with no code change.

---

## 9. Files

| file | change |
|---|---|
| `systems/modifiers_system/resources/modifier.gd` | **+6 workshop hooks**, all pass-through |
| `systems/modifiers_system/modifiers_system.gd` | **+6 aggregators**, incl. `notify_workshop_visited()` |
| `systems/modifiers_system/resources/rarity.gd` | **new** — tiers, colours, names, depth weights |
| `systems/modifiers_system/resources/workshop_entry.gd` | **new** — a modifier plus its offer terms |
| `systems/modifiers_system/resources/workshop_pool.gd` | **new** — weighted draw without replacement |
| `systems/modifiers_system/workshop_modifier.gd` | **new** — answers all six hooks |
| `room_scenes/workshop/workshop.gd` + `.tscn` | **new** — the room and its flow |
| `room_scenes/workshop/default_pool.tres` | **new** — 28 weighted entries |
| `ui/workshop/workshop_style.gd` | **new** — palette, metrics, timings, styleboxes |
| `ui/workshop/workshop_card.gd` + `WorkshopCard.tscn` | **new** — the card |
| `gameplay/modifiers/*.tres` | **12 new** modifiers (§5) |
| `core/main_game/main_game.gd` | `enter_shop` → `enter_workshop`, implemented; HUD unload |
| `map/generation/room.gd` | `SHOP` → `WORKSHOP`; `apply_type_scene()` |
| `map/generation/map_generator.gd` | rename; `_apply_scene_uids()` |
| `map/visuals/map_node.gd` | rename in `ROOM_ART` |
| `autoloads/uids.gd` | workshop scene/pool/card + 12 modifier UIDs |
| `debug/workshop_check.gd` + `WorkshopCheck.tscn` | **new** — 50-check headless harness |
| `room_scenes/room_scene.gd` | doc comment only |
