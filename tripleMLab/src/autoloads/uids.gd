extends Node

# UI
const START_MENU_SCENE_UID: String = "uid://decj2y8v3qpdf"
const MAP_HUD_SCENE_UID: String = "uid://ogipvp6hivr7"
const LEVEL_HUD_SCENE_UID: String = "uid://4o0nmaeak4ns"
const MODIFIER_DISPLAY_SCENE_UID: String = "uid://dv6ct8mkr3jqw"

# WORLD
const MAP_SCENE_UID: String = "uid://ipmc68r6n333"
const PLAYER_SCENE_UID: String = "uid://kwjq37d8yab5"
const TEST_LEVEL_UID: String = "res://src/levels/initial_levels/Level1.tscn"
const WORKSHOP_SCENE_UID: String = "uid://bkq7wn3vxm2td"
const TREASURE_ROOM_SCENE_UID: String = "uid://dn8kw3vqm7xbt"

# WORKSHOP
const WORKSHOP_DEFAULT_POOL_UID: String = "uid://cm2vj7xkq9nsw"
const WORKSHOP_CARD_SCENE_UID: String = "uid://dp5nt8crj4wxb"

# TREASURE
## The good and corrupted chest, dealt across a treasure row.
const TREASURE_SET_UID: String = "uid://cn6wb3vkm9xqt"
const TREASURE_GOOD_UID: String = "uid://bv8kq4nwm6xtr"
const TREASURE_CORRUPTED_UID: String = "uid://dk2mx7wnq5vbc"

## The three ways a chest can be opened. Which one a chest allows is a flag on
## its table, so adding a fourth game is a scene, a uid and one enum value.
const TREASURE_COIN_GAME_UID: String = "uid://bw6mq2nvk9xtr"
const TREASURE_WHEEL_GAME_UID: String = "uid://ck4nx8wbm3qvt"
const TREASURE_PLINKO_GAME_UID: String = "uid://dt9vm5nkq2wxb"

# SYSTEMS
const TIME_SYSTEM_UID: String = "uid://bjktioxpxjuo"
const MODIFIERS_SYSTEM_UID: String = "uid://sgn327tv2pc6"

# MODIFIERS - start of level
const COLD_FUSE_UID: String = "uid://b3xkq7wvn5dtm"
const COATING_UID: String = "uid://cn9dh4prj2wsl"
const WARM_CATCH_UID: String = "uid://cp4vs9lmt6bxh"
const PRIMED_UID: String = "uid://dk6mt8zbv3rqx"
const DOUBLE_PRIMED_UID: String = "uid://bw2fj5nch7xkd"
const DETONATE_UID: String = "uid://dr8kn3wqz5jvm"

# MODIFIERS - end of level
const SPARE_FUSE_UID: String = "uid://bivxio7ycorca"
const FRESH_FUSE_UID: String = "uid://bm5tc7xdw2nhk"
const LUCKY_BREAK_UID: String = "uid://dt7wb4nxh9lqs"
const LUCKY_FIND_UID: String = "uid://cz3jq8vpk6mrt"
const OVERTIME_UID: String = "uid://bq6ml2skv8dcn"
const BARELY_MADE_IT_UID: String = "uid://ch5rp9wtj4xzm"
const SPEEDRUNNERS_PRIZE_UID: String = "uid://dv8ks3mqb7ntw"
const LIVE_WIRE_UID: String = "uid://cw7dm2vqk9tbs"

# MODIFIERS - event based
const CHEAP_FUSE_UID: String = "uid://b7kxuvi3xud53"
const JERRY_CAN_UID: String = "uid://bn4zx6hcw5lrp"
const SLOW_BURN_UID: String = "uid://dj3nh8lrx6pmv"
const FAST_BURN_UID: String = "uid://bs9wk5tzc2qdn"
const ADRENALINE_UID: String = "uid://bz5hw9nkq4jrm"
const DAMP_FUSE_UID: String = "uid://bh8jn6czv3rlk"
const LUCKY_DAMP_FUSE_UID: String = "uid://dp3kb2vhm6wxz"
const DOUBLE_TIME_UID: String = "uid://ct5mw9xdq7bsn"
const DASH_UPGRADE_UID: String = "uid://cl6vb3mnp8wjx"
const DOUBLE_JUMP_UPGRADE_UID: String = "uid://dq2xs7wkh4mtb"
const COSTLY_DASH_UID: String = "uid://bv7ln4srj9tqc"
const COSTLY_POGO_UID: String = "uid://cx2qm8wbk5nhd"
const BIGGER_TANK_UID: String = "uid://dm6ts3xvp7cwl"
const WET_WICK_UID: String = "uid://bk2mv7xqc5nrt"
const FROST_GRIP_UID: String = "uid://cq8vn3mtx7bkw"
const COLD_STORAGE_UID: String = "uid://bw3nk6vqm8trx"
const DEAD_MANS_SWITCH_UID: String = "uid://cn5wj8kzr3mqv"
const PUNCTURED_TANK_UID: String = "uid://dh7bq2nvx9kwl"
const CHAIN_REACTION_UID: String = "uid://dg4kw9pnb2vsm"

# MODIFIERS - combined cards (a bonus with a drawback linked to it)
const OVERPRESSURE_UID: String = "uid://bq7xm3nvk9wtd"
const SHORT_FUSE_UID: String = "uid://cn2vw8kqx4mrb"
const DEAD_AIR_UID: String = "uid://dm6bq4nwx8ktv"
const HAZARD_PAY_UID: String = "uid://bk9wv3mqn6xtc"
const LOOSE_WIRING_UID: String = "uid://cw5nq8vbm2xkr"
const OVERCHARGE_UID: String = "uid://dt3kx6nwq9vmb"
const CASH_ADVANCE_UID: String = "uid://bv8mn4kwq3xrt"
const COLD_SNAP_UID: String = "uid://cq6wb9nxm5vkt"
const TIME_AND_A_HALF_UID: String = "uid://dn4vm7kqx8wbr"

# MODIFIERS - drawbacks, only ever reached as the second half of a combined card
const PRESSURE_LOSS_UID: String = "uid://bn3kw7vqx2mtd"
const RACING_WICK_UID: String = "uid://cr8mv4nkq6wzt"
const OPEN_CIRCUIT_UID: String = "uid://dk5nw9xbm3qvr"
const SPARKING_CONTACT_UID: String = "uid://bw6qt3nkc8mxv"
const THIN_SKIN_UID: String = "uid://ch4mb8wvn5rkt"
const DOCKED_PAY_UID: String = "uid://dv9nk2xqm7bwt"

# MODIFIERS - treasure terms
const LUCKY_CHARM_UID: String = "uid://bx4nq9wmk7vtd"
const PADDED_CRATE_UID: String = "uid://dw7kv2nxb5mqr"
const THUMB_ON_THE_SCALE_UID: String = "uid://cj4nv7wxk2mtb"
## The drawback half of Thumb On The Scale — never offered on its own.
const ON_THE_CLOCK_UID: String = "uid://bn7mk4wxq2vtc"
const SECOND_CHANCE_UID: String = "uid://dp8mk3nwq6vxr"
const MAGPIES_EYE_UID: String = "uid://bt5wn9kvx3qmc"
const SALVAGE_RIGHTS_UID: String = "uid://ck7bm2vnq8wxt"
const SHALLOW_SEAM_UID: String = "uid://dv4kn6wxm9btq"

# MODIFIERS - workshop terms
const SECOND_SET_OF_HANDS_UID: String = "uid://bs4mv9xkq7ntd"
const OPEN_BENCH_UID: String = "uid://cd7nk3wvx5rmp"
const CLUTTERED_BENCH_UID: String = "uid://dv3nb8kxm6qwl"
const BLUEPRINTS_UID: String = "uid://dw9qt6mnb4xks"
const SCRAP_HEAP_UID: String = "uid://bh5jx2vwc8ntr"
const UNION_BREAK_UID: String = "uid://ck6mw4rzq9vbt"
const DANGER_MONEY_UID: String = "uid://bh2wq6nvx4mkt"
