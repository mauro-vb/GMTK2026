# Treasure Rooms

Halfway through a run every path crosses the same row: **three chests, side by side**. The
player takes one, and it either puts seconds on the clock or takes them off.

The interesting part isn't the payout — it's that the three chests are three *different bets*,
each one is played as a minigame you can actually make a decision in, and each one states its
terms by how it is drawn rather than by printing percentages at you. A chest is a `.tres`
file: its odds, its payouts, and which minigames may present it. **Adding a fourth chest is
authoring, not code.**

This document covers the chest row, the tables, the three minigames and what each one does
about the odds, the room's flow, and the modifier hooks it extends.

---

## 1. The row

`MapGenerator` already forced an entire row of rooms halfway through the run — it was
`Room.Type.HEAL`, wearing `chest.png`, and selecting one dead-ended the run because
`enter_rest()` pushed an error and returned (`docs/workshop.md` §8). That row is now the
treasure row.

### 1.1 `HEAL` → `TREASURE`

Same enum position, so no stored room type was invalidated — the same move `SHOP` →
`WORKSHOP` made. The generator's weight constant and its no-consecutive rule renamed with
it, `MapNode.ROOM_ART`'s key renamed with it, and `enter_rest()` became `enter_treasure()`.

The room was never a heal. Calling it what it is stops the generator's rules from reading as
though they were protecting a rest stop.

### 1.2 Chests are dealt, not rolled

```gdscript
for current_row: Array[Room] in map_data:
    var chests: Array[Room] = ...        # TREASURE rooms that a path actually reaches
    var dealt: Array[TreasureTable] = treasure_set.deal(chests.size())
```

Per **row**, from a shuffled set, rather than each chest rolling independently. Three
independent rolls would routinely put the same bet on two of the three paths and quietly
turn the choice into a question about geometry. A row wider than the set reshuffles and
carries on, so a five-chest row is two repeats rather than five of the same.

Rooms with no outgoing cords are the ones no path reaches — `Map.create_map()` never draws
them — so they are left out of the deal instead of eating a kind.

The chest lands on `Room.treasure`, which is read by two places and nothing else:
`MapNode` for its icon, and `TreasureRoom` for the game it lays out.

### 1.3 How the room knows which chest it is

`Map` sets `last_room` **before** it emits `selected`, so by the time the room exists the
node the player clicked is already on record:

```gdscript
Global.main_game.map.last_room.treasure
```

`MainGame.enter_room()` keeps its `(uid, type)` signature — no room type had to grow a
payload for one of them to carry a chest. `TreasureRoom` falls back to an exported
`fallback_table` when there is no map behind it, which is what makes the scene runnable on
its own and what the check harness uses to walk all three chests in one run.

---

## 2. The chests

### 2.1 `TreasureTable` — the whole of a chest's design

```gdscript
@export var table_name: String
@export_multiline var description: String
@export_flags("Coin Flip:1", "Wheel:2", "Plinko:4") var games: int
@export var slices: Array[TreasureSlice]     # weight + seconds, per outcome
@export var map_icon: Texture2D              # ART
@export var spent_icon: Texture2D            # ART
```

**The odds live here**, and every game is built out of them — but they don't all resolve the
same way. The coin and the wheel ask the table to `roll()` and then spend their animation
arriving at that answer, so a wheel's wedges can never drift from the chest's odds. A plinko
board instead lays its bins out *from* these weights and lets the ball find one (§3.3), so it
plays close to the chest without being dictated by it. That difference is the point of having
a board at all.

`rarest_slice()` is the least likely outcome — the thing a chest is really about, whichever
direction it points. On Rich Seam it is the disaster; on Dead Drop it is the jackpot.

### 2.2 The three shipped

| chest | odds | plays as | why you'd take it |
|---|---|---|---|
| **Even Split** | 50% **+12s** / 50% **−12s** | coin | the honest one. No edge, no trick, and you call it yourself. |
| **Rich Seam** | 70% **+10s** / 30% **−18s** | wheel *or* plinko | usually pays; the rare outcome is the one that hurts. |
| **Dead Drop** | 70% **−8s** / 30% **+28s** | wheel *or* plinko | usually bites; the rare outcome is the one worth having. |

Expected value runs +0.0s / +1.6s / +2.8s — the more likely a chest is to hurt you, the more
it is worth in the long run. That ordering is the point: the safe-looking chest is the
boring one.

Two chests allow two games each and pick between them **per visit**, so meeting Rich Seam
twice in a run is not the same event twice.

### 2.3 One board, two decisions

Rich Seam and Dead Drop share both minigames, with the probabilities the other way round.
That is not a saving on work — it is the design. A plinko board's edges pay the wildest
numbers, so the *same* board is a trap on Rich Seam (a −27 bin on the left edge) and the
entire reason to be there on Dead Drop (a +42 bin in the same place). The player learns one
board and reads two opposite situations off it.

---

## 3. The minigames

All three are `TreasureGame`s: a `Control` that is handed a table, emits `resolved(slice)`
when it is done, and draws itself procedurally out of `TreasureStyle`. Art drops in where a
game exports a texture and is never required.

The rule they share: **the player commits before anything is decided.** Calling a side,
letting go of the spin, dropping the ball — every one of them happens before the outcome
exists, so the choice is real.

### 3.1 Coin flip — exact

The player calls heads or tails, and calling it right is worth the table's better outcome.
The table still decides, so a chest authored 60/40 would come out 60/40 with the same
animation over it; the coin never hard-codes a half.

Landing on the right face is arithmetic, not luck: every half-turn swaps the face, so the
*parity* of the half-turn count is the face it lands on, and the toss takes one extra
half-turn when it would otherwise come down wrong.

`can_present()` returns false for anything that isn't exactly two slices — a coin with three
faces is not a coin — and the room falls through to a game that can show it.

### 3.2 Wheel — exact, and no way to cheat it

Wedges are cut **by weight**: each slice keeps exactly its share of the circle, chopped into
several wedges dealt alternately around the rim so the rare outcome appears at two or three
places instead of as one solid block the player can watch approaching.

Because the angles stay exactly proportional, where the pointer lands *is* the table's odds.
The outcome is drawn from the table first and the rotation is worked backwards from it, so
float drift can't put the pointer on a wedge that disagrees with the result.

**Holding the button winds the spin up.** That is drama, not odds — the charge picks how
many *whole* turns are travelled, and whole turns land in the same place. The code says so
where it happens, so nobody has to take it on trust.

### 3.3 Plinko — the one with a decision in it

**Nine bins, ten rows of pegs, drawn as a narrow centred column** rather than across the
whole screen: a lattice as wide as the viewport makes the ball travel further sideways than
it ever falls, which reads as sliding rather than dropping. One drop slot per bin, pinned to
the same column, so a slot sits exactly above the column it drops into.

#### The row alternates, and it is a picture of the odds

Bins are dealt rarest-outcome-first, spread at even intervals from bin 0, with each outcome
taking a share of the row equal to its share of the odds. Nine bins is chosen for exactly
that: 30% rounds to three of them.

```
Dead Drop  (70% −8s / 30% +28s)    +42  −10   −8  +21   −4   −6  +28  −10  −12
Rich Seam  (70% +10s / 30% −18s)   −27  +13  +10  −14   +5   +8  −18  +13  +15
```

Good, bad, bad — and the same row inverted on the chest that pays. Spreading rather than
blocking is what makes the board a gamble at *every* slot instead of a choice between a
green half and a red half, and never more than two alike in a row is asserted, not hoped
for.

It comes out deliberately **lopsided**: one edge holds the rare outcome at its wildest, the
other holds the common one at its wildest. The two ends of the board are two different bets,
which is the point — the player has to actually look at it.

#### The bins get wilder toward the edges

An edge bin pays `WILD_SCALE` (1.5×) what the table says, the middle pays `MILD_SCALE`
(0.5×), linear in between and symmetric. Across the row those average out to about 1.0, so
the board is worth what the chest is worth overall — just never evenly. The middle is small
money either way; the edges are where a run gets decided.

Each bin is a *copy* of its outcome with the seconds already scaled, so the number drawn on
the bin and the number the clock gets are literally the same object and cannot drift apart.
Bins also fill harder the further out they sit: the wild ones are visible before any number
is read.

**That row of numbers is the only thing this board states.** See §3.4.

#### The fall decides — nothing is rolled

Unlike the coin and the wheel, the board does not draw an outcome and then drive the ball to
it. Each row is an even chance of half a bin left or right, a bounce that would carry the
ball off the board is taken the other way — there are walls — and the bin it ends over is
the result:

```gdscript
func _fall_columns(from_bin: int) -> Array[float]     # ten coin flips and two walls
```

Ten rows is an even count, so a walk that starts over a bin ends over one. There is no
target, no reachability constraint, and **no slot that guarantees anything** — which is the
whole reason a drop slot is worth choosing rather than a button worth pressing.

The odds this produces are the board's own, and because the row is built from the chest's
ratio *and* its outcomes alternate, they land close to it from almost anywhere:

| chest | from the middle | from the edges | the chest itself |
|---|---|---|---|
| Rich Seam | 33% | 29% | 30% |
| Dead Drop | 33% | 28% | 30% |

So the slot barely moves the odds and moves the **stakes** enormously — a left-edge drop on
Dead Drop is mostly choosing between +42 and −10 instead of +21 and −4. That is the choice
worth giving, and it is one the player reads off the bins rather than off a percentage.

Each hop is **two tweens running together** — sideways overshoots the peg and comes back
(`TRANS_BACK`, the ricochet), downwards accelerates into it (`TRANS_QUAD`) — and every hop
takes a randomly different length of time, so the rhythm never settles into a metronome.

Before the drop, the ball waits in the chute above whichever slot is being pointed at, which
is what makes this "put the ball somewhere" rather than "press one of nine buttons".
Pointing at a slot moves focus to it — the workshop's rule — so the mouse and the stick can
never disagree about where the ball is. Once it lands, the ball is remembered as a **bin
index rather than a pixel position**: the column resizes underneath it the moment the result
strip lands, and a pixel would leave the ball hanging where the board used to be.

### 3.4 No room states a percentage

The chests used to print their odds as a line under the room's title, and the plinko slots
used to print what each one did to them (`46 43 39 35 30 35 39 43 46`). Both are gone.

A wheel says its odds with the size of its wedges. A board says them with the shape of its
row. A coin has two sides. A line of percentages on top of that is the same information
twice, in the form nobody reads — and on the slots it was worse than redundant: a percentage
on a drop slot is a promise a free-falling ball does not make.

What survives is **what each outcome is worth**, and only where it changes a decision:

| game | prints | because |
|---|---|---|
| coin | nothing | heads or tails is symmetric — no number changes how you call it |
| wheel | the seconds on each wedge | anticipation; the only input is SPIN |
| plinko | the seconds in each bin | this *is* the decision — which slot to drop down |

The consequence worth stating: a player meeting a chest for the first time learns what it
pays by opening it. Which chest to walk into is a decision made on the map, where the art
distinguishes them — see §8.

---

## 4. The room

### 4.1 It is the workshop again

`TreasureRoom` is a `RoomScene` whose UI lives on a `CanvasLayer`, loaded into
`SceneContainer.LEVEL` so `exit_room()` tears it down like any other room, with the map HUD
unloaded because the room carries its own clock and carried-modifier strip. All of that is
`enter_workshop()`'s shape, deliberately — see `docs/workshop.md` §3.3 for why each part is
that way.

`should_tick_time = false`: a gamble is not a time trial.

### 4.2 Flow

```
_ready()
 ├── _resolve_table()      ← the chest the player clicked, off map.last_room
 ├── _tilt()               ← every held modifier's say over its odds, before anything draws
 ├── _build_strip()        ← clock + carried-modifier row
 ├── _refresh_header()     ← the chest's name, before anything is played
 └── _open()
      ├── fade backdrop + UI in
      └── _lay_out_game()
           ├── shuffle the games this chest allows
           ├── first one whose can_present() agrees, wins
           └── begin()  → the player is now in control
                          resolved(slice)
                           ├── bit, and something pays for it? → _retry() ─┐
                           └── otherwise → _settle() → _offer_card()       │
                                                                 ↑────────┘
                                                          (laid out again)
```

There is no way to walk away from a chest. The choice was made on the map; the Leave button
does not exist until the chest has paid out.

If no game can present the table at all, the room rolls the table and pays out anyway rather
than stranding a run in a room it can't leave.

### 4.3 What the clock actually gets

```gdscript
var before: float = _time_system.current_time
if slice.is_gain():
    _time_system.add_time(_gain_seconds(slice.seconds))
else:
    _time_system.remove_time(_lose_seconds(-slice.seconds))

_applied = _time_system.current_time - before
```

**Measured, not assumed.** The clock has a ceiling, so a +28s jackpot landing on a nearly
full clock is worth less than it says on the tin, and the room reports what the run actually
got. The alternative is a number on screen the clock disagrees with.

And when the two differ, **the room says why**: a payout that overflowed prints `PAID OUT ·
TANK FULL`, a bite the run was too short to take prints `IT BITES · NOTHING LEFT`. Without
that line the truth reads as a bug — a chest rolling +12s onto a clock six seconds short of
full pays exactly +6s, and a player who watched +12s promised has no way to tell a ceiling
from a cheat.

Losses are floored: `SURVIVAL_FLOOR = 2.0` seconds a chest will not take the clock below. A
chest is a gamble on the run, not the end of it — and a run that walks into the next level on
nothing is over anyway without ever being told why. Set the constant to `0.0` to let chests
kill.

---

## 5. The extension point

The third family of passive hooks on `Modifier`, alongside the orb hooks and the workshop
hooks, in exactly the same shape:

```gdscript
## Seconds a chest is about to pay out. `seconds` is positive.
func modify_treasure_gain(seconds: float) -> float:                    return seconds
## Seconds a chest is about to take. `seconds` is positive — an amount, not a signed change.
func modify_treasure_loss(seconds: float) -> float:                    return seconds
## One outcome's share of the odds, asked before the chest is laid out.
func modify_treasure_weight(weight: float, _is_gain: bool) -> float:   return weight
## Return true to buy one more opening of a chest that just bit.
func wants_treasure_retry(_seconds: float) -> bool:                    return false
## Odds this chest hands over a modifier as well as seconds.
func modify_treasure_card_chance(chance: float, _was_gain: bool) -> float: return chance
## Return true to keep the fuse burning while the chest is open.
func runs_clock_in_treasure() -> bool:                                 return false
## Return true to be dropped — how a one-shot charm spends itself.
func on_treasure_opened(_seconds: float) -> bool:                      return false
```

Pass-through by default, so **every pre-existing modifier inherits "changes nothing about a
chest" for free** and no existing `.tres` was touched. `ModifiersSystem` folds each across
everything held (`get_treasure_gain`, `get_treasure_loss`, `get_treasure_weight`,
`claim_treasure_retry`, `get_treasure_card_chance`, `is_treasure_clock_running`,
`notify_treasure_opened`), and the seconds getters clamp at zero, so stacked modifiers can
never flip a payout into a bite.

The two seconds hooks take a **positive amount**, which is why a modifier that halves losses
can't accidentally halve a win.

### 5.1 The odds, and the condition they come with

The first pass at this file said there would be no hook for a chest's odds, because a chest
states its terms before the player commits and a modifier that quietly bent them would make
that statement a lie. **The objection was right; the conclusion was too strong.** What makes
a bent number a lie is bending it *after* the chest has drawn itself.

So `modify_treasure_weight` is asked **once per outcome, on arrival, before any minigame
exists** — `TreasureRoom._tilt()`, called on the way out of `_resolve_table()`. Everything
downstream reads its odds off that one tilted table: the wheel cuts its wedges from it, the
board deals its row from it, `roll()` draws from it. A player carrying two Thumbs On The
Scale walks into a 70% chest and sees a wheel that is **82% green**, because the wheel was
cut after the tilt. The drawing is still the truth; it is the truth about the chest they are
actually holding.

Three properties fall out of doing it there and only there:

- **The `.tres` on disk is never touched.** The tilt is a copy, slices and all, made per
  visit — so the next chest of that kind is the authored one again, and two runs never
  disagree about what Rich Seam is.
- **It can't invert an outcome.** `get_treasure_weight()` clamps at zero: a stacked tilt can
  shrink a side away to nothing, but a negative share of the odds is not a thing.
- **A tilt that empties a chest is refused.** If nothing has weight left, the room opens the
  chest as authored and warns, rather than laying out a chest that cannot resolve.

The exception worth knowing: **the coin can't show a tilt.** A wheel has wedge sizes and a
board has a row shape, but a coin has two sides and says nothing about odds by design
(§3.4), so a tilted Even Split is a 50/50-looking coin that isn't one. It is the one place
in the room where a charm's effect is only legible from the charm.

### 5.2 `TreasureModifier`

One class answers all seven hooks, the way `WorkshopModifier` answers the workshop's.

| export | default | effect |
|---|---|---|
| `gain_scale` | 1.0 | multiplier on seconds won |
| `loss_scale` | 1.0 | multiplier on seconds lost |
| `gain_weight_scale` | 1.0 | multiplier on how likely the paying outcomes are |
| `loss_weight_scale` | 1.0 | multiplier on how likely the biting ones are |
| `gain_bonus_seconds` | 0.0 | flat seconds on top of a win, after the scale |
| `retry_on_loss` | false | pays for a chest that bit to be opened again |
| `gain_card_chance` | 0.0 | odds a chest that paid also hands over a modifier |
| `loss_card_chance` | 0.0 | odds a chest that bit does |
| `runs_clock` | false | the fuse keeps burning while the chest is open |
| `consume_on_use` | false | spend itself on the first chest it actually changed |

`consume_on_use` asks "did this do anything?" — a charm that only sweetens wins is not spent
by a loss, and one that only softens losses is not spent by a win. `retry_on_loss` doesn't
need it: the retry is spent inside `claim_treasure_retry()` at the moment it is used, which
is also what stops a second chance from looping (§5.4).

Card chances fold as **independent** chances rather than adding up, so two charms that each
search half the chests come out at three quarters. Stacking them is worth something and
never worth everything.

**Seven cards ship**, all in the workshop pool:

| name | id | terms | effect |
|---|---|---|---|
| **Lucky Charm** | `lucky_charm` | 0.8 / row 1 | chests that pay, pay **half again** |
| **Padded Crate** | `padded_crate` | 0.8 / row 1 | chests that bite, take **half as much** |
| **Thumb On The Scale** | `thumb_on_the_scale` | 0.7 / row 2 | **combined** — every chest ×1.6 likelier to pay, and shows it; comes with **On The Clock** |
| **Second Chance** | `second_chance` | 0.8 / row 1 | the first chest that bites is **opened again**; spent |
| **Magpie's Eye** | `magpies_eye` | 0.6 / row 2 | **half** the chests that pay also hand over a card |
| **Salvage Rights** | `salvage_rights` | 0.6 / row 2 | **60%** of the chests that bite hand over a card instead |
| **Shallow Seam** | `shallow_seam` | 0.7 / row 2 | pays **twice as often** and **40% less** |

Shallow Seam is a trade-off inside a single card rather than a `linked_modifier` pair: both
halves are about what one chest pays, so splitting them across two icons would say less than
one line does.

### 5.2a Thumb On The Scale, and what better odds cost

Thumb On The Scale is the **combined card** (`docs/workshop.md` §1.4): the bonus carries
`linked_modifier` → **On The Clock**, so taking it grants both halves and the bench prints
the cost on the card's seam before the player commits.

The price is the interesting part. Everything else a treasure room could charge is *seconds
off a payout* — and paying for better odds with a smaller win is a wash, not a trade. So the
cost is the room's own rule instead:

> `should_tick_time = false` — a gamble is not a time trial.

**On The Clock takes that away.** The fuse keeps burning while the lid is up, so a chest
costs whatever the player spends deciding — which lands hardest exactly where the room is
most interesting, on the plinko board with nine slots to weigh up. Better odds, worse
composure.

```gdscript
func _read_clock_terms() -> void:      # TreasureRoom, in _ready
    if _modifiers_system == null or not _modifiers_system.is_treasure_clock_running():
        return
    should_tick_time = true
```

Flipping the room's **own flag** rather than writing to `time_system.ticking` is the whole
trick: `MainGame.enter_room()` does `time_system.ticking = _current_room.should_tick_time`
immediately after loading the room, so a direct write would be overwritten one line later.
Changing what the room says about itself is read by the thing that asks. ("Live Wire" solves
the same problem on the map screen a different way — it is typed `EXIT_LEVEL` so it fires in
the one gap where nothing else owns `ticking`.)

`is_treasure_clock_running()` is an **any**, not a fold: a second copy of a cost that is
already being paid is not twice the cost.

The room says it twice, because a clock that has quietly started running is the one thing
here a player must not be left to notice for themselves: the chest's name line reads
`RICH SEAM · ON THE CLOCK`, and the clock in the corner is drawn in the run's warning colour
instead of as quiet furniture.

**Worth knowing:** nothing in the game listens to `TimeSystem.time_expired` yet, so running
out mid-chest currently costs the run nothing but the seconds. When death lands, this card
becomes the first thing that can kill in a treasure room — `SURVIVAL_FLOOR` protects the
player from the *chest*, not from the fuse.

### 5.3 A card in the lining

`_offer_card()` runs last in `_settle()`, after the one-shot charms have spent themselves —
so a card found in a chest can't be burned by the chest that handed it over.

It draws from **the workshop's own pool at the run's current depth**, which is the whole of
what keeps it honest: a chest can only hand out what a bench that deep could have laid out,
`min_depth` holds, and modifiers the player already has (and can't stack) are filtered out
by `WorkshopEntry.is_available()` exactly as they are on a bench. `TreasureRoom.card_pool`
is exported for a chest-specific pool and falls back to the workshop's when left null, which
is what ships.

The card announces itself twice: its icon lands in the carry strip on the spot (the strip
listens to `modifier_added`, the way the workshop does), and the header names it —
`PAID OUT · BARELY MADE IT`. Without the name, the only sign of it is one more icon in a row
of icons.

### 5.4 A second chance

Asked in `_on_game_resolved()`, **before a single second moves**, and only about a bite: a
second chance is insurance, not a reroll of a payout the player was happy with.

When one is claimed, the chest is **laid out again from scratch** rather than replayed —
which usually means a different one of the chest's minigames, and is the honest reading of
"open it again". The second outcome stands.

It cannot loop, and not by a counter: `ModifiersSystem.claim_treasure_retry()` removes the
modifier that agreed *before* returning true, so a run gets exactly as many reopenings as it
brought charms to buy them with.

---

## 6. Tunables

| where | const | default |
|---|---|---|
| `TreasureRoom` | `SURVIVAL_FLOOR` | 2.0s |
| `TreasureRoom` | `RETRY_PAUSE` | 0.9s |
| `PlinkoGame` | `BINS` / `PEG_ROWS` | 9 / 10 |
| `PlinkoGame` | `BOARD_WIDTH` | 160px, centred |
| `PlinkoGame` | `WILD_SCALE` / `MILD_SCALE` | 1.5 / 0.5 |
| `PlinkoGame` | `ROW_TIME` / `HOP_JITTER` | 0.12s / ×0.7–1.4 |
| `WheelGame` | `TARGET_WEDGES` | 8 |
| `WheelGame` | `MIN_TURNS` / `MAX_TURNS` | 2 / 6 |
| `CoinFlipGame` | `FLIP_HALF_TURNS` | 10 |
| `MapGenerator` | `TREASURE_ROOM_WEIGHT` | 4.0 (against levels' 10.0) |

Odds and payouts live in the three `.tres` tables; everything visual in `TreasureStyle`,
which borrows the palette, the type and the text helpers from `WorkshopStyle` rather than
restating them — the treasure room is another moment in the same run, not another game.

---

## 7. Verified behaviour

`src/debug/TreasureCheck.tscn` — 192 checks, all passing:

```
godot --headless res://src/debug/TreasureCheck.tscn
```

There is also `src/debug/TreasureDemo.tscn`, which is not a test: it boots the real game
straight into a chest, so the room can be played (and shown to the artist) without walking
four levels of a run to reach one. `1` / `2` / `3` pick a chest, `R` re-opens the same one,
leaving rolls on to the next.

| group | covers |
|---|---|
| tables | the set holds three uniquely named, valid chests; each allows a game and can both pay and bite |
| scenes | the room and all three minigame scenes load by uid |
| odds | **20,000 rolls per chest** land within 3 points of the advertised percentages — and an edge plinko drop really is the tilted number it prints on the button, and really is more likely than the middle |
| shapes | Even Split is a coin toss paying and biting the same; Rich Seam usually pays and its rare outcome hurts; Dead Drop usually bites and its rare outcome is worth having |
| the coin | all four combinations of call × outcome, **forced rather than sampled**: calling right pays the better outcome, calling wrong pays the worse one, and the face it comes down on always agrees with what it paid |
| the board | on a real board at the size the room gives it: bin counts match the odds, never more than two alike in a row, the rare outcome leads from the edge, every bin pays its own outcome scaled by its position and never flips sign, and the edges beat the middle |
| the fall | **4,000 free drops from each of the nine slots, per chest**: the ball never leaves the board, always comes to rest over a whole bin, **no slot is a guarantee** (nothing above 98% or below 2%), and the rare outcome lands within ten points of the chest's own odds both overall and from the middle |
| hooks | each charm's arithmetic, in isolation and folded through the system; a plain modifier changes nothing, is never spent, bends no odds and buys no reopening; a negative amount can't become a payout; a negative tilt clamps at zero; two card charms fold to 75% rather than to 100%; **all seven cards are reachable from a bench** |
| chest row | 20 generated maps: every chest knows which chest it is, points at the right scene, and **no row ever offers the same chest twice** |
| live rooms | all three games played end to end through the real `MainGame`: the clock moves by exactly what the room reports, in the direction the outcome said, and the way out only appears once it has paid |
| charms | Lucky Charm and Padded Crate measured on a real payout; a forced payout against a 57-second clock fills the tank, reports the 3s that actually landed, and says `TANK FULL`; the survival floor holds on a 4-second clock |
| a tilted chest | Thumb On The Scale walked into a real Rich Seam: the card brings its drawback with it, the room opens the chest at **79% rather than 70%**, the minigame was handed that same tilted table, the `.tres` on disk is still 70% afterwards — and the fuse really is burning (`MainGame` started the clock, seconds came off standing still, and the name line says `ON THE CLOCK`) |
| a second chance | a **forced bite** through the real room: it buys the reopening, spends the charm, moves the clock by nothing yet, keeps the way out shut, lays the chest out again as a *different* game object, lets the second outcome be the one that lands, and does not reopen a third time on an empty pocket |
| the lining | a **forced payout** with a certain searcher: the card is drawn, carried, named in the header and iconed in the strip — and a run carrying nothing gets seconds and nothing else |

The layout was also rendered at the shipping resolution and inspected in all three games, at
the waiting, mid-animation and result states.

The coin's own bug was caught in **playtest, not by the harness** — which is why the harness
now forces all four combinations rather than tossing a few and hoping:

> The resting face was *derived* from where the spin stopped, and `11 * PI / PI` is
> `10.999999999999998`, which floors to 10 and reads as the wrong face. Eleven half-turns is
> exactly the case where the coin has to land on the opposite side from the one it started
> on — so **every toss that should have come down tails came down heads**, while still
> paying out correctly for tails. It looked like the chest was rewarding a wrong call. The
> face is now *assigned* from the same boolean that decided the outcome, so the two cannot
> disagree by construction.

Playtest also caught the two buttons reading as though one was already picked: focus was
styled in the run's accent, the same as hover. Focus is now a quiet wash
(`TreasureStyle.cursor_button`) — a cursor, not a choice — on the coin's sides and the
board's nine slots alike.

Four more bugs came out of rendering it:

- minigames built themselves in `setup()`, before they were in the tree, so every
  `@onready` control was null — they build in `_ready()` now, which is also what lets the
  room ask `can_present()` before committing;
- the room reported the *intended* payout rather than the one the clock's ceiling allowed;
- the landed plinko ball was remembered in pixels, so it hung in mid-air below the board
  when the result strip resized it (it is a bin index now, and every game clips its own
  drawing to its board);
- the Leave button appearing at the moment of the result shrank the board under it. It now
  holds its place from the start and only fades in.

---

## 8. Known limitations

- **The chests share one icon.** All three wear `chest.png` until the art exists. Each
  table has `map_icon` and `spent_icon` slots and `MapNode` already prefers them, so the
  three chests become distinguishable on the map with no code change — which they need to
  be, because telling them apart *is* the choice.
- **No art anywhere else either.** The coin is a drawn disc with an H or a T on it, the
  plinko ball is a dot. `CoinFlipGame.heads_texture` / `tails_texture` and
  `PlinkoGame.ball_texture` are the drop-in points, and one coin sprite covers both games.
- **No sound.** Every seam for it is there — `resolved`, the landing beat, the payout delay
  — and nothing is wired.
- **A chest can't be declined.** Deliberate: the decision was which chest to walk into. If
  playtesting says players want to back out, that is a Leave button shown before
  `begin()` and a `notify_treasure_opened(0.0)`.
- **A tilt is invisible on the coin** (§5.1). The wheel and the board draw themselves out of
  the tilted odds; a coin has two sides whatever the odds are. Even Split is the only
  coin-only chest, so a run holding Thumb On The Scale gets one chest in three where the
  charm is real but unreadable. The fix, if it matters, is the coin drawing its faces at
  different sizes — which is a design decision, not a bug fix.
- **The retry doesn't say what it saved you from.** A second chance prints
  `IT BIT · SECOND CHANCE` and re-lays the board, but never shows the number it tore up. It
  is deliberate for now — the outcome was never applied, so showing it invites the player to
  mourn seconds they never lost — and it is the first thing to revisit if playtesting says
  the charm feels like it did nothing.
- **`_last_resolved()` in the check harness recovers the outcome from the direction the
  clock moved**, which works because every shipped table has exactly one payout and one
  bite. A table with two payouts would need the room to record the slice it settled on.
- **The plinko reach constraint** (§3.3) is warned about, not enforced. A table authored
  with many outcomes could lay one out further from a slot than the ball can travel.
- **Treasure rooms outside the forced row are still weighted at 4.0** and gated to row 3+,
  as the old heal rooms were. Those are single chests rather than a row of three, so they
  are a bet rather than a choice — worth deciding whether that is wanted now that the row
  is the headline.
- **`enter_event` remains unimplemented** (pre-existing). The generator never produces
  `Room.Type.EVENT`, so nothing reaches it.

---

## 9. Files

| file | change |
|---|---|
| `room_scenes/treasure/resources/treasure_slice.gd` | **new** — one outcome: weight + seconds |
| `room_scenes/treasure/resources/treasure_table.gd` | **new** — a chest: odds, payouts, allowed games, map art |
| `room_scenes/treasure/resources/treasure_set.gd` | **new** — every chest kind, and the deal across a row |
| `room_scenes/treasure/tables/*.tres` | **new** — Even Split, Rich Seam, Dead Drop, and the set |
| `room_scenes/treasure/treasure_room.gd` + `.tscn` | **new** — the room and its flow; `_tilt()`, `_retry()`, `_offer_card()`, `_read_clock_terms()` |
| `room_scenes/treasure/games/treasure_game.gd` | **new** — base: a presentation of a table |
| `room_scenes/treasure/games/coin_flip_game.gd` + `.tscn` | **new** — call it in the air |
| `room_scenes/treasure/games/wheel_game.gd` + `.tscn` | **new** — wedges cut by weight |
| `room_scenes/treasure/games/plinko_game.gd` + `.tscn` | **new** — the board with a decision in it |
| `ui/treasure/treasure_style.gd` | **new** — gain/loss colours, board furniture, timings |
| `systems/modifiers_system/treasure_modifier.gd` | **new** — answers all seven hooks |
| `systems/modifiers_system/resources/modifier.gd` | **+7 treasure hooks**, all pass-through |
| `systems/modifiers_system/modifiers_system.gd` | **+7 aggregators**, incl. `claim_treasure_retry()` and `is_treasure_clock_running()` |
| `gameplay/modifiers/lucky_charm.tres`, `padded_crate.tres` | **new** — 2 charms |
| `gameplay/modifiers/thumb_on_the_scale.tres`, `second_chance.tres`, `magpies_eye.tres`, `salvage_rights.tres`, `shallow_seam.tres` | **new** — 5 charms: odds, a retry, and two ways a chest hands over a card |
| `gameplay/modifiers/on_the_clock.tres` | **new** — the drawback half of Thumb On The Scale; never in the pool |
| `room_scenes/workshop/default_pool.tres` | +7 entries, so the charms are reachable |
| `core/main_game/main_game.gd` | `enter_rest` → `enter_treasure`, implemented |
| `map/generation/room.gd` | `HEAL` → `TREASURE`; `treasure` field; scene uid |
| `map/generation/map_generator.gd` | rename; `_assign_treasure_tables()` |
| `map/visuals/map_node.gd` | rename in `ROOM_ART`; per-chest icon with fallback |
| `autoloads/uids.gd` | room, set, 3 tables, 3 games, 8 modifiers |
| `debug/treasure_check.gd` + `TreasureCheck.tscn` | **new** — 192-check headless harness |
| `debug/treasure_demo.gd` + `TreasureDemo.tscn` | **new** — play the chests without walking a run to one |
