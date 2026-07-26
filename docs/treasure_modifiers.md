# Treasure Modifiers

Chests could already be sweetened or softened by two charms. This adds **five more cards and
one drawback**, and the three mechanisms they needed: a chest's *odds* can be leaned on, a
chest that bites can be *opened again*, and a chest can hand over a *modifier* as well as
seconds.

`docs/treasure.md` is the system reference — how a chest works, what a `TreasureTable` is,
why the room prints no percentages. **This document is the branch-level view**: what was
added, what each card does, and why each one is shaped the way it is.

---

## 1. The cards

Seven treasure cards now ship. All seven are in the workshop pool, so they arrive the way
every other modifier does.

| card | id | terms | what it does |
|---|---|---|---|
| **Lucky Charm** | `lucky_charm` | 0.8 / row 1 | chests that pay, pay **half again** *(pre-existing)* |
| **Padded Crate** | `padded_crate` | 0.8 / row 1 | chests that bite, take **half as much** *(pre-existing)* |
| **Thumb On The Scale** | `thumb_on_the_scale` | 0.7 / row 2 | **combined** — chests are **×1.6 likelier to pay**, and show it. Comes with **On The Clock** |
| **Second Chance** | `second_chance` | 0.8 / row 1 | the first chest that bites is **opened again**. Spent on use |
| **Magpie's Eye** | `magpies_eye` | 0.6 / row 2 | **half** the chests that pay also hand over a card |
| **Salvage Rights** | `salvage_rights` | 0.6 / row 2 | **60%** of the chests that bite hand over a card instead |
| **Shallow Seam** | `shallow_seam` | 0.7 / row 2 | pays **twice as often** and **40% less** |

Plus one drawback, which is **never offered on its own** — it reaches the player only as the
second half of the card that carries it:

| drawback | id | what it does |
|---|---|---|
| **On The Clock** | `on_the_clock` | the fuse keeps burning while a chest is open |

*Terms* are `weight / min_depth`: relative share of the draw, and the map row before which a
card never appears. Both live on the `WorkshopEntry` rather than on the modifier, because
"how good is this" and "how early should the run see it" are different questions
(`docs/workshop.md` §2.1).

### 1.1 Thumb On The Scale — better odds, and what they cost

The **combined card** (`docs/workshop.md` §1.4): a bonus carrying `linked_modifier`, so
taking it grants both halves and the bench prints the cost on the card's seam *before* the
player commits.

- **The bonus:** every paying outcome gets ×1.6 its share of the odds. A 70% Rich Seam opens
  at **79%**; a Dead Drop jackpot goes from 30% to **41%**.
- **The cost:** `On The Clock` — the treasure room's own rule is `should_tick_time = false`,
  *a gamble is not a time trial*, and this takes it away.

The price is the interesting part. Everything else a treasure room could charge is seconds
off a payout — and paying for better odds with a smaller win is a wash, not a trade. Making
the *clock* the cost means a chest now costs whatever the player spends deciding, which
bites hardest exactly where the room is most interesting: the plinko board, with nine slots
to weigh up.

It is also the card that makes the map's chest choice interesting a second time. Dead Drop
is the worst chest on the map and the best one to point a thumb at.

### 1.2 Second Chance — insurance, not a reroll

Asked **before a single second moves**, and only about a bite: a payout the player is happy
with is never re-rolled.

When it fires, the chest is **laid out again from scratch** rather than replayed — which
usually means a different one of the chest's minigames, and is the honest reading of "open
it again". The second outcome stands, better or worse.

It cannot loop, and not by a counter: the modifier that agrees is removed *before* the
retry is granted, so a run gets exactly as many reopenings as it brought charms to buy them
with.

### 1.3 Magpie's Eye / Salvage Rights — a chest that owes more than time

Two halves of the same idea, split by what the chest did. Magpie's Eye searches the chests
that pay; Salvage Rights takes something off the ones that bite, which is the one that
changes how a bad chest feels.

Cards are drawn from **the workshop's own pool at the run's current depth**, which is what
keeps them honest: a chest can only hand over what a bench that deep could have laid out,
`min_depth` still holds, and anything the player already carries (and can't stack) is
filtered out exactly as it is on a bench.

Their chances fold as **independent** chances rather than adding up, so two searchers come
out at 75% rather than at certainty. Stacking is worth something and never worth everything.

### 1.4 Shallow Seam — a trade-off inside one card

Pays twice as often and hands over 40% less. Deliberately *not* a `linked_modifier` pair:
both halves are about what one chest pays, so splitting them across two icons would say less
than one line does.

---

## 2. What had to be built

Three of the cards needed mechanisms that did not exist. Each is one hook on `Modifier`, one
fold on `ModifiersSystem`, and a handful of lines in `TreasureRoom` — the same shape the orb
hooks and the workshop hooks already had.

### 2.1 Odds can be leaned on — but only before the chest is drawn

`docs/treasure.md` used to say flatly *"There is no hook for a chest's odds"*, because a
chest states its terms by how it is drawn (wedge sizes, the shape of the plinko row) and a
modifier that quietly bent those numbers would make the drawing a lie.

**The objection was right; the conclusion was too strong.** What makes a bent number a lie is
bending it *after* the chest has drawn itself. So the hook is asked **once per outcome, on
arrival, before any minigame exists**:

```gdscript
_table = _tilt(_resolve_table())      # TreasureRoom, in _ready
```

Everything downstream reads its odds off that one tilted table — the wheel cuts its wedges
from it, the board deals its row from it, `roll()` draws from it. A player carrying Thumb On
The Scale walks into a 70% chest and sees a wheel that is **79% green**, because the wheel
was cut after the tilt. The drawing is still the truth; it is the truth about the chest they
are actually holding.

Three properties fall out of doing it there and only there:

- **The `.tres` on disk is never touched** — the tilt is a copy, slices and all, made per
  visit, so the next chest of that kind is the authored one again.
- **It can't invert an outcome** — the fold clamps at zero.
- **A tilt that empties a chest is refused** — the room opens it as authored and warns,
  rather than laying out a chest that cannot resolve.

The one blind spot: **a tilt is invisible on the coin.** A wheel has wedge sizes and a board
has a row shape; a coin has two sides whatever the odds are. Even Split is the only
coin-only chest, so one chest in three is a place where the charm is real but unreadable.

### 2.2 A chest can be opened again

`_on_game_resolved()` asks, before the clock is touched, whether anything the player is
carrying will pay for a bite to be torn up. If so, the game is freed and `_lay_out_game()`
runs again.

### 2.3 A chest can hand over a card

`_offer_card()` runs **last** in `_settle()`, after one-shot charms have spent themselves —
so a card found in a chest can't be burned by the chest that handed it over.

The card announces itself twice: its icon lands in the carry strip on the spot (the strip
listens to `modifier_added`, the way the workshop does), and the header names it —
`PAID OUT · BARELY MADE IT`. Without the name, the only sign of it is one more icon in a row
of icons.

### 2.4 The clock can run in a treasure room

```gdscript
func _read_clock_terms() -> void:      # TreasureRoom, in _ready
    if _modifiers_system == null or not _modifiers_system.is_treasure_clock_running():
        return
    should_tick_time = true
```

Flipping the room's **own flag** rather than writing to `time_system.ticking` is the whole
trick: `MainGame.enter_room()` does `time_system.ticking = _current_room.should_tick_time`
immediately after loading the room, so a direct write would be overwritten one line later.
Changing what the room *says about itself* is read by the thing that asks.

The room says it twice, because a clock that has quietly started running is the one thing
here a player must not be left to notice for themselves: the chest's name line reads
`RICH SEAM · ON THE CLOCK`, and the clock in the corner is drawn in the run's warning colour
instead of as quiet furniture.

---

## 3. The API that was added

Four new hooks on `Modifier`, all pass-through by default — so **every pre-existing modifier
inherits "changes nothing about a chest" for free** and no existing `.tres` was touched:

```gdscript
## One outcome's share of the odds, asked before the chest is laid out.
func modify_treasure_weight(weight: float, _is_gain: bool) -> float:       return weight
## Return true to buy one more opening of a chest that just bit.
func wants_treasure_retry(_seconds: float) -> bool:                        return false
## Odds this chest hands over a modifier as well as seconds.
func modify_treasure_card_chance(chance: float, _was_gain: bool) -> float: return chance
## Return true to keep the fuse burning while the chest is open.
func runs_clock_in_treasure() -> bool:                                     return false
```

And four folds on `ModifiersSystem`, each matching the shape of the hook it aggregates:

| fold | shape | note |
|---|---|---|
| `get_treasure_weight(base, is_gain)` | multiply through | clamps at zero |
| `claim_treasure_retry(seconds)` | first taker | **removes the modifier before returning true** — this is what stops a retry looping |
| `get_treasure_card_chance(was_gain)` | independent chances | two half-chances make 75%, never 100% |
| `is_treasure_clock_running()` | any | a second copy of a cost already being paid is not twice the cost |

`TreasureModifier` grew the exports to match: `gain_weight_scale`, `loss_weight_scale`,
`retry_on_loss`, `gain_card_chance`, `loss_card_chance`, `runs_clock`. Every one defaults to
"changes nothing", so a `.tres` only fills in what it is about.

---

## 4. Verified

```
godot --headless res://src/debug/TreasureCheck.tscn     # 192 checks, all passing
godot --headless res://src/debug/WorkshopCheck.tscn     #  74 checks, all passing
```

The treasure harness went from **121 checks to 192**. The new groups play the real
`MainGame` end to end rather than checking arithmetic:

| group | covers |
|---|---|
| hooks | every card's arithmetic in isolation and folded through the system; a plain modifier bends no odds, buys no reopening and is never spent; a negative tilt clamps at zero; two card charms fold to 75%; all seven cards are reachable from a bench |
| a tilted chest | Thumb On The Scale walked into a real Rich Seam: the card brings its drawback, the chest opens at **79% rather than 70%**, the minigame was handed that same tilted table, the `.tres` on disk is still 70% afterwards — and the fuse really is burning |
| a second chance | a **forced bite**: it buys the reopening, spends the charm, moves the clock by nothing yet, keeps the way out shut, lays the chest out again as a different game object, lets the second outcome land, and does not reopen a third time on an empty pocket |
| the lining | a **forced payout** with a certain searcher: the card is drawn, carried, named in the header, iconed in the strip — and a run carrying nothing gets seconds and nothing else |

Forced rather than sampled throughout: a chest that happened to pay would walk a retry check
straight past the thing it exists to prove.

### 4.1 A pre-existing flaky check, fixed on the way past

`WorkshopCheck`'s *"Danger Money put a combined card on the bench"* failed roughly one run in
six. The cause was worth writing down: it opened its bench at the run's **depth 0**, where
the only two-edged cards in the pool are the two ability upgrades that drag a cost along —
and an earlier group in the same file can already have taken both, at which point no bench
could ever satisfy it. It now sets `map.progress = 4` first, and opens up to
`COMBINED_ATTEMPTS` benches before giving up. Danger Money makes a two-edged bench very
likely; it was never asked to make one certain.

---

## 5. Trying it

A real run reaches the chest row about four levels in, so there is a demo:

```
godot res://src/debug/TreasureDemo.tscn
```

```
1 / 2 / 3   Even Split / Rich Seam / Dead Drop      R  again      ESC  quit
Q W E A S   Thumb On The Scale (+ On The Clock) / Second Chance /
            Magpie's Eye / Salvage Rights / Shallow Seam
C           drop everything
```

Charm keys work **while a chest is open** and land on the *next* one — a chest reads its
odds once, on arrival, and this demo opens the next chest the instant you leave the last one,
so there was no gap between rooms to equip anything in.

The console prints what actually happened: the tilted odds under the authored ones
(`charmed: 79% +10s · 21% -18s`), `reopened 1 time(s) by a second chance`, and
`and handed over 'X'`. If the printed odds and the wheel on screen ever disagree, the tilt is
leaking in somewhere it shouldn't.

Worth trying: **Q then 3** (Dead Drop on the board, where the time pressure hurts), **W then
3** (Dead Drop bites 70% of the time, so the retry fires almost immediately), and **A then
3** for Salvage Rights.

---

## 6. Known limits

- **A tilt is invisible on the coin** (§2.1). Even Split is coin-only, so one chest in three
  is a place where Thumb On The Scale is real but unreadable. The fix, if it matters, is the
  coin drawing its faces at different sizes — a design decision, not a bug fix.
- **The retry doesn't say what it saved you from.** It prints `IT BIT · SECOND CHANCE` and
  re-lays the board, but never shows the number it tore up. Deliberate for now: the outcome
  was never applied, so showing it invites the player to mourn seconds they never lost. First
  thing to revisit if the charm feels like it did nothing.
- **Nothing listens to `TimeSystem.time_expired` yet.** Running out mid-chest currently costs
  the run nothing but the seconds. When death lands, On The Clock becomes the first card that
  can kill in a treasure room — `SURVIVAL_FLOOR` protects the player from the *chest*, not
  from the fuse.
- **Card chances are not shown anywhere before the fact.** A player carrying Magpie's Eye
  learns what it does by opening chests. The card's description says it; nothing in the room
  does.

---

## 7. Files

| file | change |
|---|---|
| `systems/modifiers_system/resources/modifier.gd` | **+4 treasure hooks**, all pass-through |
| `systems/modifiers_system/modifiers_system.gd` | **+4 folds**, incl. `claim_treasure_retry()` and `is_treasure_clock_running()` |
| `systems/modifiers_system/treasure_modifier.gd` | **+6 exports** answering them |
| `room_scenes/treasure/treasure_room.gd` | `_tilt()`, `_retry()`, `_clear_game()`, `_offer_card()`, `_read_clock_terms()`, `_depth()`; `card_pool` export |
| `gameplay/modifiers/thumb_on_the_scale.tres` | **new** — the combined card |
| `gameplay/modifiers/on_the_clock.tres` | **new** — its drawback; never in the pool |
| `gameplay/modifiers/second_chance.tres` | **new** |
| `gameplay/modifiers/magpies_eye.tres` | **new** |
| `gameplay/modifiers/salvage_rights.tres` | **new** |
| `gameplay/modifiers/shallow_seam.tres` | **new** |
| `room_scenes/workshop/default_pool.tres` | +5 entries (40 → 45); the drawback is deliberately not one |
| `autoloads/uids.gd` | +6 modifier uids |
| `debug/treasure_check.gd` | 121 → **192 checks** |
| `debug/treasure_demo.gd` | charm keys, and printing what a charm actually did |
| `debug/workshop_check.gd` | fixes the flaky combined-card check (§4.1) |
| `docs/treasure.md` | §4.2 flow, §5–5.4, §6 tunables, §7 verified, §8 limits, §9 files |
| `docs/workshop.md` | pool is 45 entries, not the 38 it claimed; the flaky-check note |
