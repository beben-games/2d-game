# Milestone 3 design: weapons and the upgrade picker

Approved 2026-09-08 in the brainstorm session. Supersedes the Milestone 3 line of the design
table in `docs/plans/2026-09-02-action-roguelike-design.md` ("eight upgrades, at least three
that combine"): the picker now draws from per-weapon upgrade pools with ranks and caps, and a
second weapon with its own pool is part of the milestone. `docs/plans/2026-09-08-m3-prework-notes.md`
holds the code hooks this design builds on.

## Goal

The room-clear moment becomes a choice. The heart pickup stops dropping on every clear and
becomes one card among several. Two weapons, each with an authored upgrade path that suits how
it plays: the handgun fast and homing, the crossbow slow, piercing, and elemental. A weapon
switch is itself a card and costs one pick. Runs are eight rooms long so a build can form.

Done when the user plays a full run and finds a build they like, rated on a feel checklist
written in the last task. Replay 2's changes (the entry bricking up, chasers at player speed)
get rated in the same playtest.

## Decisions taken in the brainstorm

| Question | Decision |
|---|---|
| Picker in-room or paused menu | A real menu: the tree pauses, cards over a dim, nothing moves until a card is taken. (An in-room variant was considered first and dropped.) |
| The heart | One card among the offers, "Heal", shown only when HP is missing. The room-centre heart drop goes away. |
| Weapon-specific pools | Yes. Each weapon has its own upgrade list with ranks and caps; a few upgrades are shared. |
| Second weapon | The crossbow. Bolts instead of bullets: slower, heavier, pierce 2 by default. |
| Weapon switch | A card in the pool from the first clear, drawn uniformly like any other. Taking it spends this room's pick, then the player re-picks as many weapon upgrades for the new weapon as the old one had, in back-to-back rounds. Player upgrades (hearts, dashes) are untouched. |
| Damage | A basic damage upgrade in both pools. |
| Dash | Duration and speed constant. Extra dash charges are a player upgrade. |
| Run length | The floor grows from four rooms to eight, data only. Difficulty tuning stays in Milestone 4. |
| HUD | Minimal essentials on the HUD; Tab pauses and shows the full build. |
| Icons | Raven Fantasy Icons (free set) at 16 px as the single icon source; the user's pistol sheet for the handgun; the 0x72 dungeon UI sheet for card frames, buttons, and the font. Shikashi's and the Casper Gaming MZ set stored as reserves. |
| Upgrade model | Fold at fire time: the run holds a build, a pure function folds it over the base weapon. No mutation of the weapon copy, no per-upgrade scripts. |
| Status effects | A `StatusEffects` child node on every enemy, applied by the projectile, read by the enemy each tick. |

## Weapons and pools

Base numbers (the handgun is today's pistol, renamed):

| | Handgun | Crossbow |
|---|---|---|
| damage | 1 | 3 |
| fire_rate (shots/s) | 5 | 1.5 |
| projectile_speed (px/s) | 340 | 260 |
| pierce | 0 | 2 |
| lifetime (s) | 1.1 | 1.6 |
| knockback | 140 | 220 |
| inaccuracy (deg) | 2.5 | 1.0 |
| look | drawn bullet (today's circle) | tileset `weapon_arrow`, rotated to the direction |

Upgrade pools, per rank, with caps. All numbers are data (`data/upgrades/*.tres`) and are
expected to move in the balance pass.

| Upgrade | Handgun | Crossbow | Modifiers per rank |
|---|---|---|---|
| Damage | 3 ranks, +1 | 3 ranks, +2 | damage add |
| Fire rate | 3 ranks, x1.25 | none | fire_rate mul |
| Multishot | 2 ranks | 2 ranks | projectile_count +1, spread_degrees +12 |
| Pierce | 1 rank, +1 ("piercing bullets") | 2 ranks, +2 (max 6) | pierce add |
| Bounce | 1 rank | 1 rank | bounce +1 |
| Homing ("tracing bullets") | 1 rank | none | homing +1 |
| Flaming bolts | none | 1 rank | burn +1 |
| Shock bolts | none | 1 rank | stun +1 |
| Chill bolts | none | 1 rank | chill +1 |

Player upgrades, offered with either weapon and kept through a switch:

| Upgrade | Ranks | Effect |
|---|---|---|
| Heart container | 3 | max HP +2 (one heart) and heals 2; max HP goes 6 to 12, six hearts on the HUD |
| Dash charge | 2 | +1 dash charge; three dashes in a row at rank 2 |
| Heal | unlimited, only offered when HP < max | +2 HP, does not touch the build |
| Switch to crossbow / handgun | offered when the other weapon exists | see the switch flow |

## Data

- `UpgradeDef` (`scripts/defs/upgrade_def.gd`, files in `data/upgrades/`): `id`, `name`,
  `description` (a template with the per-rank value), `icon` (a Raven sprite name), `kind`
  (WEAPON, PLAYER, HEAL, SWITCH), `weapon_id` (the weapon a WEAPON card belongs to, required; for
  SWITCH, the weapon it switches to; empty for PLAYER and HEAL), `max_rank`,
  `modifiers: Array[Modifier]`. `validate()` rejects an empty id, `max_rank < 1`, and unknown stat
  names.
- `Modifier` (`scripts/defs/modifier.gd`): `stat: String`, `add: float = 0`, `mul: float = 1`.
  Applied once per rank as `value = (value + add) * mul`. Stat names are the `WeaponDef`
  numeric fields plus `bounce`, `homing`, `burn`, `stun`, `chill`, and the player stats
  `max_hp` and `dash_charges`.
- `WeaponDef` gains `id`, `display_name`, `icon`, `look` (BULLET or BOLT), and the new stats
  `bounce: int`, `homing: float`, `burn: float`, `stun: float`, `chill: float`, all default 0.
  `validate()` also rejects negative `pierce`, `knockback`, `spread_degrees`,
  `inaccuracy_degrees`, `bounce`, and the status stats. `data/weapons/pistol.tres` becomes
  `handgun.tres` (id `handgun`); `data/weapons/crossbow.tres` is new. `shaman_bolt.tres` is
  untouched apart from the new defaults.
- `Build` (`scripts/build.gd`, RefCounted, pure): `weapon_id`, `weapon_ranks: Dictionary`
  (upgrade id to rank), `player_ranks: Dictionary`. `resolve(base: WeaponDef, catalog) ->
  WeaponDef` returns a fresh def with every owned weapon upgrade folded in. `max_hp()`,
  `dash_charges()`, `weapon_upgrade_count()` (the switch refund). `rank_of(id)`.
  `RunState.build` holds one; `start_run` replaces it with a fresh handgun build.
- `UpgradeCatalog` (`scripts/upgrade_catalog.gd`): loads every `data/upgrades/*.tres` and
  `data/weapons/*.tres` once (a boot test validates all of them). `pool(build, hp, max_hp) ->
  Array[UpgradeDef]`: the current weapon's upgrades below cap, player upgrades below cap, Heal
  when hp < max_hp, and one Switch card per other weapon. `draw(pool, rng, n = 3)` picks n
  distinct cards uniformly; fewer if the pool is smaller.
- Events: `upgrade_chosen(def: UpgradeDef, rank: int)` and `build_changed()`. The player
  re-resolves its weapon and max HP on `build_changed`; the HUD and the build screen read
  `RunState.build`.

## The picker

- Trigger: `Main._on_room_cleared`, for any room but the last, keeps the exit shut and opens
  the picker deferred (the signal arrives from a physics callback). The heart drop is removed.
  The last room wins as today, no picker.
- `UpgradeMenu` (`scenes/ui/upgrade_menu.tscn`, CanvasLayer 10: over the HUD, under the fade).
  `Juice.reset()` first (a kill freeze must not leave `Engine.time_scale` low under the pause),
  then `get_tree().paused = true`; the layer's `process_mode` is ALWAYS. Three cards in a row
  on the 0x72 frame with the 0x72 pixel font: icon, name, effect line with the rank reached.
  A click on a card or the keys 1, 2, 3 choose. R still restarts from the menu.
- Choosing: raise the rank on `RunState.build` (Heal heals instead), emit `upgrade_chosen` and
  `build_changed`, unpause, `room.open_exit()`, `room_open = true`.
- Switch: `n = build.weapon_upgrade_count()`; clear `weapon_ranks`, set `weapon_id`, emit
  `build_changed`; then re-offer `n` rounds from the new weapon's pool. Each round is a fresh
  draw; if the pool empties early the menu stops early. The switch itself is this room's pick.
- Empty pool: the picker does not open and the exit opens as today.
- Seeding: `RunState.stream("upgrades:%d:%d" % [room, round])`, so a seed replays the same
  offers.
- `BuildScreen` (`scenes/ui/build_screen.tscn`, same layer): Tab pauses and lists the weapon,
  each owned upgrade with rank and effect, and the player upgrades; Tab or Escape closes. R
  restarts from the build screen too (added in the Task 13 review: Main is paused under it, so
  the screen forwards R like the picker does). It does not open while the picker is up, during
  the room fade, or after the run has ended, and the picker cannot open over it (the picker
  waits for the next frame it is closed, or the build screen simply refuses Tab while
  `room_open` is false and the picker is pending).
- New input actions: `pick_1`, `pick_2`, `pick_3`, `build_screen` (Tab), `ui_cancel` is the
  built-in Escape.

## Projectiles

- Movement by raycast: each physics tick the projectile casts from its previous position to
  its next one against the walls layer (bit 16). On a hit with no bounces left it despawns,
  as the wall group check does today; with bounces left it moves to the hit point, reflects
  `direction` across the normal, and decrements its bounce count. Any wall shape works and
  tunneling ends at any speed. Enemy bolts share the script with the new stats at 0.
- Homing: each tick, with `homing > 0`, find the nearest live enemy within `HOMING_RANGE`
  (120 px) and rotate `direction` toward it at `HOMING_TURN` (4 rad/s). Constants at the top
  of `projectile.gd`.
- `setup(def, dir)` also copies `bounce`, `homing`, `burn`, `stun`, `chill` and the look.
  On hitting a body with a `StatusEffects` child it applies the non-zero statuses.
- The bolt look is a `Sprite2D` with the tileset `weapon_arrow`; the bullet look is the
  `_draw` circle as today.

## Status effects

`StatusEffects` (`scripts/status_effects.gd`), a child of every enemy scene, with three timers
and a `apply(kind, strength)` entry. Reapplying refreshes the timer, no stacking. Constants at
the top of the script:

| Status | Effect | Feedback |
|---|---|---|
| burn | 1 damage per second for 3 s, through `Health.take_damage` with no knockback | orange tint |
| stun | 0.6 s: movement wish zero; a shooter's attack is interrupted and it telegraphs again in full afterward | pale flash |
| chill | speed x0.5 for 2 s | blue tint |

As built, the entry is `apply_from(shot)` (one call per hit, reading the shot's `burn`, `stun`,
`chill`) plus `apply_burn()`, `apply_stun()`, `apply_chill()`; strength is not modelled, since
every card sets 1, and a shot that kills applies nothing to the corpse.

The enemy reads `status.speed_multiplier()` and `status.stunned` each tick. Burn damage
passes a flag so `Enemy._on_damaged` skips the hit trauma and white flash for those ticks; the
tint is the feedback. The dying enemy's `enemy_died` path is unchanged.

## Dash charges

`DashRules` gains `charges` handling: a dash spends one charge; the cooldown refills one
charge at a time. With one charge the behaviour is today's. Duration and speed unchanged.
The refill clock runs whenever the bar is below the max and is not restarted by a dash: two
dashes at 0 s and 0.5 s refill at 0.6 s and 1.2 s.

## HUD and build screen

- Hearts grow with heart containers, up to six.
- Under the hearts, one pip per dash charge, lit when ready.
- Top right: the weapon icon, then the owned weapon upgrade icons each with a rank digit, then
  the player upgrades. Raven 16 px sprites at 3x, with `expand_mode = EXPAND_IGNORE_SIZE`.
- Room, wave, kills unchanged.
- Tab: the build screen, above.

## Assets

- `assets/raven_icons/`: the free Raven Fantasy Icons 16 px sheet plus a name index
  (`data/icons.json`, generated by `tools/gen_icons.py` from a hand-written name list of the
  cells we use), looked up by name through `SpriteAtlas` like the tileset. README with the
  license terms as shipped.
- `assets/dungeon_ui/`: the 0x72 dungeon UI sheet; hand-measured regions for the frame, the
  button, the hearts, and the font glyphs; a Godot font resource built from the glyph strip.
  Fallback if slicing the font is unreliable: the default font, recorded as a deviation.
- `assets/guns/`: the pistol sheet downsampled by 10 to 16 px art; the top-left dark pistol is
  the handgun icon. Origin and licence in `CREDITS.md` (Hatitler, itch.io, free, no licence stated).
- `assets/reserve/`: Shikashi's Fantasy Icons Pack v2 and the Casper Gaming MZ icon set
  (credit: Fauster; Casper Gaming terms of use), unused in M3, kept for tiers, melee, casters.
- `CREDITS.md`: every pack, author, license.

## Floor

`data/rooms/room_5..8.tres` and `data/waves/room_5..8.tres`, all exits TOP, like rooms 1 to 4
(the entry is then BOTTOM, which the validator requires to differ), counts rising gently to a
room 8 finale about a third above room 4. `floor_1.tres` lists eight rooms. `RunState.rooms_total`
follows.

## Tests

- Pure: the fold (every stat, ranks, caps, unknown stat errors), pool and draw (seeded,
  distinct, Heal only when hurt, Switch for the other weapon, empty pool), the switch refund
  count, dash charges, heart layout past three hearts, bounce reflection, catalog validation.
- Scene (`SceneSuite`): picker opens on a deferred clear and the exit stays shut; card 1
  applies the rank and opens the exit; the switch chains the right number of rounds; a bounced
  shot survives one wall; a homing shot turns toward a placed enemy; burn, stun, and chill each
  alter a placed enemy as specified; the HUD strip updates on `build_changed`; Tab pauses and
  unpauses; a boot test validates every upgrade and weapon file.
- Validation fails loudly: unknown stat names and bad ranks at load, a switch to a missing
  weapon at pick, a negative stat after folding at resolve.
- Smoke: `room` picks card 1 before walking; a new `pick` scenario clears a room, takes a
  card, and asserts `SMOKE_UPGRADE <id>`.

## Build order

Each step green (tests, boot gate, relevant smoke) before the next:

1. Data and the fold: `Modifier`, `UpgradeDef`, `WeaponDef` fields, `Build`, `UpgradeCatalog`, the handgun and its stat upgrades.
2. The picker with the handgun's stat upgrades; heart drop removed; Heal card.
3. Bounce and homing (raycast movement first).
4. The crossbow, the bolt look, the switch flow.
5. Status effects and the crossbow's elemental upgrades.
6. Dash charges and heart containers.
7. HUD strip and the build screen.
8. Assets, icons, frame, font, credits.
9. Rooms 5 to 8.
10. Smoke scenarios, the feel checklist, the `m3-candidate` tag.

## Open items

- Settled 2026-09-14, see `CREDITS.md`: the pistol sheet is Hatitler's "Pixel Art Pistol Gun Pack" (itch.io, free, no licence stated); the Raven free set is personal use only (free, non-profit projects); DungeonUI is CC0.
- The 0x72 UI font slice; fallback is the default font.
- From the Milestone 2 notes, touched by this work: `juice.gd`'s header claim about feel
  numbers; the shooter lockstep (`recover_time` jitter) if it reads as unfair in the playtest.
- For 1.0, not here: multiple characters with distinct starting weapons (the build already
  keys on `weapon_id`, so a character is a starting build), melee and caster weapons
  (`WeaponDef.kind` picks the attack path later), non-rectangular rooms and multiple exits.

## Deviations found while planning (2026-09-08)

Recorded from `docs/plans/2026-09-08-milestone-3.md`; the plan's own "Deviations" section grows during the build and is copied here at the close.

- The 0x72 UI sheet does carry its font: three rows of white glyphs, invisible on a white background, proportional, no punctuation. `tools/gen_ui_font.gd` builds a BMFont from it and draws `+ - . , : / % '` by hand. The "default font fallback" above is not needed.
- Assets (icons, frames, font) land before the menu (plan Task 5, before Task 6), not at step 8 of the build order above, so the menu is built once with its final look.
- With two weapons a switch card is always in the pool, so the pool is never empty; the "empty pool skips the picker" path stays as a guard without a test.
- Icon cells chosen on the Raven sheet (row, col): damage 45,7; fire rate 31,2; multishot 61,2; pierce 134,9; bounce 67,2; homing 44,14; flaming 62,5; shock 64,0; chill 63,4; heal 67,0; heart container 65,1; dash charge 57,1; crossbow 112,12. The handgun comes from the user's pistol sheet (10x, cut at 1x). `tools/icon_sheet.gd` renders them for a check.
- Probed and settled: a paused tree keeps running `_process`, input, `physics_frame`, and real-time timers for a CanvasLayer set to always process; `intersect_ray` works inside an Area2D's physics tick and `Vector2.bounce(normal)` is the reflection; a failed `assert` in a headless `-s` script hangs instead of quitting, so generators use `push_error` plus `quit(1)` and run under a deadline.

## Deviations during the build (copied from the plan's "## Deviations" at the close, 2026-09-14)

One line each; the plan's bullets hold the detail and the file names.

- Task 1 review: `Modifier.is_known_stat` reports a modifier on the wrong stat list next to its other errors; HEAL rejects a set `weapon_id` like PLAYER; `test_weapon_def.gd` pins every `Modifier.WEAPON_STATS` name to a real `WeaponDef` property, since `Object.set` on a misspelled property is a silent no-op.
- Task 2 review: `Build` rounds int stats after every rank on both folds (one `_apply` helper), so a `mul` on `max_hp` folds like a `mul` on `projectile_count`; `resolve` trusts a validated catalog.
- Task 3: `load_steps` in a card file is 3 + sub-resources (the modifier script counts), so the three modifier-less cards are `load_steps=3`.
- Task 3 review: the catalog strips `.remap` before its `.tres` filter, since an export lists `name.tres.remap` and would have loaded empty; load time asserts every `weapon_id` names a loaded weapon; both caches are read-only once loaded.
- Task 5: four Raven icon cells did not show what their comments said and moved: fire rate (39, 10), dash charge (41, 10), multishot (52, 5), crossbow (106, 2); the table in "Deviations found while planning" above is superseded by `tools/gen_icons.py`.
- Task 5 review: the u/v glyph split in `gen_ui_font.gd` started v one column late; both generators check every save and open; `ui_font.fnt` imports with integer scaling; `assets/reserve/.gdignore` keeps the reserve packs out of the import pipeline; a glyph-coverage test names any card character the font lacks.
- Task 6: three test changes, no game code: the summary suite's fade-death test picks a card before expecting a fade; a held `restart` action is never "just pressed" again, so the damage suite releases it; the switch test checks WEAPON cards only, since `switch_handgun` is a legitimate crossbow-pool offer.
- Task 6 review: refund rounds accumulate (a switch during a refund round keeps the rounds still owed); the refund re-open is deferred (a click arrives inside `pressed`); `Main.restart()` closes the menu so no live menu sits over a test's or the smoke tool's game.
- Task 7: naming `Enemy` from `projectile.gd` closed a load cycle through `enemy.gd`'s bolt preload, which silently cached the bolt scene without its script; `_nearest_enemy` iterates the `enemies` group as `Node2D`, a corpse leaves the group in `_on_died`, and the `walls` group (no reader left) is gone from `door.gd` and `arena.tscn`; the enemy bolt no longer masks walls (0, not 16) and does not monitor.
- Tasks 8 and 9 review: `test_homing_ignores_a_corpse` fires while the corpse still stands through the kill freeze (the plan's placement after the freeze would pass without `remove_from_group`); the nearer of two enemies wins; the bolt's rotation test reads `absf` because the composed transform lands on the branch cut.
- Task 10: `flash.gdshader` never read the incoming `COLOR`, so `modulate` was ignored: the status tints and the Milestone 2 spawn fade-in had never shown; fixed to `mix(COLOR.rgb, vec3(1.0), flash)` with `COLOR.a` kept. Two test fixes for a freed corpse and an override signature.
- Task 10 review: a stun mid-telegraph interrupts the attack (`ShooterBrain.interrupt()` back to APPROACH, shiver and pulse cut), so the shooter telegraphs again in full and a shot is never a surprise; corpses take no status (`apply_from` returns on `health.dead`, the `Status` child stops with the enemy); the entry is `apply_from(shot)` plus `apply_burn/stun/chill` with no strength, as the "Status effects" section now says.
- Task 11: `_apply_build` restructured with the Task 4 review's deferred items: the weapon is always re-resolved, each player stat gates its own signal on its own max, the grow/clamp is one `hp += new_max - max_hp` plus `hp = mini(hp, max_hp)`.
- Task 11 review: the dash test pins the refill ticks (the clock continues across a second dash rather than restarting; checked by mutation); the overshoot on a refill is dropped, not carried; `_start_dash` starts the clock on "no clock running". Tidy-up candidate: a `DashCharges` RefCounted.
- Task 12 review: the HUD hides the rank digit on one-rank cards; the HUD reads the build at ready.
- Task 13 review: the build screen panel grew to 1000 x 560 so a crossbow build's effect column fits (the fit test seeds seven upgrades, the most an eight-room floor can give); R restarts from the build screen; `open()` checks `blocked` itself and `blocked` holds during the room fade. Tidy-up candidates: `UiTheme` clear-children and framed-panel helpers shared by the two screens.
- Menu polish (Task 15, from a 2026-09-13 screenshot and the Task 6 review): the key digit moved to the bottom of the card column because the frame's gem ornament covered it at the top; a title longer than 12 characters uses the 32 px font so a two-line title plus a two-line effect no longer runs the rank line under the bottom frame (a fit test runs every catalog card); a switch with nothing to refund reads "Fresh start" instead of "Re-pick 0 upgrades"; a card brightens while hovered.
- Task 15: the `pick` smoke scenario and the `room` scenario's pick landed as planned; the Task 14 review's two balance notes (room 5's finale wave is the smallest since room 3; the shooter share dips at room 6) were not written into the plan, so the checklist's "Inputs for the balance pass" records them, verified against the wave files.
- Final review: a seed replays a run with the same offers only given the same picks and the same hurt state at each clear; Heal joins the pool only when hurt and the draw is from the whole pool, so hurt or not changes all three cards, not one slot (a one-slot swap from a separate stream is a Milestone 4 recommendation in the checklist).
- `UpgradeDef.description` is a fixed string per card, not a template: every rank of a card has identical modifiers, so there is nothing per rank to fill in.
- Card icons are served by a separate `IconAtlas` (`data/icons.json`, the Raven sheet), not `SpriteAtlas`, which stays the tileset's lookup.
