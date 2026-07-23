# Shop System

The shop is a platforming level (like any combat room) where the player spends
**coins or seconds** on relics and consumables, themed around the countdown.

## Design rules

- **Hybrid economy**: every `ShopItem` has a `currency` — `COINS` or `SECONDS`.
  Paying with seconds deducts from the run countdown. A purchase can never
  reduce the countdown to zero (`RunState.can_spend_time` requires a surplus).
- **Time exchange, one deal per visit**: two dedicated pedestals — Buy Time
  (coins → seconds) and Sell Time (seconds → coins). Using either locks both
  for the rest of the visit (`ShopLevel._exchange_used`).
- **+10s entry bonus** (`ShopLevel.ENTRY_BONUS_SECONDS`) so visiting is a gift.
- **One item per shop is on sale** at half price (`ShopItem.on_sale`).
- **Purchases are a moment**: buying pauses the countdown, freezes the player,
  and shows a "SOLD!" card with the item + effect. Interact dismisses it.
- **Chrono Anchor relic** freezes the countdown in shops
  (`ShopLevel.should_tick_time`, hooked via `BaseLevel` → `MainGame`).

## Who does what

| Piece | Role |
|---|---|
| `RunState` (autoload, `src/autoloads/run_state.gd`) | Owns the run: countdown, coins, relics, consumables. Signal-driven. Only place money/time is mutated. |
| `ShopItem` (`shop_item.gd`) | Resource: id, kind (RELIC / CONSUMABLE / TIME_BUY / TIME_SELL), price, currency, sale flag. Effects are identified by `id` only. |
| `ShopCatalog` (`shop_catalog.gd`) | Placeholder item pools + random stock. Replace with designed `.tres` files later — nothing else changes. |
| `ShopPedestal` (`pedestal/`) | Pure **view**: icon, price tag, "UP: buy" prompt. Emits `focus_changed` when the player stands at it. Handles **no** input or money. |
| `ShopLevel` (`src/levels/shop/`) | The **controller** and single input owner: stocks pedestals, handles the interact press (dismiss card, else buy), enforces exchange lock, drives the shopkeeper speech bubble and purchase card. |

## Purchase flow

1. Player overlaps a pedestal → `focus_changed(pedestal, true)` →
   `ShopLevel` remembers `_focused_pedestal`, shopkeeper bubble pitches the item.
2. Interact press → `ShopLevel._unhandled_input`:
   card open? dismiss it : `_try_purchase(_focused_pedestal)`.
3. `_try_purchase` validates (sold / locked / exchange used), pays via
   `RunState.try_spend_coins/time`, grants via `RunState.add_relic/consumable/time/coins`,
   marks the pedestal sold, then `_show_purchase_card` (pause + freeze + card).
4. Dismiss → unfreeze, `RunState.set_ticking(should_tick_time())`.

## How to…

- **Add an item**: append a `ShopItem.make(...)` to a pool in `ShopCatalog`.
- **Implement a relic effect**: match on its id where relevant, e.g.
  `RunState.has_relic(&"chrono_anchor")`. See `ShopLevel.should_tick_time`.
- **Change shop frequency on the map**: `SHOP_ROOM_WEIGHT` in `map_generator.gd`.
- **Route a new level type**: `MainGame._on_map_node_selected`.

## Testing

Headless smoke test (purchase logic + real input path with a real player):

```sh
godot --headless res://src/debug/ShopSmokeTest.tscn
```

Exits 0 on success. Run it after touching shop/RunState code.
