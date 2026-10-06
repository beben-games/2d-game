# Milestone 7 feel checklist (phase 1: the arena rules, tier 2, the lifts)

Play at least one tier 1 run to a win (or type `scalae` in the title's seed field: every shipped
tier unlocked on the save, no wipe), then take the new lift in the Hypogeum and play tier 2 through
to the beast and its handler, twice if you can, killing the pair in a different order each time.
`tools/run.sh` or the zips of `0.7.0-rc1`; `tools/run.sh --tier=2` starts a tier 2 run at once
whatever the save has unlocked, and `--tier=2 --seed=N` replays one (the seed and the tier are on
the gate screen and in the `RUN_END` line). The other cheats still stand: `permawhat?` (no
damage), `verso` (the thumb goes down), `dives` (1000 coins), `tabula` (wipe the save, kept as
`save.cfg.bak`).

Nobody has played tier 2 yet, and none of its looks has been judged: the arrows, the charger's
line, the banner's ring, the two bars, and the lifts are first cuts drawn in code or taken from the
tileset, and every number is a first guess. The sprites are proposals (the chort, the masked orc
under a red banner, the big zombie at 2x, the necromancer); the new sounds are stand-ins borrowed
from existing files until you supply real ones (the plan's "User actions"). Rate each row good /
meh / bad with a note in its Result cell; the knob for each is named. Phase 1 closes on this
playtest's verdict (the table at the end), and the answer to "where did you feel told" should be
"nowhere".

## The arena rules

| # | What it is | Question | Knob | Result |
|---|---|---|---|---|
| 1 | In tier 2 the screen's edge is a wall for shots. A shot that reaches it with no bounce left vanishes there, quietly: no clink, no spark (an enemy bolt too). | Did a shot vanishing at the edge feel right, or should it be heard or seen? | `Projectile._leave_view`; `Events.shot_left_view` (nothing listens yet: `Audio` and `Fx` could) | |
| 2 | A ricochet bounces off the edge as off a wall (the bounce's sound), but it travels a tile past the screen's edge (the margin) before it turns. | Did a ricochet off the edge read right, and did the moment it spent out of sight bother you? | `View.MARGIN` in `scripts/view.gd` | |
| 3 | Spawns fade in near the screen's edge, never beyond it; about one in nine fades in with its centre a few pixels past the edge, half visible. | Did any enemy appear where it felt unfair? Did a half-visible spawn read wrong? | `SpawnMath.VIEW_BAND`, `EDGE_MARGIN` in `scripts/spawn_math.gd`; `View.MARGIN` | |
| 4 | Nothing begins an attack off screen: off screen an enemy walks at you; a wind-up begun on screen finishes after you scroll away. | Were you ever hit by something you never saw begin? Did an enemy at the edge ever stand waiting oddly? | `View.on_screen`, `View.SIGHT_SLACK` | |
| 5 | Tier 2's arena is two screens each way, no obstacles; the walls are rarely in view. | Too big, too empty, or did you lose your bearings? Do the camera's follow and the aim's lean feel right at this size? | `arena_width`/`arena_height` in `data/series/tier_2.tres`; `scripts/camera.gd` | |
| 6 | A Roar's coin piles and the boss's land on the screen around you. | Did you find them all, and did any land somewhere awkward? | `Main.throw_piles`; `PileRules.RING_MIN`/`RING_MAX` in `scripts/pile_rules.gd` | |

## The arrows

| # | What it is | Question | Knob | Result |
|---|---|---|---|---|
| 7 | An arrow at the screen's edge for each enemy off screen: a pale dart; the boss's larger and red; the standard-bearer's with a small red flag. | Did you see them, and did you follow them? Are they the right size, and does the flag read? | `ARROW_SIZE`, `ARROW_INSET`, `FILL`, `FLAG_POLE`, `FLAG_SIZE` in `scripts/ui/offscreen_arrows.gd` | |
| 8 | An arrow fades in as its enemy leaves the screen and out as it comes back (over 32 px). | Did an arrow ever pop in or out? | `ARROW_FADE` | |
| 9 | Arrows that would overlap are nudged apart along the edge. Two whose enemies really cross keep their slots while they overlap and swap only once they have parted a gap apart, so for a moment each arrow can sit on the other's side. | Did you ever notice an arrow on the wrong side of its neighbour, or arrows jittering? | `ARROW_GAP`; `ArrowRules.spread` in `scripts/arrow_rules.gd` | |
| 10 | Tier 1 should never show an arrow. | Did you see one in tier 1? | `View.MARGIN` | |

## The charger

| # | What it is | Question | Knob | Result |
|---|---|---|---|---|
| 11 | The chort walks at you, stops on screen in range, and a thin chalk line on the floor shows its path for 0.7 s; the line does not follow you. | Did the line read before the run? Is its colour and width right on the sand? | `charge_range`, `windup_time` in `data/enemies/charger.tres`; `ChargeLine.WIDTH`, `COLOR`, `ALPHA_FROM`, `ALPHA_TO` in `scripts/charge_line.gd` | |
| 12 | The run crosses at 380 px/s for 0.6 s (or to a wall) through other enemies, then a 1 s skid; a shot from behind during the skid does double. | Fair to dodge? Did you find its back? | `charge_speed`, `charge_time`, `skid_time`, `back_damage_scale`, `back_arc_degrees` in `charger.tres` | |
| 13 | A dash across its path while it runs is a dare, from about 49 px ahead of the running body. | Did the crowd notice your sidesteps when you expected it to? | `Favour._passes_an_enemy`; `FavourRules.DANGER_RADIUS` | |
| 14 | Where the gate screen names the enemy that hit you most, the charger is "Chort" (the creature's name, as "Imp" and "Shaman" are); the sprite is the tileset's chort. | Right name and sprite? | `display_name`, `idle_anim`, `run_anim` in `charger.tres` | |
| 15 | Its sounds are stand-ins: the wind-up is the shaman's, the run the boss's charge (quieter), the skid the dash's whoosh. | Did the run read by ear? Which of the three most wants its own sound? | `charge_windup`, `charge`, `charge_skid` in `data/audio.json` | |

## The standard-bearer

| # | What it is | Question | Knob | Result |
|---|---|---|---|---|
| 16 | The masked orc carries a red banner, does no damage, and is solid; a faint red ring of 140 px (about a third of a screen) lies on the floor round it. | Did you see the ring, and is the radius right (only part of a spread pack covered)? | `banner_radius` in `data/enemies/standard_bearer.tres`; `RING_ALPHA`, `DISC_ALPHA` in `scripts/banner_ring.gd` | |
| 17 | Enemies inside the ring move and wind up a quarter faster (never more with two banners) under a red tint: on the red imp a deeper red, on the shaman and the orc plain. | Did the tint read, on the imp especially? Did you connect it to the banner? | `banner_haste`; `StatusEffects.HASTE_TINT` in `scripts/status_effects.gd` | |
| 18 | Where the radius reaches a wall the ring is drawn over the wall's tiles (not clipped for now). | Does it look wrong there? | `BannerRing` | |
| 19 | It keeps the nearest other enemy between itself and you and backs away when you come close; cornered between you and a wall it hovers at the edge of its flee range. | Did it read as hiding behind its pack? Did a cornered one look stuck or silly? | `flee_range` in `standard_bearer.tres`; `BearerRules.KEEP`, `EDGE`, `ANCHOR_SLACK` in `scripts/bearer_rules.gd` | |
| 20 | Its banner works from off screen; its arrow carries the flag. | When you saw the tint with no bearer in view, did you go after it? | the flag in `scripts/ui/offscreen_arrows.gd` | |
| 21 | As the last enemy alive it walks at you. | Did a round ever stall on a bearer? | `BearerRules.stand` | |
| 22 | Its arrival plays a stand-in (the boss's summon, quieter). | Does it want a horn, a hum, or nothing? | `banner` in `data/audio.json` | |

## The beast and its handler

| # | What it is | Question | Knob | Result |
|---|---|---|---|---|
| 23 | Tier 2's boss is two bodies seated along the top of the screen, with a bar each side by side at the screen's top: "Big zombie" and "Necromancer". | Did the two bars read as one fight? Right names and sprites? | `BOSS_BAR_PAIR_WIDTH`, `BOSS_BAR_GAP` in `scripts/ui/hud.gd`; `display_name` and the anims in `data/enemies/beast.tres`, `handler.tres` | |
| 24 | In a wide arena a boss is seated about 64 px above a centred player and may begin its wind-up on its first frame in view. | Did the arrival feel fair? | `SEAT_UNDER_SCREEN`, `SEAT_DEPTH` in `scripts/spawn_math.gd`; `approach_time` | |
| 25 | The beast charges in chains of three, a line before each leg, then a ring. | Could you read every leg? | `charge_chain`, `telegraph_time`, `charge_speed`, `ring_count` in `beast.tres` | |
| 26 | Kill the handler first and the beast goes wild: three legs, 0.45 s wind-ups, 470 px/s, no ring. | Fair to dash through, or too much? | `phase2_telegraph_time`, `phase2_charge_speed`, `phase2_recover_time` in `beast.tres` | |
| 27 | Kill the beast first and the handler fights alone: faster volleys and two chargers called once. | Fair, and did the call read? | `phase2_telegraph_time`, `phase2_recover_time`, `summon_count` in `handler.tres` | |
| 28 | The handler keeps 160 px away; straight above or below you it is held at the screen's edge. | Did it read as keeping far away, without hiding at the edge? | `keep_range` in `handler.tres`; `BossBrain.keep_on_screen` | |
| 29 | The handler's slow volley: five shaman bolts over 40 degrees. | Fair beside the beast's charges? | `volley_count`, `volley_spread_degrees`, `bolt` in `handler.tres` | |
| 30 | The beast roars at each chain's first wind-up (a stand-in: the boss's wind-up sound); the handler's call at its summon (the boss's summon). | Heard often enough, or too often? | `Audio.BOSS_CHAIN_SOUNDS`; `beast_roar`, `handler_call` in `data/audio.json` | |
| 31 | The meter opens at the top, as tier 1's boss round; the damage you deal to either pays against their summed health; the coins are thrown at the second death. | Did the favour feel as in tier 1's boss round? Did the second death land as the end? | `FavourRules.boss_hit_share`, `boss_kill_share`, `BOSS_GAIN_CAP` | |
| 32 | 500 and 250 hp (750 together, tier 1's boss's), 80 coins together (tier 1's boss: 60). | How long did each order take? Which order did you choose, and why? | `max_hp`, `coins` in `beast.tres`, `handler.tres` | |

## Tier 2's rounds

| # | What it is | Question | Knob | Result |
|---|---|---|---|---|
| 33 | Eight rounds: 1 chargers alone (2, then 3), 2 chargers with chasers, 3 a bearer a wave with a pack, 4 to 7 everything in bigger waves than tier 1's, 8 the pair. | Did rounds 1 to 3 teach the two new enemies? Is the run too long? | `data/waves/tier2_room_*.tres`, `data/rounds/tier2_round_*.tres` | |
| 34 | A charger or a bearer is worth 3 coins (a chaser 1, a shooter or a shielded chaser 2), the pair 80. | Did a tier 2 run pay noticeably more? Is the worth of each enemy right? | `coins` in `data/enemies/*.tres` (the economy pass is still parked) | |
| 35 | The step from tier 1 to tier 2. | Hard enough, too hard, fair? Where did you fall? | the waves and the defs above | |

## The lifts and the record

| # | What it is | Question | Knob | Result |
|---|---|---|---|---|
| 36 | The Hypogeum holds three bays side by side: tier 2's on the left, tier 1's in the centre, tier 3's on the right. A shut bay is the closed door darkened, its frame too; it takes no key and no E. | Does a shut bay read as shut until earned, not as broken or as decoration? Should its frame stay lit with only the door darkened? | `Lift.SHUT_MODULATE`, `Lift.shut_bay` in `scripts/lift.gd`; `lift_tiers` in `data/grounds/hypogeum.tres` | |
| 37 | The first time you enter the Hypogeum after tier 1's first win, the new bay rises open once: the door draws up, the dark lifts, a stand-in door sound. | Did you see it? Did it read as the new lift opening? | `Lift.LIFT_RISE`; `lift_open` in `data/audio.json` | |
| 38 | Once a second tier exists, the gate screen's run block opens with a row naming the tier ("Tier 2"). | Did you notice it, and is it in the right place? | `GateScreen` in `scripts/ui/gate_screen.gd` | |

## Show, don't tell

- The one question: where did you feel told? A caption, a label, a name, a hint, a line someone said, a sound that explained instead of being. No tier, lift, arrow, banner, or charge is explained anywhere; the gate screen names the tier, the bars name the bodies. We want "nowhere"; anything else is a row below.

## Verdict, playtest 1

(Your notes on `0.7.0-rc1`, one row each; the Change column holds the decision once taken, the
Done column the commit.)

| # | Note | Change | Where | Done |
|---|---|---|---|---|
| | | | | |
