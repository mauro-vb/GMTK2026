# The Workshop

The shop room is now a **workshop**: a bench between levels with three modifiers laid out
on it, and the player takes one.

The interesting part isn't the room — it's that the workshop never asks *which* modifiers
the player is carrying. Every number it runs on is a question put to the modifiers
themselves, so a modifier that widens the bench or buys a second pick is **a `.tres` file,
not a change to the workshop**.

Some cards are **combined**: a bonus that drags a drawback along with it — "+30s
max time, but −5s at the end of every level". That is authoring rather than code
too, and §1.4 explains why it needed no new mechanism at all.

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
## Rebalances the draw, by whether a card carries a trade-off.
func modify_workshop_offer_weight(w: float, _combined: bool) -> float:  return w
## Seconds paid out for walking away without taking anything.
func modify_workshop_skip_bonus(seconds: float) -> float:              return seconds
## Return true to be dropped — how a one-shot perk spends itself.
func on_workshop_visited(_picks_taken: int) -> bool:                   return false
## Would this do anything for the run as it stands? A bench won't offer a dead pick.
func is_useful(_modifiers_system: ModifiersSystem) -> bool:            return true
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
| `clean_weight_scale` | 1.0 | multiplier on plain cards' share of the draw |
| `combined_weight_scale` | 1.0 | …on trade-off cards' |
| `consume_on_use` | false | spend itself after a visit the player took from |

Nothing here triggers. `trigger_modifier()` is left as the base no-op — these are answered
passively, the same way Coating answers orb hooks.

**`consume_on_use` only fires when `picks_taken > 0`.** Walking away empty-handed doesn't
burn a one-shot perk, because it didn't do anything.

### 1.4 Combined cards need no mechanism

A **combined card** is one modifier that grants a bonus and drags a drawback
along with it — "+30s max time, but −5s at the end of every level".

There is no `ComboModifier`, no `bonus`/`drawback` pair, and no new field. A card
is combined **iff its modifier carries a `linked_modifier`**:

```gdscript
func is_combined() -> bool:
    return modifier != null and modifier.linked_modifier != null
```

`linked_modifier` already meant "gaining this also grants that", and
`ModifiersSystem.add_modifier()` already follows it one level deep. Kick Start
(dash, plus Costly Dash) was shipping on this before the workshop existed — it
became a combined card the moment the UI learned to read the link, without its
`.tres` being touched.

The consequences are worth stating plainly, because they are the whole reason
for doing it this way:

- **Authoring a combined card is writing two `.tres` files**, one pointing at the
  other. No code.
- **A card can never lie.** The seam prints `linked_modifier.modifier_name` and
  the detail panel prints its description, so what's advertised is exactly what
  gets granted.
- **Both halves are ordinary modifiers** — separate durations, separate
  `chance`, separate entries in the modifier display. A drawback on a `LEVELS`
  duration expires on its own schedule.
- **Drawbacks are never offered alone.** They aren't in the pool; the only way to
  meet one is through the card that carries it. `workshop_check` asserts this.

`chance` covers the "some bonus, but a risk of losing time" shape with no new
work either: a drawback with `chance = 0.3` and `type = EXIT_LEVEL` is a 30%
chance of a penalty at each level's end.

---

## 2. The offer pool

### 2.1 `WorkshopEntry` — a modifier plus its terms

```gdscript
@export var modifier: Modifier
@export var weight: float = 1.0   # relative draw weight
@export var min_depth: int = 0    # map row before which this never appears
```

Terms are kept off the modifier deliberately. "How good is this?" belongs to the modifier;
"how often does it turn up on a bench, and how early" belongs to the run's pacing — and
the same modifier can arrive by other routes (Lucky Find, a linked trade-off) that these
terms have no say over.

`is_available(depth, system)` filters out anything gated deeper than the current row,
anything the player already holds unless the modifier is `stackable`, and anything
that would be a **dead pick** (§2.3).

### 2.2 Pacing without rarity

There are no rarity tiers. A card is not "rare" — it is either available at this
depth or it isn't, and it either draws often or it doesn't. Two numbers per
entry carry all of it:

- **`min_depth`** gates anything that reads as a payoff. Run-defining modifiers
  sit at rows 2–4; the plain time cards are available from row 0.
- **`weight`** tunes how often something turns up among what's available.

Then the player's own modifiers get a say, by whether a card carries a trade-off
— the only axis the draw has, and the interesting one. **Blueprints** multiplies
plain cards ×2.0 and trade-off cards ×0.25; **Danger Money** does the reverse
(×0.35 / ×2.5). One buys safety, the other buys power at a price.

### 2.3 Dead picks

Some modifiers only modify *another* modifier's effect. **Primed** refunds an
ability's time cost — and abilities cost nothing until something has priced them:

```gdscript
var cost: float = ability_time_costs.get(ability, 0.0)
if cost <= 0.0:
    return                    # ← never reaches the free-use counter
```

Exactly two modifiers price an ability (`AbilityCostModifier`): **Costly Dash**,
which rides along with Kick Start, and **Costly Pogo**. On a run carrying
neither, Primed and Double Primed are cards that do *literally nothing*, and both
were offerable from row 0 — a trap, because they read like plain upgrades and
cost a bench slot that could have been +15 seconds.

So a modifier gets asked whether it would do anything, and the pool won't lay out
one that says no:

```gdscript
func is_useful(modifiers_system: ModifiersSystem) -> bool:
    if modifiers_system == null:
        return true                    # nobody to ask ≠ known useless
    for modifier: Modifier in modifiers_system.modifiers:
        if modifier is AbilityCostModifier:
            return true
    return false
```

Asked of the **modifier**, not encoded in the pool, and asked **by class**, not by
id. Both on purpose: a third modifier that prices an ability makes Primed
offerable again on its own, with no list for anyone to forget to update.

Everything else inherits `true` from the base and is unaffected.

> Not yet wired into `GainModifierModifier` — Lucky Find and Chain Reaction can
> still hand out a Primed that does nothing. Same one-line fix if it turns out to
> matter in play.

### 2.4 The draw

`WorkshopPool.draw(count, depth, modifiers_system)` is weighted and **without
replacement**: the winner is removed from the candidate list and its weight subtracted
from the running total rather than the whole list being re-summed each round.

Running short of candidates lays out a **smaller bench** rather than repeating itself or
failing, and pushes a warning. Asking for zero returns empty rather than erroring.

### 2.5 `default_pool.tres`

45 entries, 13 of which are combined cards. The seven treasure charms are in here too:
a chest is another moment in the same run, so a card that changes one is drawn from the same
bench (see `docs/treasure.md` §5.2).

Only upgrades and two-edged trades are in the pool. **Pure downgrades are never
offered**; they reach the player only as the second half of a combined card, which
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

### 4.3 Two kinds of card, one distinction

The palette has exactly one job on the bench: say whether a card costs you
something.

| kind | edge & glow | seam |
|---|---|---|
| plain | `EDGE` — slate | none |
| combined | `CAUTION` — dusty red | red strip naming the drawback |

`CAUTION` is deliberately kept clear of `EMBER`, the run's accent. Ember means
"this is what you're here to do" — it's on the instruction at the top of the
screen. Red means "this one bites". They must never read as the same colour.

The seam is a **ruled line over a wash**, not a filled block: the drawback
belongs to the card, it isn't a second card stuck underneath it. And it is never
colour alone — the drawback's name is printed in it, and repeated in full in the
description panel.

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
    frame.add_theme_stylebox_override(&"panel", WorkshopStyle.card_frame(entry.is_combined(), value))
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

It prints the small print in the order it matters — chance, then duration, then
`STACKS` — and, for a combined card, gives the cost **its own line in its own
colour**:

```gdscript
detail_cost.visible = entry.is_combined()
if entry.is_combined():
    detail_cost.text = "%s: %s" % [
        modifier.linked_modifier.modifier_name,
        modifier.linked_modifier.get_description(),
    ]
```

Not appended to the description: on a combined card the cost is half the
decision, and it must not read as a footnote to the good half. Finding out
afterwards would be a gotcha, not a decision.

### 4.6 Layout: the bench spans the column

Cards do **not** have a computed width. Each one is `SIZE_EXPAND_FILL`, so the
`HBoxContainer` divides the full column between them:

```gdscript
card.custom_minimum_size = Vector2(WorkshopStyle.CARD_MIN_WIDTH, WorkshopStyle.CARD_HEIGHT)
card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
```

That is what makes the bench's outer edges land **exactly on the description
panel's**, at any bench size — they're siblings in the same `VBoxContainer`, so
they inherit the same span. A fixed width left the row floating inset inside the
panel below it, which was the single biggest thing making the screen look
cramped. Three cards get ~97px each, five get ~58px, and the alignment holds
either way.

Vertically the cards keep the height they were drawn at rather than stretching
into the row's slack. Every card reserves two lines for its name, so a name that
wraps doesn't shove that one card's icon out of line with its neighbours.

| band | px |
|---|---|
| margins (5 top, 5 bottom) | 10 |
| strip — clock, room name, carried modifiers | 12 |
| instruction | ~13 |
| card row | 56 |
| description panel (minimum; absorbs slack) | 40 |
| footer — Sweep / Leave | ~21 |
| separations (6 × 4) | 24 |
| **total** | **~176 of 180** |

The status strip carries the clock, the room's name and the carried-modifier row;
the **instruction** ("TAKE ONE", "TAKE 2 · 1 LEFT") is the header, in ember. The
thing that changes and that the player has to act on is the biggest text on the
screen; the room's name is a quiet tag. That reordering is also what stopped a
lifted card's glow from colliding with the line above it.

---

## 5. New modifiers

28 new `.tres`. Exactly one needed a new script (`WorkshopModifier`); everything
else reuses modifier classes that already existed.

### 5.1 Workshop terms

| name | id | effect |
|---|---|---|
| Second Set of Hands | `second_set_of_hands` | **take two instead of one**, spent on use |
| Open Bench | `open_bench` | **+2 options**, permanent |
| Blueprints | `blueprints` | bench favours plain cards (×2.0 / ×0.25); links Cluttered Bench |
| Danger Money | `danger_money` | bench favours trade-off cards (×0.35 / ×2.5) |
| Cluttered Bench | `cluttered_bench` | −1 option — trade-off partner, not offered directly |
| Scrap Heap | `scrap_heap` | one sweep of the bench per workshop |
| Union Break | `union_break` | +8s for leaving empty-handed |

### 5.2 Combined cards

Each is a bonus `.tres` whose `linked_modifier` points at a drawback `.tres`.

| card | bonus | drawback it carries |
|---|---|---|
| **Overpressure** | +30s max time | *Pressure Loss* — −5s at every level's end |
| **Short Fuse** | +10s right now | *Racing Wick* — next level burns at double speed |
| **Dead Air** | clock doesn't tick at all next level | *Open Circuit* — it burns on the map for 2 levels |
| **Hazard Pay** | +6s every level cleared | *Punctured Tank* — −10s max time |
| **Loose Wiring** | 20% slower burn, permanently | *Sparking Contact* — 30% chance of −8s at level end |
| **Overcharge** | first 3 abilities each level are free | *Cold Storage* — 3s frozen at level start |
| **Cash Advance** | +25s right now | *Cluttered Bench* — every future workshop shows one fewer option |
| **Cold Snap** | cold orbs worth 4s for a level's first 8s | *Thin Skin* — hot orbs burn 4s in that window |
| **Time and a Half** | +8s if a level takes over 30s | *Docked Pay* — −8s if it takes under 15s |
| **Kick Start** | *(pre-existing)* you can dash | *Costly Dash* — every dash burns 1s |

Kick Start is in that list without having been edited: it already carried a
`linked_modifier`, so it became a combined card for free when the UI learned to
read the link. That is the architecture working.

Three drawbacks are reused rather than written (`punctured_tank`,
`cold_storage`, `cluttered_bench`); six are new (`pressure_loss`, `racing_wick`,
`open_circuit`, `sparking_contact`, `thin_skin`, `docked_pay`).

### 5.3 Plain additions

| name | class reused | effect |
|---|---|---|
| Frost Grip | `OrbWindowModifier` | cold orbs worth 4s for a level's first 6s; links Cold Storage |
| Chain Reaction | `GainModifierModifier` | 6% chance per cold orb of a new modifier |
| Wet Wick | `TickRateModifier` | 40% slower for 2 levels |
| Dead Man's Switch | `ConditionalTimeModifier` | clear under 10s → +14s; links Punctured Tank |

Frost Grip and Chain Reaction fill genuine gaps: nothing previously touched cold
orbs, and **nothing at all used the `COLD_ORB_TOUCHED` trigger**.

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

Per-entry pacing lives in `default_pool.tres` (`weight`, `min_depth`); everything
visual in `WorkshopStyle`.

---

## 7. Verified behaviour

`src/debug/WorkshopCheck.tscn` — 74 checks, all passing:

```
godot --headless res://src/debug/WorkshopCheck.tscn
```

It runs as a **scene, not via `--script`**: autoloads only exist for a scene run, and half
of it touches `Global`. It boots the real `MainGame`, equips real perks and walks two full
visits.

| group | covers |
|---|---|
| pool | all 45 entries resolve a named, uniquely-ided modifier; both scenes load |
| combined | the pool offers combined cards but not only combined cards; **no drawback is offered on its own**; every drawback has a name and a description to print |
| draw | 3 offers at depths 0/4/8, no duplicates, nothing gated deeper leaks through, zero-draw is empty not an error, oversized draw caps at pool size |
| hooks | each perk's arithmetic; one-shot spends on a pick but keeps on an empty exit; a plain modifier changes nothing |
| clock | overlapping rate contributions multiply, unwind in any order, and never leave the clock at 0 — see §8a |
| dead picks | Primed is hidden on a run with nothing priced and returns once something is; an ordinary modifier is never hidden |
| live visit 1 | Open Bench + Second Set of Hands → 5 cards, 2 picks; take one (bench stays open) then the second (bench closes); modifiers granted; one-shot spent; permanent kept |
| live visit 2 | Scrap Heap's sweep lays a genuinely different bench and is spent; leaving empty-handed pays Union Break's 8s (30.0 → 38.0) |
| live visit 3 | Danger Money puts a combined card on the bench; its seam names the drawback; taking it grants **both** halves |

Live visit 3 used to be flaky, and the cause was worth writing down: it opened its bench at
the run's **depth 0**, where the only two-edged cards in the pool are the two ability
upgrades that drag a cost along — and an earlier group in the same file could already have
taken both, at which point no bench could ever satisfy it. It now sets `map.progress` to 4
first, which is where the combined cards actually live, and opens up to
`COMBINED_ATTEMPTS` benches before giving up. Danger Money makes a two-edged bench very
likely; it was never asked to make one certain.

The layout was also rendered at a true 320×180 and inspected at three, five and taken-card
states, including the worst-case description (a body plus a `Comes with:` line).

**Five real bugs were caught this way**, all fixed: a `const Dictionary` built from an
autoload member; a static `get_name` shadowed by a built-in; `Label.clip_text` zeroing the
card name's minimum size so names never rendered; the subtitle reading "THE BENCH IS BARE"
during the opening fade; and the map HUD overlapping the bench.

---

## 8. Known limitations

- ~~**`enter_rest` / `enter_event` are still unimplemented**~~ — `enter_rest` is now
  `enter_treasure` and the forced row halfway through the run is a row of chests, so a run
  no longer dead-ends on it. See `docs/treasure.md`. `enter_event` is still unimplemented,
  and the generator still never produces `Room.Type.EVENT`.
- **Workshop rooms are rare.** Weight 2.5 against levels' 10.0, never consecutive, never on
  row 0. A run can finish without meeting one. Worth raising while the room is being
  tested.
- **Terms are fixed on arrival** (§3.4). Gaining Open Bench *from* a bench doesn't widen
  that same bench. Deliberate, but it surprises people.
- **A sweep re-rolls the whole bench**, including slots whose cards were already taken.
  Already-taken modifiers can't reappear (the draw filters held non-stackables), so this is
  safe — just worth knowing it isn't a partial re-roll.
- **Combined halves expire independently.** Both are ordinary modifiers, so a
  bonus on a `LEVELS` duration can run out while its drawback is still running,
  or the reverse. Where that matters the two are authored with matching
  durations, but nothing enforces it — worth a look if a pairing feels wrong.
- **Dead Air's drawback needs a playtest, not a check.** `MapTimeModifier`'s
  on/off timing is entangled with `exit_room`'s ordering (see the note in that
  script), and a `LEVELS` duration on top of it is not something the headless
  harness can judge the feel of.
- **No sound.** Signals and animation seams are in place for it; nothing is wired.
- **All visuals are procedural placeholders.** Every stylebox that a sprite should replace
  is marked `## ART:` in `workshop_style.gd`. A modifier with its `icon` set already renders
  it — the icon is the one place real art drops straight in with no code change.

---

## 8a. The clock fix combined cards forced

Modifiers used to scale the clock by **saving and restoring** `TimeSystem.tick_rate`
around themselves. `TickRateModifier` even documented the flaw: *"two overlapping
tick-rate modifiers only unwind cleanly if they expire in reverse order… if
overlapping ones become common, TimeSystem should multiply a list of
contributions."*

Combined cards made them common. Frost Grip carries a freeze (rate 0), and
several cards carry tick-rate drawbacks, so the pairing is now routine — and it
was run-ending:

| step | old behaviour |
|---|---|
| freeze triggers | snapshots 1.0, sets rate 0 |
| slow-burn triggers | snapshots **0**, sets 0 × 0.6 = 0 |
| freeze thaws | restores 1.0 — **the slow-burn is silently gone** |
| slow-burn expires | restores its snapshot: **0. The clock is dead for the rest of the run.** |

Reproduced deterministically, then fixed the way the old comment prescribed:
`TimeSystem` keeps a dictionary of named contributions and derives `tick_rate` as
their product. A modifier only ever adds or removes its own entry, keyed per
*instance* so two stacks each count:

```gdscript
func set_rate_contribution(key: StringName, multiplier: float) -> void
func clear_rate_contribution(key: StringName) -> void
```

There is no ordering left to get wrong. `tick_rate` stays a plain readable
property, so its two outside readers were untouched.

Worth knowing: **"Wet Wick" never actually worked before this.** Any freeze in
the same level wiped its slow-burn on thaw. The fix is what makes it — and every
tick-rate drawback on a combined card — do what its card says.

---

## 9. Files

| file | change |
|---|---|
| `systems/modifiers_system/resources/modifier.gd` | **+6 workshop hooks** and `is_useful()`, all pass-through |
| `systems/modifiers_system/modifiers_system.gd` | **+6 aggregators**, incl. `notify_workshop_visited()` |
| `systems/time_system/time_system.gd` | rate contributions replace save/restore (§8a) |
| `systems/modifiers_system/tick_rate_modifier.gd` | registers a contribution instead of snapshotting |
| `systems/modifiers_system/freeze_modifier.gd` | same |
| `systems/modifiers_system/free_ability_modifier.gd` | `is_useful()` — hides Primed when nothing is priced |
| `systems/modifiers_system/resources/workshop_entry.gd` | **new** — a modifier plus its offer terms; `is_combined()` |
| `systems/modifiers_system/resources/workshop_pool.gd` | **new** — weighted draw without replacement |
| `systems/modifiers_system/workshop_modifier.gd` | **new** — answers all six hooks |
| `room_scenes/workshop/workshop.gd` + `.tscn` | **new** — the room and its flow |
| `room_scenes/workshop/default_pool.tres` | **new** — 28 weighted entries |
| `ui/workshop/workshop_style.gd` | **new** — palette, metrics, timings, styleboxes |
| `ui/workshop/workshop_card.gd` + `WorkshopCard.tscn` | **new** — the card |
| `gameplay/modifiers/*.tres` | **28 new** modifiers (§5), incl. 9 combined pairs |
| `core/main_game/main_game.gd` | `enter_shop` → `enter_workshop`, implemented; HUD unload |
| `map/generation/room.gd` | `SHOP` → `WORKSHOP`; `apply_type_scene()` |
| `map/generation/map_generator.gd` | rename; `_apply_scene_uids()` |
| `map/visuals/map_node.gd` | rename in `ROOM_ART` |
| `autoloads/uids.gd` | workshop scene/pool/card + 12 modifier UIDs |
| `debug/workshop_check.gd` + `WorkshopCheck.tscn` | **new** — 74-check headless harness |
| `room_scenes/room_scene.gd` | doc comment only |
