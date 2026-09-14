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

- The switch card's effect line "Swap weapons, re-pick your upgrades" wraps at its hyphen ("re-" / "pick"); a shorter description in `data/upgrades/switch_*.tres` would avoid it.
- A card gives no pressed feedback, only the hover brightening; a click is confirmed by the menu closing.
- Tidy-up candidates from the reviews, no behaviour change: a `DashCharges` RefCounted holding charges, max, and the refill clock (the player carries three loose vars and `DashRules.refill`'s Array return); `UiTheme` helpers for clearing a container's children and building the framed panel (paper plus frame) that `UpgradeMenu` and `BuildScreen` both do by hand; the build screen's weapon row is detected by empty rank and description strings in `_row` rather than a named parameter.
