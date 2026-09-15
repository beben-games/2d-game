# Milestone 3 feel checklist

Play a full run (win or die; eight rooms, a card after each of the first seven), then rate each
line good / meh / bad with a note. The milestone closes when you have played a full run and
found a build you liked. Tab shows the build at any time; R restarts. The seed is on the summary
and in the `RUN_OVER`/`RUN_WON` line; `-- --seed=N` replays the run with the same offers given the
same picks and the same hurt state at each clear (Heal joins the pool only when hurt, and the
draw is from the whole pool, so being hurt or not changes all three cards, not one slot).

- The picker: does the pause feel like a reward beat or an interruption? Cards readable at a glance? Did you use the number keys or click? Does the hover brighten enough to know a click will land? (`CARD_SIZE`, `CARD_INSET`, `LONG_TITLE`, `HOVER_MODULATE` in scripts/ui/upgrade_menu.gd; font sizes in scripts/ui/ui_theme.gd)
- Offers: are three cards enough choice? Does Heal show up when hurt at the right rate, and is it ever the only good card? Is the switch card tempting or a trap? (`UpgradeCatalog.pool` and `draw` in scripts/upgrade_catalog.gd; `max_rank` per card in data/upgrades/*.tres)
- Handgun path: rapid fire, split shot, tracing bullets, ricochet, piercing: which combined into something you liked? Are the damage ranks worth a pick? (data/upgrades/*handgun*.tres, fire_rate.tres, homing.tres; base numbers in data/weapons/handgun.tres)
- Crossbow: does slow, heavy, piercing feel different enough from the handgun? Are flaming, shock, and chill readable through the tints, and worth taking? (data/weapons/crossbow.tres; `BURN_*`, `STUN_TIME`, `CHILL_TIME`, `CHILL_SPEED`, the three `*_TINT` colours in scripts/status_effects.gd)
- The switch and its refund: fair? Did you switch back? Did the back-to-back refund rounds read as a refund? ("Fresh start" and `rank_line` in scripts/ui/upgrade_menu.gd; the round accounting in `Main._on_upgrade_chosen`, scripts/main.gd)
- Heart containers and dash charges: worth a pick over a weapon card? Do two or three dashes in a row change how you play? (`BASE_MAX_HP`, `BASE_DASH_CHARGES` in scripts/build.gd; `COOLDOWN`, `SPEED`, `DURATION` in scripts/dash_rules.gd; `max_rank` in data/upgrades/heart_container.tres and dash_charge.tres)
- Bounce and homing: do shots behave as expected off walls and around enemies? Does a homing bullet ever feel like it missed on purpose? (`HOMING_RANGE`, `HOMING_TURN`, `WALL_NUDGE` in scripts/projectile.gd)
- HUD strip, dash pips, Tab screen: legible, in the way of anything? Is the rank digit on the strip readable at 3x? (`ICON_SCALE`, `PIP_SIZE`, `RANK_FONT_SIZE` in scripts/ui/hud.gd; `PANEL_SIZE`, `INSET` in scripts/ui/build_screen.gd)
- Rooms 5 to 8: does difficulty rise? Is eight rooms the right length for a build to form? Where did you die, or how much health did you finish with? (data/waves/room_5..8.tres; `SPAWN_INTERVAL` in scripts/wave_progress.gd)
- Replay 2's changes, judged here: the entry bricking up behind you (`ENTRY_SEAL_DELAY` in scripts/main.gd), and chasers at your speed (`speed` in data/enemies/chaser.tres).
- A full run: how long did it take, did it end the way you expected, and did you find a build you liked? Which one?

## Inputs for the balance pass (Milestone 4)

Recorded by the Task 14 review and checked against `data/waves/*.tres`; not tuned before the
playtest, since the run should be rated as built.

- Room 5's finale wave (6 chasers + 2 shooters, 8) is the smallest since room 3 (6); room 4's is 10. Room 5 reads as a step back right after the room 4 crowd.
- The shooter share dips at room 6: 5 of 24 (21%) against 6 of 22 in room 5 (27%), then 6 of 26 and 7 of 29. Room 6's first wave has a single shooter.
- From the Milestone 2 checklist, still open: the first rooms are easy; two shooters in lockstep (`recover_time` jitter) if it reads as unfair.
- Recommendation: draw the three offers from the Heal-free pool and, when hurt, swap Heal into one slot chosen from a separate stream, so a seed replays the other two cards regardless of hurt state and only that slot varies (`UpgradeCatalog.pool` and `draw`).
- Does Heal crowd out weapon cards when hurt? It has no cap and joins the pool as one of three draws, so a hurt player sees a weapon card less often at every clear of a run where they stay hurt.

One concern per commit in the balance pass, each with a before/after note here.

## Known polish items

Not fixed in Task 15; rate them if they bother you.

- The switch card's effect line "Swap weapons, re-pick your upgrades" wraps at its hyphen ("re-" / "pick"); a shorter description in `data/upgrades/switch_*.tres` would avoid it. Resolved by playtest 1 note 4: the switch cards now describe the weapon.
- A card gives no pressed feedback, only the hover brightening; a click is confirmed by the menu closing.
- Tidy-up candidates from the reviews, no behaviour change: a `DashCharges` RefCounted holding charges, max, and the refill clock (the player carries three loose vars and `DashRules.refill`'s Array return); `UiTheme` helpers for clearing a container's children and building the framed panel (paper plus frame) that `UpgradeMenu` and `BuildScreen` both do by hand; the build screen's weapon row is detected by empty rank and description strings in `_row` rather than a named parameter.

## Verdict, playtest 1 (2026-09-14)

The user played and sent eight notes; no line was rated good, and the "found a build you liked"
question is not answered yet. Milestone 3 stays open until a replay after the pass below. Each
note maps to one change, one concern per commit, in this order (the two `_on_room_cleared`
changes first, the font last because it needs the user's choice). The Done column records the
commit; a note's tick lands in the commit after it, since the hash is known only then.

| # | Note | Change | Where | Done |
|---|---|---|---|---|
| 1 | Clearing the last wave should make every projectile disappear at once | In `Main._on_room_cleared` (deferred: the signal arrives from a shot's `body_entered`), free every child of `room.projectiles` (player shots and enemy bolts share it). Test: place two shots and a bolt, emit `room_cleared`, await a process frame, the container is empty. | `scripts/main.gd`; `tests/test_upgrade_menu_scene.gd` or `tests/test_floor_scene.gd` | Done in 231fe32 |
| 2 | The upgrade screen pops too instantly when the last wave dies | A real-time beat before the picker opens: `const PICKER_DELAY := 0.8` (tune 0.6 to 1.0), a real-time timer like `_seal_entry_later`, guarded on room identity and `_ended`. The kill burst and freeze play out first. Tests that await the open (`SceneSuite.clear_and_pick`, the menu suite, the summary and floor suites via `clear_and_pick`) wait `real_seconds(Main.PICKER_DELAY + 0.1)`; add the delay to CLAUDE.md's list of real-time waits. `tools/smoke.gd` `_pick_first_card` waits the same. | `scripts/main.gd`; `tests/support/scene_suite.gd`; `tools/smoke.gd`; `CLAUDE.md` | Done in 7f02c81 |
| 3 | Cards should not be numbered 1 2 3; redundant and confusing | Drop the key label from the card column; the keys keep working silently. Remove `test_the_key_hint_sits_below_the_frame_ornament`, the `"1"` text assertion in `test_cards_show_name_description_and_rank`, and `ORNAMENT_HEIGHT` if nothing else uses it. Mention "1, 2, 3 or click" nowhere on the card; the checklist and STATUS keep saying it. | `scripts/ui/upgrade_menu.gd`; `tests/test_upgrade_menu_scene.gd` | Done in 8ff5a88 |
| 4 | The Crossbow card should describe the crossbow's gameplay and style, not the swap (implicit) | Descriptions: crossbow "Slow, heavy bolts that pierce two enemies"; handgun "Fast bullets, quick to fire". The rank line keeps "Fresh start" / "Re-pick n upgrades", which is the swap cost. The fit test covers the new strings; the glyph test too. | `data/upgrades/switch_crossbow.tres`, `switch_handgun.tres` | Done in e03ce50 |
| 5 | Shooter bolts a little faster and/or slightly more frequent | One step each and rate: `projectile_speed` 120 to 150 in `shaman_bolt.tres`; `recover_time` 0.8 to 0.6 in `shooter.tres`. Check `tests/test_shooter_scene.gd` and the stun tests in `tests/test_status_effects_scene.gd` for pinned tick counts (they assume `telegraph_time` 0.5 and a recover outside their windows; 0.6 still is). The M2 checklist rated 120 px/s dodgeable; the replay judges 150. | `data/weapons/shaman_bolt.tres`; `data/enemies/shooter.tres` | Done in 9e51e53 |
| 6 | The crossbow icon is a bow | Cell (106, 2) on the Raven sheet reads as a bow. Render the weapon rows (88 to 112) at 4x with `tools/icon_sheet.gd`-style code and look for a true crossbow (stock plus a horizontal bow); if the sheet has none, ask the user for a 16x16 crossbow sprite rather than settling. Update `tools/gen_icons.py`, regenerate `data/icons.json`. | `tools/gen_icons.py`; `data/icons.json` | |
| 7 | The current font does not look good | Replace the 0x72 bitmap font. The user chooses (candidates below); the session wires it: `UiTheme.FONT` becomes the new body font, glyph coverage test in `tests/test_assets.gd` runs against it, `tools/gen_ui_font.gd` and its outputs stay as a record or go. Sizes: pick multiples of the font's native size if it is a bitmap font, or use a TTF at 28 to 40 px with `texture_filter` nearest. | `assets/dungeon_ui/`, `scripts/ui/ui_theme.gd`, `tests/test_assets.gd` | Done in 843827f: Pixel Operator (CC0), TTF at 32 and 48 with no antialiasing or hinting |
| 8 | The title should use a different, bigger font than the description | With note 7: two fonts, `UiTheme.TITLE_FONT` (a display pixel font) at `FONT_TITLE` for card names and the build screen heading, `UiTheme.FONT` for descriptions and rank lines; `UiTheme.label` gains a font parameter or a `title()` helper. Re-check the card fit test with the new metrics; `LONG_TITLE` may go if the title font fits "Piercing bullets" at its size. | `scripts/ui/ui_theme.gd`, `scripts/ui/upgrade_menu.gd`, `scripts/ui/build_screen.gd` | Done in add646f: Alagard at 48, wide names wrap to two lines, `LONG_TITLE` gone |

Font candidates for the user to choose and download (all free for a free game; the session must
not pick one silently):

- Body: **Pixel Operator** (CC0, TTF, several sizes) or **m5x7** / **m3x6** by Daniel Linssen (itch.io, free, clean 5x7 and 3x6 bitmap looks) or **Kenney Pixel** (CC0, from kenney.nl fonts).
- Title: **Alagard** by Pix3M (free, medieval display) or **Press Start 2P** (OFL, arcade) or the same body font two sizes up if one family is preferred.

After the pass: the user replays a full run and rates the lines above; the milestone closes on
"found a build I liked" (`git tag m3`), then the balance pass continues from "Inputs for the
balance pass".
